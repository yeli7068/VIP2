#!/bin/bash
#
#       This is the main driver script for the VIP2 pipeline.
#
#       Quick guide:
#       Create default config file.
#               VIP2.sh -z -i <NGSfile> -p <nano/pacbio/iontor/illumina> -f <fastq/fasta/bam/sam> -r <reference_path> -m <fast/sense>
#

### Authors : Yang Li <yeli7068@outlook.com>
### License : GPL 3 <http://www.gnu.org/licenses/gpl.html>
### Update  : 2019-06-25
#
bold=$(tput bold)
normal=$(tput sgr0)
green='\e[0;32m'
red='\033[31m'
endColor='\033[0m'
blink='\033[05m'
#scriptname=${0##*/}
scriptname=`basename $0`
VIP2_version='alpha 0.1'
while getopts ":zh1:2:a:p:r:i:c:k:t:o:m:" option;
do
	case "${option}" in
		a)	ADAPTER=${OPTARG}
			;; #specify the input file format
		h)	HELP=1
			;;
		z)	CREATE_CONFIG=1
			;;
		p)	PLATFORM=${OPTARG}
			;;
		r)	REFERENCE_PATH=${OPTARG}
			;;
		i)	INPUT=${OPTARG}
			;;
		1)	FORWARD=${OPTARG}
			;;
		2)	BACKWARD=${OPTARG}
			;;
		c)	CONFIG=${OPTARG}
			;;
		m)	MODE=${OPTARG}
			;;
		t)	TIME=${OPTARG}
			;;
		k)	taskid=${OPTARG}
			;;
		o)	OUTPUT_DIR=${OPTARG}
			;;
		:)	echo "Option -$OPTARG requires an argument." >&2
			exit 1
			;;
	esac
done



if [[ $HELP -eq 1  ||  $# -lt 1 ]]
then
	cat <<USAGE

${bold}Welcome to use VIP2 for your analysis.

Virus Identification Pipeline 2 (VIP2) is a semi-automatical computational
pipeline for identification of virus.

VIP2 version ${VIP2_version}${normal}

This program will run the VIP2 with the parameters supplied by the config file.

${bold}Command Line Switches:${normal}

	-h	Show help & ignore all other switches

	-z	This switch will create a standard config file.

	-p	Specify the sequencing platform <iontor/illumina/nano/pacbio>

		VIP2 will perform further analysis accroding to the sequencing platform.

	-r	Specify the PATH for database (DB)

		VIP2 will search the reference DB under the Path provided.

			* host_DB
			* sense_nucl_DB
			* sense_prot_DB
			* tax_DB

	-m	mode <sense/kraken/dir>

		Sense mode performs centrifuge to microbes -> kaiju to Viral proteins -> coverage map + krona visulization
		kraken mode performs kraken to microbes -> krona visulization
		dir mode performs comparative analysis on the files under the directory provided by -i switch.
		The file system must be as:

			<Work Dir>
			|-- file1
			|   |-- file1_1.fq.gz
			|   |-- file1_2.fq.gz
			|-- file2
			|   |-- file2_1.fq.gz
			|   |-- file2_2.fq.gz

	-i	Specify NGS file for processing

	-o	Specify the output dir

		${bold}This switch is used to initiate a VIP2 via loading the config file.
		Config file is crucial for VIP2. Config file provided the parameters to VIP2 for analysis.${normal}
		The pipeline will cease if VIP2 fails to find a software dependency or necessary reference data.



${bold}Usage:${normal}

	${bold}Create config file:${normal}

	Platform: illumina

	$scriptname -z -1 test.1.fastq -2 test.2.fastq -p illumina -r <reference_PATH> -m <sense/kraken> -o <OUTPUT_DIR>

	Platform: iontor

	$scriptname -z -i test.fastq -p iontor -r <reference_PATH> -m <sense/kraken> -o <OUTPUT_DIR>

	Mode: dir

	$scriptname -z -i <DIR> -m dir -p illumina -o <OUTPUT_DIR> -r <REFERENCE_PATH>

USAGE
	exit
fi

if [[ ! $CREATE_CONFIG ]] || [[ $CREATE_CONFIG -ne 1 ]]
then
	echo -e "Please turn on switch -z. More helps refer to $scriptname -h"
	exit
fi


if [[ ! -f $FORWARD ]] || [[ ! -f $BACKWARD ]]
then
	PAIRED=0
else
	PAIRED=1
fi


if [[ ! -d $OUTPUT_DIR ]]
then
	echo -e "The directory of outputs $OUTPUT_DIR was invalid. Please check it"
	exit
fi

OUTPUT_DIR=`readlink -f $OUTPUT_DIR`

if [[ ! $MODE ]]
then
	echo -e "Please specify the mode to run. More helps refer to $scriptname -h"
	exit
elif [[ $MODE != "kraken" && $MODE != "sense" && $MODE != "dir" ]]
then
	echo -e "The mode $MODE might be in a wrong format. It should be 'kraken' or 'sense'. More helps refer to $scriptname -h"
	exit
fi

if [[ $MODE != "dir" ]]
then
	if [[ -f $INPUT ]] && [[ $PAIRED -eq 0 ]]
	then
		echo -e "The file $INPUT is unparired. "
	elif [[ $PAIRED -eq 1 ]]
	then
		#INPUT=$(readlink -f $INPUT)
		echo -e "The file $FORWARD and $BACKWARD are paired."
	else
		echo -e "Input file missing. Abort ..."
		exit
	fi
elif [[ -d $INPUT ]]
then
	WORKDIR=`readlink -f $INPUT`
else
	echo -e "Please provide the directory contains files to be processed."
	exit
fi


if [[ ! -d $REFERENCE_PATH ]] || [[ ! -d $REFERENCE_PATH/DATABASE ]] || [[ ! $REFERENCE_PATH ]]
then
	echo -e "Please locate the reference path and re-run the program. More helps refer to $scriptname -h"
	exit
fi

if [[ ! $PLATFORM ]]
then
	echo -e "Please specify the platform where the data generated from. More helps refer to $scriptname -h"
	exit
elif [[ $PLATFORM != "iontor" && $PLATFORM != "illumina" && $PLATFORM != "pacbio" && $PLATFORM != "nano" ]]
then
	echo -e "The platform $PLATFORM might be in a wrong format. It should be 'iontor' or 'illumina' or 'pacbio' or 'nano'. More helps refer to $scriptname -h"
	exit
fi

if [[ $CREATE_CONFIG -eq 1 && $INPUT && $PLATFORM && $REFERENCE_PATH && $MODE && $OUTPUT_DIR ]]
then
	if [ "$PLATFORM" = "illumina" ]
	then
		quality_threshold=20
	elif [ "$PLATFORM" = "iontor" ]
	then
		quality_threshold=17
    elif [[ "$PLATFORM" = "nano" || "$PLATFORM" = "pacbio" ]]
    then
        quality_threshold=5
    else
		echo "$scriptname:The platform $PLATFORM cannot be supported. Please check the platform. Currently the data from ${bold}illumina/iontor${normal} are supported"
		exit 65
	fi

(
	cat <<EOF
# This is the config file used by VIP2 (Virus Identification Pipeline 2).
# It contains mandatory parameters, optional parameters.

# VIP2 will perform alignment due to mode <sense/kraken>
# sense mode performs centrifuge to microbes -> kaiju to Viral proteins -> coverage map + krona visulization
# kraken mode performs kraken to microbes -> krona visulization

# Reads will be classfied at genus-level for identification at species or strain level.
# Do not change the config_file_version - it is auto-generated.
# and used to ensure that the config file used matches the version of the VIP2 pipeline run.
config_file_version="$VIP2_version"

##########################
#  PATH for VIP2
##########################
#The variable REFERENCE_PATH is the top branch of VIP2 scripts and its dependancies.
#All scripts of VIP2 were installed at $REFERENCE_PATH
#All software dependencies were installed in $REFERENCE_PATH/bin

#PATH=/usr/local/sbin/:/usr/local/bin:/usr/bin/:/bin:$REFERENCE_PATH:$REFERENCE_PATH/bin
REFERENCE_PATH=$REFERENCE_PATH

OUTPUT_DIR=$OUTPUT_DIR

##########################
#  Input file
##########################

#To create this file, concatenate the entirety of a sequencing run into one file.
INPUT="$INPUT"

#sequencing platform
PLATFORM="$PLATFORM"

##########################
# Run Mode
##########################

#Run mode to use. [kraken/sense]
run_mode="sense"

##########################
# Preprocessing
##########################
#preprocess parameter to skip preprocessing or not
#skipping preprocess is useful for large data sets that have already undergone preprocessing step such as data from SRA.
#default yes
#preprocess=Y/N
preprocess="Y"

#Adapter removed?
#
adapter="$ADAPTER"

#Specific parameters for preprocess
#average quality cutoff (17 for PGM, 20 for illumina)

quality_cutoff="$quality_threshold"

#length_cutoff: after quality and adaptor trimming, any sequence with length smaller than length_cutoff will be discarded

length_cutoff="20"

#Removing Background-related reads
#default yes
#background=Y/N
background="Y"

#Percent query coverage per read for generate coverage map
reads_coverage="60"


##########################
# Reference Data
##########################

# SNAP-indexed database of host genome (for subtraction phase)
# SURPI will subtract all SNAP databases found in this directory from the input sequence
# Useful if you want to subtract multiple genomes (without combining SNAP databases)
# or, if you need to split a db if it is larger than available RAM.
SNAP_subtraction_folder="$REFERENCE_PATH/DATABASE/HOST/"

# directory for SNAP-indexed databases of NCBI NT (for mapping phase in comprehensive mode)
# directory must ONLY contain snap indexed databases
SNAP_db_dir="$REFERENCE_PATH/DATABASE/nt/"

# directory for SNAP-indexed databases of bacteria (for mapping phase in sense mode)
SNAP_SENSE_DIR="$REFERENCE_PATH/DATABASE/nt/"


#Taxonomy Reference data directory
#This folder should contain the 3 SQLite files created by the script "create_taxonomy_db.sh"
#gi_taxid_nucl.db - nucleotide db of gi/taxonid
#gi_taxid_prot.db - protein db of gi/taxonid
#names_nodes_scientific.db - db of taxonid/taxonomy
taxonomy_db_directory="$REFERENCE_PATH/DATABASE/TAX/"

#RAPSearch viral database name: indexed protein dataset (all of Viruses)
#make sure that directory also includes the .info file
#RAPSearch_NR_db="$REFERENCE_PATH/DATABASE/SENSE/AA/nr_20151231"

#RAPSearch nr database name: indexed protein dataset (all of NR)
#make sure that directory also includes the .info file
#RAPSearch_VIRUS_db="$REFERENCE_PATH/DATABASE/AA/cmip_db_viral_protein"

kaiju_nodes="$REFERENCE_PATH/DATABASE/AA/nodes.dmp"
kaiju_fmi="$REFERENCE_PATH/DATABASE/AA/virus_protein_20170304.fmi"
kaiju_name="$REFERENCE_PATH/DATABASE/AA/scientific_name.dmp"
#  Number of mismatches allowed in Greedy mode with kaiju
kaiju_error=5

ITS_16S="$REFERENCE_PATH/DATABASE/16S_ITS"

rRNA="$REFERENCE_PATH/DATABASE/rRNA"

#ribo_clean_db="$REFERENCE_PATH/DATABASE/rRNA_DB/rRNA_clean"

#Local database collection for quickly data query
BLASTDB="/home/liyang/CMIP/DATABASE/blast_nt/nt"
EOF
) > $INPUT.config
fi
declare -a software_list=("bwa" "samtools" "ococo" "centrifuge" "kaiju" "java"  "blastdbcmd" "makeblastdb" "blastn")
echo "#####################################################################################"
echo "SOFTWARE DEPENDENCY VERIFICATION"
echo "#####################################################################################"
for command in "${software_list[@]}"
do
	if hash $command 2>/dev/null
	then
		echo -e "$command: passed"
	else
		echo -e "$command: ${red} ${blink}ERROR!ERROR!${endColor}"
#		software_check="FAIL"
		exit
	fi
done

#Dir
if [[ $MODE = "dir" ]]
then
	if [[ $PLATFORM != "illumina" ]]
	then
		echo -e "The mode $MODE only supported paire-end data from illumina. Please refer the -p "
		exit
	fi
	cd $WORKDIR
	ls -1 | sed '/list/d' > list
	name=`head -n 1 list`
	cd $name
	errFlag=0
	if [ ! -e ${name}.fq1_clean.fq.gz ] || [ ! -e ${name}.fq2_clean.fq.gz ]
	then
		errFlag=1
	fi
	if [[ $errFlag -ne "0" ]]
	then
		echo -e "The files under the dir $WORKDIR are not in the format as requested. The mode $MODE only supported paire-end data from illumina."
		echo -e "Please go for help $scriptname -h."
		exit
	fi
	cd ..
	CMIP_pExec.sh -o $OUTPUT_DIR -r $REFERENCE_PATH -z 20
	echo -e "${bold} Done.... ${normal}"
	echo -e "Please refer to $OUTPUT_DIR/ to find results."
	exit
fi

#QC
if [ "$PLATFORM" = "illumina" ]
then
	if [ -f $FORWARD ] && [ -f $BACKWARD ]
	then
		name=${FORWARD%_*}
		env LD_LIBRARY_PATH="" VIP2_preprocess.sh -1 $FORWARD -2 $BACKWARD -a $ADAPTER -r $REFERENCE_PATH -p illumina
	fi

elif [ "$PLATFORM" = "iontor" ]
then
	if [ -f $INPUT ]
	then
		name=${INPUT%.*}
		env LD_LIBRARY_PATH="" VIP2_preprocess.sh -i $INPUT -r $REFERENCE_PATH -p iontor
	fi

elif [[ "$PLATFORM" = "pacbio" || "$PLATFORM" = "nano" ]]
then
     if [ -f $INPUT ]
     then
         name=${INPUT%.*}
         env LD_LIBRARY_PATH="" VIP2_preprocess.sh -i $INPUT -r $REFERENCE_PATH -p $PLATFORM
     fi
fi

if [ -d $name.report ]
then
	rm -rf $name.report
	mkdir -p $name.report
else
	mkdir -p $name.report
fi

workdir=$(pwd)

#Alignment
VIP2_aln.sh -m $MODE -i $name.SE -r $REFERENCE_PATH -p $PLATFORM


#Analysis
VIP2_covplot.sh -m $MODE -i $name -r $REFERENCE_PATH -p $PLATFORM

#report generation
#VIP2_report.sh

#You can add the $taskid and $TIME
#e.g
#cp -r $name.report $OUTPUT_DIR/${taskid}_${TIME}_${name}.report
cd $workdir/$name.report
VIP2_report_html.py -s $name.summary -l $REFERENCE_PATH -n $name

if [ ! -d $OUTPUT_DIR/$name.report ]
then
	cp -rf $name.report $OUTPUT_DIR
fi

echo -e "${bold}Done.${normal}"
echo -e "Please refer to $OUTPUT_DIR/$name.report to find results."

#!/bin/bash
#
#
#       This is the main driver script for the VIP2 pipeline.
#
#       Quick guide:
#       Create default config file.
#               VIP2_preprocess.sh -z -i <NGSfile> -p <nano/pacbio/iontor/illumina> -f <fastq/fasta/bam/sam> -r <reference_path> -m <fast/sense>
#
### Authors : Yang Li <yeli7068@outlook.com>
### License : GPL 3 <http://www.gnu.org/licenses/gpl.html>
### Update  : 2019-06-25
#
#VIP2质控：
#
#1, Trimmomatic
#2, Prinseq-lite去除低复杂度区域, 暂时被移除  Todo 使用https://github.com/eclarke/komplexity
#3, 输出是$name.SE.fq

scriptname=${0##*/}

while getopts ":h1:2:a:p:i:r:" option;
do
	case "${option}" in
		a)	ADAPTER=${OPTARG}
			;; #specify the input file format
		h)	HELP=1
			;;
		p)	PLATFORM=${OPTARG}
			;;
		i)	INPUT=${OPTARG}
			;;
		1)	FORWARD=${OPTARG}
			;;
		2)	BACKWARD=${OPTARG}
			;;
		r)	DEPENDENCY=${OPTARG}
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

VIP2 is a semi-automatical computational pipeline for identification of pathogen.

This program $scriptname perform quality control

Command Line Switches:

	-h	Show help & ignore all other switches

	-p	Specify the sequencing platform <iontor/illumina/pacbio/nano>

		VIP2 will perform further analysis accroding to the sequencing platform.

	-r	PATH to dependencies required by VIP2

	-i	Specify NGS file for processing. Could be gzip'ed (extension: .gz) or bzip2'ed (extension: .bz2).

	-1	Files with #1 mates, paired with files in <m2>. Could be gzip'ed (extension: .gz) or bzip2'ed (extension: .bz2).

	-2	Files with #2 mates, paired with files in <m1>. Could be gzip'ed (extension: .gz) or bzip2'ed (extension: .bz2).

Usage:

	$scriptname {-1 <m1> -2 <m2> | -i <se>} -p <illumina/iontor> -r <PATH>

	Platform: illumina

	$scriptname -1 test.1.fastq -2 test.2.fastq -p illumina -r <PATH>

	Platform: iontor

	$scriptname -i test.fastq -p iontor -r <PATH>

USAGE
	exit
fi

QualityFormat(){
	FASTQ=$1
	Phred=`head -n 40 $FASTQ | awk '{if(NR%4==0) printf("%s",$0);}' \
					  | od -t u1 -A n -v \
					  | awk 'BEGIN{min=100;max=0;}{for(i=1;i<=NF;i++) {if($i>max) max=$i; if($i<min) min=$i;}}END{if(max<=74 && min<59) print "Phred+33"; else if(max>73 && min>=64) print "Phred+64";}'`
	echo $Phred					  
}

#Step 1 Trimmomatic
if [ "$PLATFORM" = "illumina" ]
then
	if [ -f $FORWARD ] && [ -f $BACKWARD ]
	then
		trimmomatic PE -threads 20 \
		$FORWARD $BACKWARD ${FORWARD}_1P.fq ${FORWARD}_1U.fq ${BACKWARD}_2P.fq ${BACKWARD}_2U.fq \
		LEADING:5 TRAILING:5 SLIDINGWINDOW:4:15 MINLEN:50 AVGQUAL:20
		name=${FORWARD%_*} #illumina一般文件名格式 S1109L138_HCM2GCCXY_L7_1.fq
		cat ${FORWARD}_1P.fq ${BACKWARD}_2P.fq | sed 's/\//_/' | sed 's/ /_/'> $name.SE
	fi
elif [ "$PLATFORM" = "iontor" ]
then
	if [ -f $INPUT ]
	then
		name=${INPUT%.*}
		trimmomatic SE -threads 20 \
		$INPUT $name.SE \
		LEADING:5 TRAILING:5 MINLEN:50 AVGQUAL:17
	fi
elif [[ "$PLATFORM" = "pacbio" || "$PLATFORM" = "nano" ]]
then
    if [[ -f $INPUT ]]
    then
        name=${INPUT%.*}
		#echo $name
		#Phred=`QualityFormat $name.SE`
		#echo $Phred
        trimmomatic SE -threads 20 \
        $INPUT $name.SE \
        LEADING:3 TRAILING:3 MINLEN:50 AVGQUAL:5
    fi
fi

#Step 2
# 暂时移除去除低复杂度reads。
#prinseq-lite.pl -fastq $name.SE -out_format 3 -out_good $name.SE.fq –lc_method dust –lc_threshold 7
#mv $name.SE $name.SE.fq

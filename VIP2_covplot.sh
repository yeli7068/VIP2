#!/bin/bash
#
#
#
#       This is the result generation script for the VIP2 pipeline.
#
#
### Authors : Yang Li <yeli7068@outlook.com>
### License : GPL 3 <http://www.gnu.org/licenses/gpl.html>
### Update  : 2019-06-25
#
#  
#
#图像生成模块
# 
# 	   -> kraken =  krona
#mode
#      -> sense  =  class to genus -> coverage map

bold=$(tput bold)
normal=$(tput sgr0)
green='\e[0;32m'
red='\033[31m'
endColor='\033[0m'
blink='\033[05m'
#scriptname=${0##*/}
scriptname=`basename $0`
while getopts ":hr:i:m:p:" option; 
do
	case "${option}" in
		h)	HELP=1
			;;
		r)	REFERENCE_PATH=${OPTARG}
			;; #CMIP work dir
		i)	name=${OPTARG}
			;;
		m)	MODE=${OPTARG}
			;;
		p)  PLATFORM=${OPTARG}
			;;
		:)	echo "Option -$OPTARG requires an argument." >&2
			exit 1
			;;
	esac
done

if [[ $HELP -eq 1  ||  $# -lt 1 ]]
then
	cat <<USAGE

${bold}Welcome to use CMIP for your analysis.
 
Clinical Metagenomics Identification of Pathogen (CMIP) is a semi-automatical computational
pipeline for identification of pathogen.

This program $scriptname perform alignment against candidate database 

${bold}Command Line Switches:${normal}

	-h	Show help & ignore all other switches

		
	-r	Specify the PATH for dependencies

	-m	mode <sense/kraken>
		
		Sense mode performs centrifuge to microbes -> kaiju to Viral proteins -> coverage map + krona visulization
		kraken mode performs kraken to microbes -> krona visulization
	
	-p	Specify the sequencing platform <iontor/illumina/nano/pacbio>
		
	-i	Specify the prefix of NGS files
	

${bold}Usage:${normal}

	$scriptname -m <sense/kraken> -i <name> -r <REFERENCE_PATH>	-p <Platform>
USAGE
	exit
fi

if [ $MODE = "kraken" ] && [ -f $name.centri.out ]
then
	source activate python3.6
	recentrifuge.py -n $REFERENCE_PATH/DATABASE/tax_DB/ -f $name.centri.out -o $name.html
	# kaiju2krona -t $REFERENCE_PATH/DATABASE/tax_DB/nodes.dmp -n $REFERENCE_PATH/DATABASE/tax_DB/scientific_name.dmp -i $name.kraken -o $name.krona
	# ktImportText -o $name.html $name.krona
	cp $name.html ./$name.report/
	source deactivate python3.6
elif [ $MODE = "sense" ] && [ -f $name.consensus_unireads.viruses ]
then
	# 获得unireads对应的属
	# TODO:
	# 需要从unireads.NT获得校验后的结果
	awk '{print$5}' $name.consensus_unireads.viruses  | sed -e 's/;//' | sort -u | egrep -v "^NA" > $name.genusList

	#针对每个属进行分析，默认每次最多10个属同时分析
	num_limits=10 #这里谨慎改变，这个数字是摸索后能最大化利用CPU和IO的结果。238和239通用此结论
	mkdir $name.logs
	[ -e ./tmp ] || mkfifo ./tmp
    exec 3<>./tmp
    rm -rf ./tmp

	
	for ((i=1;i<=$num_limits;i++)) 
	do
		echo >&3
	done
		
	for genus in `cat $name.genusList` 
	do
		read -u3
		{
			VIP2_covplot_map.sh $genus $name $REFERENCE_PATH $PLATFORM >& ./$name.logs/$genus.cov.log
			echo >&3
		}&	
	done
	wait
	
	#收集整理
	cd $name.report
	echo -e "Virus Name\tTaxid\tAccession Number\tCoverage%\tMean Depth" > $name.summary
	cat *.table | sort -t $'\t' -r -n -k4,4 >> $name.summary
	rm -rf *.table
else 
	echo "$scriptname: Please check the mode and input"
	echo "$scriptname -m <sense/kraken> -i <name> -r <REFERENCE_PATH>"
fi
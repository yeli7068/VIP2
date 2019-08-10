#!/bin/bash
#
#
#
#       This is the alignment part script for the VIP2 pipeline.
#
#       
### Authors : Yang Li <yeli7068@outlook.com>
### License : GPL 3 <http://www.gnu.org/licenses/gpl.html>
### Update  : 2019-06-25
#
#   
#Alignment Part
# 	   -> kraken =  kraken (nucl)
#mode
#      -> sense  =  centrifuge (nucl) + kaiju (prot)

set -e

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
			;; 
		i)	INPUT=${OPTARG}
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

${bold}Welcome to use VIP2 for your analysis.

VIP2 is a semi-automatical computational pipeline for identification of pathogen.

This program $scriptname perform alignment against candidate database

${bold}Command Line Switches:${normal}

	-h	Show help & ignore all other switches


	-r	Specify the PATH for dependencies

	-m	mode <sense/kraken>

		Sense mode performs snap to microbes -> kaiju to Viral proteins -> coverage map + krona visulization
		kraken mode performs kraken to microbes -> krona visulization

	-p	Specify the sequencing platform <iontor/illumina/nano/pacbio>

	-i	Specify NGS file for processing


${bold}Usage:${normal}

	$scriptname -m <sense/kraken> -i <INPUT> -r <REFERENCE_PATH> -p <iontor/illumina/nano/pacbio>
USAGE
	exit
fi

name=${INPUT%.*}

if [ "$MODE" = "kraken" ]
then
	centrifuge -x $REFERENCE_PATH/DATABASE/centri_DB/nucl \
			   -p 20 --mm --host-taxids 9606 \
			   -U $name.SE -S $name.centri_out --report-file $name.centri_report 

elif [ "$MODE" = "sense" ]
then
	# alignmet
	centrifuge -x $REFERENCE_PATH/DATABASE/centri_DB/nucl \
			   -p 20 --mm --host-taxids 9606 \
			   -U $name.SE -S $name.centri_out --report-file /dev/null \
			   --un $name.unmatch
			   
    VIP2_aln_parseCentri.pl $name.centri_out $name # output $name.nucl_covreads  $name.cand_unireads

	kaiju -t $REFERENCE_PATH/DATABASE/tax_DB/nodes.dmp \
		  -f $REFERENCE_PATH/DATABASE/viral_DB/viral.fmi \
		  -z 20 -a greedy -e 5 \
		  -i $name.unmatch -o $name.kaiju_out

	# merge nucl_covreads and kaiju_out
	cat $name.nucl_covreads $name.kaiju_out > $name.covreads

	
	# filter non-virus results
	## unireads
	kaiju-addTaxonNames -t $REFERENCE_PATH/DATABASE/tax_DB/nodes.dmp \
						-n $REFERENCE_PATH/DATABASE/tax_DB/scinames.dmp \
						-r superkingdom,genus \
						-i $name.cand_unireads -o $name.cand_unireads.annoted
	 
	grep "Viruses;" $name.cand_unireads.annoted > $name.cand_unireads.viruses

	## recheck unireads
	VIP2_aln_bestHitTaxid.pl $name.cand_unireads.viruses $name 30 # output $name.cand_unireads.bestHit
	
	awk '{print$1}' $name.cand_unireads.bestHit \
		| seqtk subseq $name.SE - \
		| seqtk seq -A - > $name.cand_unireads.fa
	
	if [[ "$PLATFORM" = "iontor" || "$PLATFORM" = "illumina" ]]
	then
		blastn -db $REFERENCE_PATH/DATABASE/blast_DB/viruses_nucl \
			-query $name.cand_unireads.fa \
			-task blastn -max_target_seqs 20 \
			-outfmt '6 std staxids' \
			-num_threads 20 \
			-qcov_hsp_perc 60 \
			-evalue 10e-5 \
			-out $name.cand_unireads.blastn
	else
		blastn -db $REFERENCE_PATH/DATABASE/blast_DB/viruses_nucl \
			-query $name.cand_unireads.fa \
			-task blastn -max_target_seqs 20 \
			-outfmt '6 std staxids' \
			-num_threads 20 \
			-qcov_hsp_perc 30 \
			-evalue 10e-5 \
			-out $name.cand_unireads.blastn
	fi

	VIP2_aln_agreementBlastCentri.py -b $name.cand_unireads.blastn -c $name.cand_unireads.bestHit \
									 -r $REFERENCE_PATH/DATABASE/tax_DB/nodes.db \
	 								 -o $name.consensus_unireads 

	# annotations
	## consensus_unireads
	kaiju-addTaxonNames -t $REFERENCE_PATH/DATABASE/tax_DB/nodes.dmp \
						-n $REFERENCE_PATH/DATABASE/tax_DB/scinames.dmp \
						-r superkingdom,genus \
						-i $name.consensus_unireads -o $name.consensus_unireads.viruses
	## covreads
	kaiju-addTaxonNames -t $REFERENCE_PATH/DATABASE/tax_DB/nodes.dmp \
						-n $REFERENCE_PATH/DATABASE/tax_DB/scinames.dmp \
						-r superkingdom,genus \
						-i $name.covreads -o $name.covreads.annoted

	grep "Viruses;" $name.covreads.annoted > $name.covreads.viruses

	## $name.cand_unireads.viruses

fi

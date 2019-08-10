#!/bin/bash
#
#
#	VIP2_covplot_map.sh
#
#	This program covplot was a submodule of clinical metagenomics identificaiton of pathogen.
#	It will automatically choose the most likely reference genome. The reference genome will be further subject to BLAST alignment for coverage maps.
#	
#	$0\tUsage: <annotated BOWTIE file> <annotated RAPSearch file> <NGS> <mode> <kmer_start> <kmer_end> <kmer_step>
#
### Authors : Yang Li <liyang@ivdc.chinacdc.cn>
### License : GPL 3 <http://www.gnu.org/licenses/gpl.html>
### Update  : 2016-3-28
### Copyright (C) 2016 Yang Li All Rights Reserved

scriptname=${0##*/}

if [ $# -lt 4 ]
then
	#echo -e "$scriptname\tUsage: <genus> <name> <reads_coverage> <tax_dir> <Platform>"
	echo -e "$scriptname\tUsage: <genus> <name> <tax_dir> <Platform>"    
	exit
fi

genus=$1
name=$2
#reads_coverage=$3
REFERENCE_PATH=$3
PLATFORM=$4

if [ -d tmp.$genus ]
then
	rm -rf tmp.$genus
	mkdir tmp.$genus
else
	mkdir tmp.$genus
fi

cd tmp.$genus
#1, 得到属内的unireads和covreads
grep $genus ../$name.consensus_unireads.viruses > $genus.consensus_unireads
grep $genus ../$name.cand_unireads.viruses > $genus.cand_unireads
grep $genus ../$name.covreads.viruses > $genus.covreads

awk '{print$2}' $genus.cand_unireads | awk -F ";" '{print$1}' | sort -u > $genus.cand_unireads.reads
awk '{print$2}' $genus.covreads | sort -u > $genus.covreads.reads
awk '{print$2}' $genus.consensus_unireads | sort -u > $genus.consensus_unireads.reads

cat $genus.cand_unireads.reads $genus.covreads.reads $genus.consensus_unireads.reads > $genus.reads
num_genus_reads=`wc -l $genus.reads | awk '{print$1}'`

#2, 得到所有候选taxid， 从consensus_unireads.viruses
awk '{print$3}' $genus.consensus_unireads | sort -u | egrep -v "^NA" > $genus.taxids

for taxid  in `cat $genus.taxids`
do
	mkdir $taxid
#3, 获得对应taxid的reference
	cd $taxid
	reference=`grep $taxid ../$genus.cand_unireads | \
			   awk '{print$2}' | awk -F ';' '{print$2}' | \
			   awk '{a[$1]++}END{for (i in a) print i" "a[i]}' | \
			   sort -k2,2 -rn | head -n 1 | awk '{print$1}'`

	blastdbcmd -db $REFERENCE_PATH/DATABASE/blast_DB/viruses_nucl \
			   -entry $reference \
			   -out $reference.bwaref.fa

#4, 获取对应taxid的covreads以及unireads
## $taxid.cand_unireads
## $genus.covreads
## $taxid.consensus_unireads
	grep species ../$genus.cand_unireads | awk '{print$2}' | awk -F ';' '{print$1}' | sort -u > $taxid.cand_unireads
	grep $taxid  ../$genus.consensus_unireads | awk '{print$2}' | sort -u > $taxid.consensus_unireads
	ln -s ../$genus.covreads .
	cat $taxid.cand_unireads $taxid.consensus_unireads $genus.covreads | sort -u > $taxid.reads
	seqtk subseq ../../$name.SE $taxid.reads > $taxid.reads.fq
	
#5, aln
	bwa index $reference.bwaref.fa

	if [[ "$PLATFORM" = "pacbio" ]]
	then
		tag="-x pacbio"
	elif  [[ "$PLATFORM" = "nano" ]]
	then
		tag="-x ont2d"
	else
		tag=""
	fi

	bwa mem -t 2 $tag $reference.bwaref.fa $taxid.reads.fq | samtools sort - > $taxid.sorted.bam
	num_hit_reads=`samtools view -c $taxid.sorted.bam`
	BamDeal statistics Coverage -InFile $taxid.sorted.bam -OutPut $taxid  # $taxid.stat $taxid.depth.fa
	gzip -d $taxid.depthsite.fa.gz
	stat_cov=`grep Genome $taxid.stat | awk '{print$3}'`

	if [[ ! -s $taxid.depthsite.fa ]] || [[ $stat_cov -eq 0 ]] 
	then
		cd ..
		continue
	fi


#6, preplot
	ococo -i $taxid.sorted.bam \
		  -c 1 \
		  -F $taxid.consensus.fa
		   
	seqtk subseq ../../$name.SE $taxid.consensus_unireads | seqtk seq -A - > $taxid.consensus_unireads.fa

#7, plot and table
	VIP2_covplot_plot.py -d $taxid.depthsite.fa -s $taxid.stat \
						 -r $REFERENCE_PATH/DATABASE/tax_DB/nodes.db \
						 -e $num_hit_reads -g $num_genus_reads \
						 -t $taxid
						 
	# $taxid.coverage.png $taxid.table $taxid.consensus.fa $taxid.consensus_unireads.fa
	cp $taxid.coverage.png $taxid.table $taxid.consensus.fa $taxid.consensus_unireads.fa ../../$name.report
#8, TODO:phylogenetic tree  
	cd ..
	
	
done
cd ..

# seqtk subseq ../$name.SE.fa candidate.readsids.$genus > candidate.readsids.$genus.fa 
# numTotalReads=`grep -c ">" candidate.readsids.$genus.fa`
# flag=0
# ln candidate.readsids.$genus.fa candidate.readsids.$genus.$flag.fa

# # for gi in `cat candidate.seqids.$genus`
# # do
# gi=`head -n 1 candidate.seqids.$genus`
# 	#1 当前参考序列的
# 	blastdbcmd -db $REFERENCE_PATH/DATABASE/blast_DB/h+b+f+v \
# 	-entry $gi -out temp.$gi.ref.$flag.fa
	
# 	#2 比对
# 	makeblastdb -in temp.$gi.ref.$flag.fa -dbtype nucl  \
# 	-title temp.$gi.ref.$flag.db -out temp.$gi.ref.$flag.db
	
# 	blastn -db temp.$gi.ref.$flag.db \
# 	-query candidate.readsids.$genus.$flag.fa \
# 	-task blastn -reward 1 -penalty -1 -num_threads 5 -outfmt '6 std qlen' \
# 	-out temp.$gi.$flag.blastn -qcov_hsp_perc 60
# 	#3, 得到coverage map
# 	CMIP_plot_blast.sh temp.$gi.$flag.blastn temp.$gi.ref.0.fa $genus $name $flag
# cd ..

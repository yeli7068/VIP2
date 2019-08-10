#!/root/miniconda3/bin/python
# -*- coding: utf-8 -*-
#
#
#       Return reads based on taxid assigned with agreement between Blast and Centrifuge
#
#
### Authors : Yang Li <yeli7068@outlook.com>
### License : GPL 3 <http://www.gnu.org/licenses/gpl.html>
### Update  : 2019-06-25
import os, sys, argparse
import sqlite3

parser = argparse.ArgumentParser(description='Return reads based on taxid assigned with agreement between Blast and Centrifuge ')
parser.add_argument('-b, --blastn', metavar='.blastn', type=argparse.FileType('r'), required=True, dest="blastn",
                    help='Outfmt "6 std staxtid" from Blastn')
parser.add_argument('-o, --output', metavar='.unireads', type=argparse.FileType('w'), required=True, dest='output',
                    help='Outfmt "C ReadsID Taxid"')
parser.add_argument('-r, --refer', metavar='nodes.db', required=True, dest='db',
                    help='The path of nodes.db built by SQlite3')
parser.add_argument('-c, --centri', metavar='.cand_unireads.bestHit', type=argparse.FileType('r'), required=True, dest='centri',
                    help='Best Hit from centrifuge cand_unireads')

args = parser.parse_args()

def taxidLookup(taxid):
    conn = sqlite3.connect(args.db)
    d = conn.cursor()
    rank = ""
    while taxid != 1 :
        d.execute('''select * from nodes where taxid = %s ''' % taxid)
        record = d.fetchone() # (11053, 12637, 'no rank')
        parent_taxid = record[1]
        rank = record[2]
        if rank == 'species' :
            break
        else:
            taxid = parent_taxid
    return taxid

def agreementBlastCentri(blast_taxid, centri_taxid):
    if blast_taxid == centri_taxid:
        return True
    else :
        blast_speices_taxid = taxidLookup(blast_taxid)
        centri_speices_taxid = taxidLookup(centri_taxid)
        if blast_speices_taxid == centri_speices_taxid:
            return True
        else :
            return False

with args.blastn as blastn:
    reads_taxid_score = {}
    for line in blastn.readlines():
        line = line.strip('\n').split('\t')
        readsid = line[0]
        score = line[-2]
        taxid = line[-1]
        
        # 初始化
        if not readsid in reads_taxid_score:
            reads_taxid_score[readsid] = {}
            reads_taxid_score[readsid]['taxid'] = taxid
            reads_taxid_score[readsid]['score'] = score
            reads_taxid_score[readsid]['remove_flag'] = 0
            continue

        if reads_taxid_score[readsid]['remove_flag'] == 1:
            continue
        
        # 同一个taxid 则下一个
        if taxid == reads_taxid_score[readsid]['taxid']:
            continue

        # 不同taxid， 则比较score
        if float(score) * 1.1 > float(reads_taxid_score[readsid]['score']):
            cur_species_taxid = taxidLookup(taxid=taxid)
            ori_species_taxid = taxidLookup(taxid=reads_taxid_score[readsid]['taxid'])
            if cur_species_taxid != ori_species_taxid:
                reads_taxid_score[readsid]['remove_flag'] = 1

with args.centri as centri:
    centri_taxid = {}
    for line in centri.readlines():
        line = line.strip('\n').split('\t')
        readsid = line[0]
        taxid = line[-1]
        centri_taxid[readsid] = taxid        
            
with args.output as output:
    for readsid in reads_taxid_score:
        if reads_taxid_score[readsid]['remove_flag'] == 1:
            continue
        
        agreement = agreementBlastCentri(blast_taxid=reads_taxid_score[readsid]['taxid'], centri_taxid=centri_taxid[readsid])
        if agreement:
            taxid = reads_taxid_score[readsid]['taxid']
            output.write("\t".join(["C", readsid, taxid, "\n"]))

   
        
        

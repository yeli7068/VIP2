#!/root/miniconda3/bin/python


from jinja2 import Environment, FileSystemLoader
from glob import glob
import argparse
import os.path
# -*- coding: utf-8 -*-
parser = argparse.ArgumentParser(
    description='Generate the iteractive coverage map based on depth.fa file')
parser.add_argument('-s, --table', metavar='.summary', type=argparse.FileType('r'), required=True, dest="table",
                    help='Summary Table from VIP2')
parser.add_argument('-l, --template', metavar='.tt', required=True, dest="template",
                    help='Template for VIP2 html')
parser.add_argument('-n, --name', required=True, dest="name",
                    help='Name of NGS')
                  
args = parser.parse_args()
# prepare template
loader = FileSystemLoader(args.template)
env = Environment(loader=loader)
template = env.get_template('VIP2.tt.html')
# prepare inputs
#covplot   = glob("{}.coverage.png".format(taxid))
#consensus = glob("*.consensus.fa")
#reads     = glob("*.consensus_unireads.fa")
print(__file__)
n = 0
lines = []
pics_covplot = {}
seqs_consensus = {}
seqs_reads = {}
with args.table as table:
    for line in table.readlines():
        line = line.strip().split("\t")
        line.append("Consensus Seqs")
        line.append("Confidence Reads")
        taxid = line[1]
        if n == 0:
            header = line
            n += 1
            continue        
        lines.append(line)
        covplot = glob("{}.coverage.png".format(taxid))
        consensus = glob("{}.consensus.fa".format(taxid))
        reads = glob("{}.consensus_unireads.fa".format(taxid))

        pics_covplot[taxid] = covplot[0]
        seqs_consensus[taxid] = consensus[0]
        seqs_reads[taxid] = reads[0]

#path = os.path(args.template)

render_content = template.render(report_name = args.name, 
                                 h = header, 
                                 lines = lines, 
                                 pics_covplot = pics_covplot,
                                 seqs_consensus = seqs_consensus,
                                 seqs_reads = seqs_reads
                                ) 
output = args.name + "_report.html"
with open(output,'w+') as FL:
    FL.write(render_content)








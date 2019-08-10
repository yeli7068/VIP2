#!/root/miniconda3/bin/python
import os
import sys
import argparse
import re
import sqlite3
import matplotlib
matplotlib.use('Agg')

import matplotlib.pyplot as plt
import pandas as pd

plt.style.use('ggplot')
plt.rcParams["font.family"] = "Times"
plt.rcParams['font.size'] = 12

parser = argparse.ArgumentParser(
    description='Generate the iteractive coverage map based on depth.fa file')
parser.add_argument('-d, --depth', metavar='.depthsite.fa', type=argparse.FileType('r'), required=True, dest="depth",
                    help='Output from BamDeal statistics Coverage')

parser.add_argument('-s, --stat', metavar='.stat', type=argparse.FileType('r'), required=True, dest="stat",
                    help='Output from BamDeal statistics Coverage')

parser.add_argument('-r, --refer', metavar='nodes.db', required=True, dest='db',
                    help='The path of nodes.db built by SQlite3')

parser.add_argument('-t, --taxid', required=True, dest="taxid",
                    help='taxid')

parser.add_argument('-e, --hitreads', required=True, dest="hitreads",
                    help='num of hit reads')

parser.add_argument('-g, --genusreads', required=True, dest="genusreads",
                    help='num of reads under genus')


args = parser.parse_args()


def TaxidNameLookup(taxid):
    conn = sqlite3.connect(args.db)
    d = conn.cursor()
    d.execute('''select * from names where taxid = %s ''' % taxid)
    record = d.fetchone()
    sciname = record[1]
    return sciname


n = 0

taxid = args.taxid
sciname = TaxidNameLookup(taxid=taxid)
# ciname = "_".join(sciname.split(' '))

with args.stat as stat:
    for line in stat.readlines():
        if re.search("^#", line):
            n += 1
            continue
        if n == 1:
            line = line.strip('\n').split('\t')
            reference = line[0]
            reflength = line[1]
            covlength = line[2]
            coverage = line[4]
            meandepth = line[5]
            break

n = 0
with args.depth as depth:
    for line in depth.readlines():
        line = line.strip('\n').split(' ')
        if n == 0:
            n += 1
            continue

        if n == 1:
            df = pd.DataFrame({'depth':line}, dtype='int32')

reportText = '''
Name  of  Virus : {}
Accession Number: {}

Details:
Length of Reference: {} bp     Length covered: {} bp     
Coverage: {}%     
Mean Depth: {}
Num. of Hit Reads: {}     Num. of Reads Under Genus: {}
'''.format(sciname, reference, reflength, covlength, coverage, meandepth, args.hitreads, args.genusreads)

fig, ax = plt.subplots(1,1, figsize=(12,7))
ax.plot(df['depth'], 'b')
ax.set_yscale('log')
ax.set_xlabel("base position (bp)")   
ax.set_ylabel("fold coverage (X)")
ax.set_title("Coverage Map for {}".format(sciname))

fig.text(0.15, 0.1,reportText, fontsize=13) 
#fig.grid(True)
fig.subplots_adjust(bottom=0.5)

outputfig = taxid + ".coverage.png"
plt.savefig(outputfig, format='png')

outputtable = taxid + ".table"
with open(outputtable, "w") as f:
    f.write("\t".join([sciname, taxid, reference, coverage, meandepth, "\n"]))

#             fig = go.Figure(data=go.Scatter(y=line))
# fig.update_layout(
#     yaxis_title='Fold Coverage',
#     xaxis_title='Base Position (bp)',
#     width=1200, height=800
# )


# title='''
# <b>Name of Virus:</b> {}
#     <b>Reference Accession Number:</b> {}
# <br>
# <b>Length of Virus:</b> {} bp
#     <b>Length covered:</b> {} bp
#     <b>Coverage:</b> {}%
#     <b>Mean Depth:</b> {}
# <br>
# <b>Num. of Hit Reads:</b> {}
#     <b>Num. of Reads Under Genus:</b> {}
# '''.format(sciname, reference, reflength, covlength, coverage, meandepth, args.hitreads, args.genusreads)
# )

# fig.update_yaxes(type="log")
# fig.show()
# output

# outputfig = sciname + ".coverage.png"
# outputtable = sciname + ".table"

# fig.write_image(outputfig)
# with open(outputtable, "w") as f:
#     f.write("\t".join([sciname, taxid, reference, coverage, meandepth, "consensus seq", "confident reads"]))


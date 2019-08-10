#!/usr/bin/perl
#
#
#       keep best hit by length with limit number per taxid.
#
#
### Authors : Yang Li <yeli7068@outlook.com>
### License : GPL 3 <http://www.gnu.org/licenses/gpl.html>
### Update  : 2019-06-25
#
#

if (@ARGV != 3) {
	die "Usage: $0 <cand_unireads.viruses> <name> <num_reads_to_keep>\n";
}

$name = $ARGV[1]; 
$num_reads_to_keep = $ARGV[2];
open FL, "$ARGV[0]" or die "Can open file $ARGV[0]:$!\n";
open OUT, ">$name.cand_unireads.bestHit";
# input: 
# C       KFALO:02055:02711;species;199   12637   Viruses; Flavivirus;
# C       KFALO:03386:02640;KX621249.1;154        11053   Viruses; Flavivirus;
while(<FL>){
    chomp;
    @tmp = split /\t/;
    @records = split /;/, $tmp[1];
    next if $records[1] !~ /\./ ;  # remove no seqids
    #$dir{$tmp[2]}{"Length"} .= "$records[2]\t";
    $dir{$tmp[2]}{$records[0]} = "$records[2]\t";  #$dir{taxid}{reads} = length
}

for $taxid ( keys %dir ) {
    %reads_length = %{$dir{$taxid}};
    if ( %reads_length > $num_reads_to_keep ) {
        # 比较长度后取top 默认30
        @reads_sorted = sort { $reads_length{$b} cmp $reads_length{$a} } keys %reads_length;
        @reads_sorted = @reads_sorted[0..$num_reads_to_keep-1];     
    } else {
        @reads_sorted = keys %reads_length;
    }
    $sep = "\t$taxid\n";
    $reads_output = join $sep, @reads_sorted;
    print OUT "$reads_output\t$taxid\n";  
}

close OUT;
close FL;
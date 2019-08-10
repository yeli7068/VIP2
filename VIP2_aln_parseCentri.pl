#!/usr/bin/perl 
#
#       This is for parsing centrifuge results the VIP2 pipeline.
#
#
### Authors : Yang Li <yeli7068@outlook.com>
### License : GPL 3 <http://www.gnu.org/licenses/gpl.html>
### Update  : 2019-06-25
#
#  
open FL, "$ARGV[0]";
open COVREADS, ">$ARGV[1].nucl_covreads";
open UNIREADS, ">$ARGV[1].cand_unireads";
<FL>; # Remove Head Line

while (<FL>) {
    chomp;
    @tmp = split /\t/;
    next if $tmp[2] == 9606 || $tmp[2] == 0 || $tmp[2] == 1;
    $readsUniq{$tmp[0]}{"hitLength"} = $tmp[5];
    if ($tmp[-1] != 1) {
        $readsUniq{$tmp[0]}{"UNIQ"} = 1 unless defined $readsUniq{$tmp[0]}{"UNIQ"};
        $readsUniq{$tmp[0]}{'Taxid'} = $tmp[2] unless defined $readsUniq{$tmp[0]}{'Taxid'};
        if ($readsUniq{$tmp[0]}{"Taxid"} == $tmp[2]) {
            $readsUniq{$tmp[0]}{"UNIQ"} = 1 if $readsUniq{$tmp[0]}{"UNIQ"} != 0 ;
            $readsUniq{$tmp[0]}{"SEQS"} .= "$tmp[1];";
        } else {
            $readsUniq{$tmp[0]}{"UNIQ"} = 0;
            $readsUniq{$tmp[0]}{'Taxid'} .= ";$tmp[2]";
        }
    } else {
        $readsUniq{$tmp[0]}{"UNIQ"} = 1;
        $readsUniq{$tmp[0]}{'Taxid'} = $tmp[2];
        $readsUniq{$tmp[0]}{'SEQS'} = $tmp[1];
    }
}

for $reads (keys %readsUniq) {
    if ($readsUniq{$reads}{"UNIQ"} == 1) {
        @tmp_seqs = split /;/, $readsUniq{$reads}{"SEQS"};
        for $tmp_seq (@tmp_seqs) {
            next if $tmp_seq !~ /species|\./ ;
            print UNIREADS "C\t$reads;$tmp_seq;$readsUniq{$reads}{'hitLength'}\t$readsUniq{$reads}{'Taxid'}\n";
        }
    } else {
        @tmp_taxids = split /;/, $readsUniq{$reads}{'Taxid'};
        for $tmp_taxid (@tmp_taxids) {
            print COVREADS "C\t$reads\t$tmp_taxid\n";
        }
    }
}

close UNIREADS;
close COVREADS;
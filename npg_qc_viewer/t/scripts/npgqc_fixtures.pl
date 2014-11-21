#!/usr/bin/env perl

use strict;
use warnings;
use npg_qc::Schema;
use t::util;

my $util = t::util->new();
my $path = q[t/data/fixtures/npgqc];
my $real = npg_qc::Schema->connect();

my @tables =  qw(
             Adapter
             InsertSize
             Contamination
             QxYield
             SequenceError
		);

foreach my $tname (@tables) {
    my $rs = $real->resultset($tname)->search(
            [{id_run => 4099}, {id_run => 4025}, {id_run => 4950, position => 1}]
    );
    if ($rs->count > 0) {
        $util->rs_list2fixture($tname, [$rs], $path);
    } 
}

1;

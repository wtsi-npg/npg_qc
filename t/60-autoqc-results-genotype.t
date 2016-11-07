use strict;
use warnings;
use Test::More tests => 4;

use_ok ('npg_qc::autoqc::results::genotype');
use_ok ('npg_qc::autoqc::results::collection');

{
    my $r = npg_qc::autoqc::results::genotype->new(id_run => 2, path => q[mypath], position => 1);
    isa_ok ($r, 'npg_qc::autoqc::results::genotype');
}

{
    my $c=npg_qc::autoqc::results::collection->new();
    $c->add_from_dir(q[t/data/autoqc/genotype], [1], 6812);
    $c=$c->slice('class_name', 'genotype');

    is($c->results->[0]->criterion(), q[Sample name is PD6732b_wg, number of common SNPs >= 21 and percentage of loosely matched calls > 95% (fail: < 50%)], 'criteria');
}


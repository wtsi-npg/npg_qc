use strict;
use warnings;
use Test::More tests => 4;

use_ok ('npg_qc::autoqc::results::genotype');

my $r = npg_qc::autoqc::results::genotype->new(id_run => 2, position => 1);
isa_ok ($r, 'npg_qc::autoqc::results::genotype');

$r = npg_qc::autoqc::results::genotype->load('t/data/autoqc/genotype/6812_1.genotype.json');
isa_ok ($r, 'npg_qc::autoqc::results::genotype');
is($r->criterion(),
  q[Sample name is PD6732b_wg, number of common SNPs >= 21 and percentage of loosely matched calls > 95% (fail: < 50%)],
  'criteria');

1;



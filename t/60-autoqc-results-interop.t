use strict;
use warnings;
use Test::More tests => 3;
use Test::Exception;

use npg_tracking::glossary::composition::component::illumina;
use npg_tracking::glossary::composition;

my @METHODS = qw/
  aligned_mean
  aligned_stdev
  occupied_mean
  occupied_stdev
  cluster_count_total
  cluster_count_mean
  cluster_count_stdev
  cluster_pf_mean
  cluster_pf_stdev
  cluster_count_pf_total
  cluster_count_pf_mean
  cluster_count_pf_stdev
  cluster_density_mean
  cluster_density_stdev
  cluster_density_pf_mean
  cluster_density_pf_stdev
/;

use_ok('npg_qc::autoqc::results::interop');

my $composition = npg_tracking::glossary::composition->new(
  components => [
    npg_tracking::glossary::composition::component::illumina->new(
      id_run => 1, position => 1
    )
  ]
);
my $r = npg_qc::autoqc::results::interop->new(composition => $composition);
isa_ok ($r, 'npg_qc::autoqc::results::interop');

subtest 'result object methods' => sub {
  plan tests => 16;

  my $i = npg_qc::autoqc::results::interop->new(composition => $composition);
  for my $method (@METHODS) {
    lives_ok {$i->$method} "can call $method method";
  }
};

1;
use strict;
use warnings;
use Test::More tests => 24;
use Test::Exception;
use File::Temp qw/ tempdir /;

use_ok ('npg_qc::autoqc::checks::pulldown_metrics');

my $dir = tempdir( CLEANUP => 1 );
`touch $dir/CalculateHsMetrics.jar`;

{
  local $ENV{CLASSPATH} = $dir;
  my $pdm = npg_qc::autoqc::checks::pulldown_metrics->new(
    id_run => 2, path => q[t], position => 1, repository => q[t/data]);
  isa_ok ($pdm, 'npg_qc::autoqc::checks::pulldown_metrics');
  lives_ok { $pdm->result; } 'result object created';

  local $ENV{CLASSPATH} = q[];
  throws_ok {npg_qc::autoqc::checks::pulldown_metrics->new(
    id_run => 2, path => q[t], position => 1, repository => q[t/data])}
    qr/Can\'t find \'CalculateHsMetrics\.jar\' because CLASSPATH is not set/,
    q[Fails to create object when CalculateHsMetrics.jar not found];
}

{
  local $ENV{CLASSPATH} = $dir;
  my @checks = ();
  push @checks, npg_qc::autoqc::checks::pulldown_metrics->new(
    id_run => 2, qc_in => q[t], position => 1,  repository => q[t/data]);
  push @checks, npg_qc::autoqc::checks::pulldown_metrics->new(
    rpt_list => '2:1', qc_in => q[t], repository => q[t/data]);

  foreach my $pdm (@checks) {
    throws_ok {$pdm->_parse_metrics()} qr/cannot\ parse\ picard\ pulldown\ metrics/,
      'error if file handle is not passed to the parser';
    open my $fh, '<', 't/data/autoqc/pulldown_metrics/pdm.out' or die
      'Cannot open pilldown metrics test file';

    my $results_hash;
    lives_ok { $results_hash = $pdm->_parse_metrics($fh) } 'parsing picard metrics lives';
    close $fh;

    is (scalar keys %{$results_hash}, 40, 'correct number of fields saved in a hash');
    is ($results_hash->{BAIT_TERRITORY}, 51543125, 'bait territory value');
    is ($results_hash->{READ_GROUP}, undef,
      'read group - last value in the row - is undefined');

    lives_ok { $results_hash = $pdm->_save_results($results_hash) }
      'saving results to the result object lives';
    is ($pdm->result->other_metrics->{PCT_SELECTED_BASES}, 0.882919,
      'one of other values');
    ok (!exists $pdm->result->other_metrics->{BAIT_TERRITOTY},
      'bait territory does not exist on other metrics');
    is ( $pdm->result->bait_territory, 51543125,
      q[bait territory value from the result's object attribute]);
    is ( $pdm->result->mean_bait_coverage, 41.044036, q[mean bait coverage]);
  }
}

1;

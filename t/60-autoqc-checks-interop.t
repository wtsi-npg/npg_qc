use strict;
use warnings;
use Test::More tests => 8;
use Test::Exception;
use File::Temp qw/tempdir/;
use File::Slurp;
use Moose::Meta::Class;

use_ok('npg_qc::autoqc::checks::interop');
use_ok('npg_qc::autoqc::results::interop');

my $tdir = tempdir( CLEANUP => 1 );
my $interop_dir = 't/data/autoqc/180626_A00538_0008_AH5HJ5DSXX/InterOp';

# RunInfo.xml and RunParameters.xml files are available
# for some of test run folder since they might be used later.

subtest 'result object properties' => sub {
  plan tests => 15;

  my $i = npg_qc::autoqc::checks::interop->new(qc_in    => $interop_dir,
                                               rpt_list => '34:1;34:2;34:3');
  isa_ok ($i, 'npg_qc::autoqc::checks::interop');
  isa_ok ($i->result, 'ARRAY', 'results attribute');
  is (scalar @{$i->result}, 3, 'three result objects');
  my $position = 1;
  for my $r (@{$i->result}) {
    isa_ok ($r, 'npg_qc::autoqc::results::interop');
    my @info_keys = qw/Check Check_version Custom_parser Custom_parser_version/;
    is_deeply ([sort keys %{$r->info}], \@info_keys,
      'correct info keys');
    is ($r->composition->freeze2rpt, join(q[:], 34, $position),
      'composition object is for a single lane');
    is ($r->filename4serialization, q[34_] . $position . q[.interop.json],
      'file name for serialisation');
    $position++;
  }
};

subtest 'parse and produce results - one lane' => sub {
  plan tests => 8;
  
  my $output_dir = join q[/], $tdir, 'onelane_three_reads';
  mkdir $output_dir or die "failed to create $output_dir";
  
  my @temp = split /\//, $interop_dir;
  pop @temp;
  my $rf = join q[/], @temp;

  my $i = npg_qc::autoqc::checks::interop->new(qc_in    => $rf,
                                               qc_out   => $output_dir,
                                               rpt_list => '34:1');
  throws_ok {$i->run } qr/$rf\/TileMetricsOut\.bin/,
    'error when run folder is given as qc_in';
 
  $i = npg_qc::autoqc::checks::interop->new(qc_in    => $interop_dir,
                                            qc_out   => $output_dir,
                                            rpt_list => '34:1'); 
  lives_ok { $i->run } 'check runs OK';
  isa_ok ($i->result, 'ARRAY', 'results attribute'); 
  is (scalar keys @{$i->result}, 1, 'one result is available in the array');

  my %lane_metrics = ();
  $lane_metrics{'aligned_mean'}->{1}        = 0.731618344783783;
  $lane_metrics{'aligned_mean'}->{4}        = 0.724208116531372;
  $lane_metrics{'aligned_stdev'}->{1}       = 0;
  $lane_metrics{'aligned_stdev'}->{4}       = 0;
  $lane_metrics{'cluster_count_mean'}       = 4091904;
  $lane_metrics{'cluster_count_pf_mean'}    = 2875527;
  $lane_metrics{'cluster_count_pf_stdev'}   = 0;
  $lane_metrics{'cluster_count_pf_total'}   = 2875527;
  $lane_metrics{'cluster_count_stdev'}      = 0;
  $lane_metrics{'cluster_count_total'}      = 4091904;
  $lane_metrics{'cluster_density_mean'}     = 2961263.95700836;
  $lane_metrics{'cluster_density_pf_mean'}  = 2080985.88395631;
  $lane_metrics{'cluster_density_pf_stdev'} = 0;
  $lane_metrics{'cluster_density_stdev'}    = 0;
  $lane_metrics{'cluster_pf_mean'}          = 70.2735694679054;
  $lane_metrics{'cluster_pf_stdev'}         = 0;
  $lane_metrics{'occupied_mean'}            = 76.2887887887888;
  $lane_metrics{'occupied_stdev'}           = 0;

  is_deeply($i->result->[0]->metrics, \%lane_metrics,
    'parsed values as expected');

  my $output_file = join q[/], $output_dir, q[34_1.interop.json];
  ok (-e $output_file, 'output JSON file exists');
  my $r = npg_qc::autoqc::results::interop->thaw(read_file($output_file));
  is_deeply($r->metrics, \%lane_metrics, 'metrics as expected');
  is ($r->composition->freeze2rpt, '34:1', 'correct rpt list');
};

subtest 'mismatch between requested lanes and available data' => sub {
  plan tests => 4;
  
  my $output_dir = join q[/], $tdir, 'error';
  mkdir $output_dir or die "failed to create $output_dir";

  my $i = npg_qc::autoqc::checks::interop->new(qc_in    => $interop_dir,
                                               qc_out   => $output_dir,
                                               rpt_list => '34:1;34:2;34:4');
  my $error = 'ERROR: No data available for lane 2' . "\n" .
              'No data available for lane 4';
  throws_ok { $i->run } qr/$error/,
    'error when no data for some of the requested lanes';
  my $num_output_files = scalar glob "$output_dir/*.json";
  ok (!$num_output_files, 'output file is not generated');

  $i = npg_qc::autoqc::checks::interop->new(qc_in    => $interop_dir,
                                            qc_out   => $output_dir,
                                            rpt_list => '34:2;34:4');
  throws_ok { $i->run } qr/$error/,
    'error when no data for all of the requested lanes';
  $num_output_files = scalar glob "$output_dir/*.json";
  ok (!$num_output_files, 'output file is not generated');
};

subtest 'parse and produce results - one lane, three non-index reads' => sub {
  plan tests => 5;

  my $idir = 't/data/autoqc/191210_MS2_MiSeq_walk-up_246_A_MS8539685-050V2/InterOp'; 
  my $output_dir = join q[/], $tdir, 'onelane';
  mkdir $output_dir or die "failed to create $output_dir";

  my $i = npg_qc::autoqc::checks::interop->new(qc_in    => $idir,
                                               qc_out   => $output_dir,
                                               rpt_list => '246:1');
  lives_ok { $i->run } 'check runs OK';
  isa_ok ($i->result, 'ARRAY', 'results attribute'); 
  is (scalar keys @{$i->result}, 1, 'one result is available in the array');
  my $output_file = join q[/], $output_dir, q[246_1.interop.json];
  ok (-e $output_file, 'output JSON file exists');

  my $expected = {
               'cluster_density_mean' => 509970.205357143,
               'cluster_density_pf_mean' => 472729.183035714,
               'cluster pf_stdev' => 1.83651769480344,
               'cluster_count_pf_total' => 8964585,
               'cluster_count_pf_stdev' => 10581.465013129,
               'cluster_count_pf_mean' => 320163.75,
               'cluster_count_total' => 9670473,
               'aligned_stdev' => {
                                    '2' => 0,
                                    '1' => 0,
                                    '4' => 0
                                  },
               'cluster pf_mean' => 92.6941024179003,
               'cluster_count_mean' => 345374.035714286,
               'cluster_count_stdev' => 8060.09656445299,
               'cluster_density_pf_stdev' => 16324.7743431066,
               'cluster_density_stdev' => 13635.1053215914,
               'aligned_mean' => {
                                   '2' => 0,
                                   '1' => 0,
                                   '4' => 0
                                 }
                 };
  
  is_deeply ($i->result->[0]->metrics, $expected, 'correct computed data');
};

subtest 'parse and produce results - NovaSeq' => sub {
  plan tests => 12;

  my $idir = 't/data/autoqc/200117_A00715_0080_BHY7T3DSXX/InterOp';

  # Output files in a common directory
  my $output_dir = join q[/], $tdir, 'novaseq';
  mkdir $output_dir or die "failed to create $output_dir";
  my $i = npg_qc::autoqc::checks::interop->new(qc_in    => $idir,
                                               qc_out   => $output_dir,
                                               rpt_list => '32798:1;32798:2');
  lives_ok { $i->run } 'check runs OK';
  isa_ok ($i->result, 'ARRAY', 'results attribute'); 
  is (scalar keys @{$i->result}, 2, 'two results are available in the array');
  my $output_file = join q[/], $output_dir, q[32798_1.interop.json];
  ok (-e $output_file, 'output JSON file for lane 1 exists');
  $output_file = join q[/], $output_dir, q[32798_2.interop.json];
  ok (-e $output_file, 'output JSON file for lane 2 exists');
  $output_file = join q[/], $output_dir, q[32798_3.interop.json];
  ok (!-e $output_file, 'output JSON file for lane 3 does not exists');
  $output_file = join q[/], $output_dir, q[32798_4.interop.json];
  ok (!-e $output_file, 'output JSON file for lane 4 does not exists');

  # Output files in individual directories
  $output_dir = join q[/], $tdir, 'novaseq1';
  mkdir $output_dir or die "failed to create $output_dir";
  my $output_dir2 = join q[/], $tdir, 'novaseq2';
  mkdir $output_dir2 or die "failed to create $output_dir";
  $i = npg_qc::autoqc::checks::interop->new(qc_in    => $idir,
                                            qc_out   => [$output_dir, $output_dir2],
                                            rpt_list => '32798:1;32798:2');
  lives_ok { $i->run } 'check runs OK';
  $output_file = join q[/], $output_dir, q[32798_1.interop.json];
  ok (-e $output_file, 'output JSON file for lane 1 exists');
  $output_file = join q[/], $output_dir2, q[32798_2.interop.json];
  ok (-e $output_file, 'output JSON file for lane 2 exists');

  my $expected = {
               'cluster_count_total' => '3830022144',
               'cluster_density_stdev' => '4.65910237492488e-09',
               'aligned_mean' => {
                                   '1' => '1.23699507117271',
                                   '4' => '1.22529613785446'
                                 },
               'cluster_density_pf_mean' => '2261976.39832653',
               'aligned_stdev' => {
                                    '1' => '0.0744209146497674',
                                    '4' => '0.0749524762829369'
                                  },
               'cluster_count_pf_total' => '2925581718',
               'cluster_count_mean' => '4091904',
               'cluster_pf_mean' => '76.3855039998432',
               'occupied_mean' => '81.8342595462549',
               'cluster_density_mean' => '2961263.95700836',
               'cluster_density_pf_stdev' => '81163.8726584454',
               'cluster_count_pf_stdev' => '112153.046809817',
               'occupied_stdev' => '3.92870603224398',
               'cluster_count_pf_mean' => '3125621.49358974',
               'cluster_pf_stdev' => '2.74085234672704',
               'cluster_count_stdev' => '0'
                 };
  is_deeply ($i->result->[0]->metrics, $expected, 'correct computed data for lane 1');

  $expected =     {
               'cluster_count_pf_stdev' => '130105.986633121',
               'cluster_density_pf_stdev' => '94156.2091407017',
               'cluster_count_pf_mean' => '3080377.78418803',
               'cluster_pf_stdev' => '3.17959528456976',
               'occupied_stdev' => '3.93473277812932',
               'cluster_count_stdev' => '0',
               'cluster_count_pf_total' => '2883233606',
               'cluster_count_mean' => '4091904',
               'occupied_mean' => '79.9246783676036',
               'cluster_pf_mean' => '75.2798155623404',
               'cluster_density_mean' => '2961263.95700836',
               'aligned_mean' => {
                                   '4' => '1.20933121442795',
                                   '1' => '1.21915926535924'
                                 },
               'cluster_density_pf_mean' => '2229234.04514996',
               'aligned_stdev' => {
                                    '4' => '0.061127208140241',
                                    '1' => '0.0621184821025787'
                                  },
               'cluster_count_total' => '3830022144',
               'cluster_density_stdev' => '4.65910237492488e-09'
                  };
  is_deeply ($i->result->[1]->metrics, $expected, 'correct computed data for lane 2');
};

subtest 'not setting rpt_list attribute' => sub {
  plan tests => 17;

  my $rf = 't/data/autoqc/200117_A00715_0080_BHY7T3DSXX';
  my $output_dir = join q[/], $tdir, 'novaseq_norpt';
  mkdir $output_dir or die "failed to create $output_dir";
  my $i = npg_qc::autoqc::checks::interop->new(qc_in  => $rf,
                                               qc_out => $output_dir,
                                               id_run => 32798,
                                               _npg_tracking_schema => undef);
  is ($i->rpt_list, '32798:1;32798:2;32798:3;32798:4',
    'rpt list is built correctly');
  lives_ok { $i->run } 'check runs OK';
  is (scalar keys @{$i->result}, 4, 'four results are available');
  is ($i->result->[0]->cluster_count_total, 3830022144,
    'cluster count for lane 1');
  for my $lane ((1 .. 4)) {
    my $output_file = join q[/], $output_dir, qq[32798_${lane}.interop.json];
    ok (-e $output_file, qq[output JSON file for lane $lane exists]);
  }

  $output_dir = join q[/], $tdir, 'novaseq_norpt_norun';
  mkdir $output_dir or die "failed to create $output_dir";
  throws_ok { npg_qc::autoqc::checks::interop->new(
                qc_in  => $rf,
                qc_out => $output_dir,
                _npg_tracking_schema => undef) }
    qr/Unable to identify id_run with data provided/,
    'with no access to the db, trying to use ExperimentName, ' .
    'which is not integer';

  my $schema = Moose::Meta::Class->create_anon_class(
    roles => [qw/npg_testing::db/])
    ->new_object({})->create_test_db(
      q[npg_tracking::Schema], q[t/data/fixtures/npg_tracking]);

  $i = npg_qc::autoqc::checks::interop->new(qc_in  => $rf,
                                            qc_out => $output_dir);
  is ($i->rpt_list, '32798:1;32798:2;32798:3;32798:4',
    'rpt list is built correctly');
  lives_ok { $i->run } 'check runs OK';
  is (scalar keys @{$i->result}, 4, 'four results are available');
  is ($i->result->[0]->cluster_count_total, 3830022144,
    'cluster count for lane 1');
  for my $lane ((1 .. 4)) {
    my $output_file = join q[/], $output_dir, qq[32798_${lane}.interop.json];
    ok (-e $output_file, qq[output JSON file for lane $lane exists]);
  }
};

1;

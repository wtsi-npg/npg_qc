use strict;
use warnings;
use Test::More tests => 14;
use Test::Exception;
use Moose::Meta::Class;
use npg_testing::db;

BEGIN {
  use_ok(q{npg_qc::illumina::loader::Cluster_Density});
}

local $ENV{'dev'} = 'test';
my $db_helper =  Moose::Meta::Class->create_anon_class(
  roles => [qw/npg_testing::db/])
  ->new_object({ config_file => q[t/data/config.ini],});
my $schema = $db_helper->deploy_test_db(q[npg_qc::Schema],q[t/data/fixtures]);
my $schema_tracking = $db_helper->deploy_test_db(q[npg_tracking::Schema],q[t/data/fixtures/npg_tracking]);

{
  my $monitor;
  lives_ok { $monitor = npg_qc::illumina::loader::Cluster_Density->new(
         schema => $schema,
         schema_npg_tracking => $schema_tracking
      ); } q{loader object creation ok};
  isa_ok( $monitor, q{npg_qc::illumina::loader::Cluster_Density}, q{object test});
  is(scalar keys %{$monitor->runlist_db()}, 0, 'no run in the database');

  $monitor->runfolder_list_todo({13108 => 't/data/nfs/sf44/ILorHSany_sf25/incoming/140601_HS2_13108_A_C37W5ACXX'});
  is(scalar keys %{$monitor->runfolder_list_todo()}, 1, 'one runfolder to do');
  lives_ok { $monitor->run_all(); } q{save all runs};
  $monitor->clear_runlist_db();
  is(scalar keys %{$monitor->runlist_db()}, 1, '1 run in the database now');
}

{
  my $runfolder_path = qq{t/data/nfs/sf44/ILorHSany_sf25/incoming/140605_HS36_13169_B_H9FP5ADXX};

  my $loader;
  lives_ok { $loader = npg_qc::illumina::loader::Cluster_Density->new({
                            runfolder_path => $runfolder_path,
                            id_run => 13169,
                            schema => $schema,
                            schema_npg_tracking => $schema_tracking,
  }); } q{loader object creation ok};

  is($loader->tile_metrics_interop_file(), q{t/data/nfs/sf44/ILorHSany_sf25/incoming/140605_HS36_13169_B_H9FP5ADXX/InterOp/TileMetricsOut.bin}, 'correct tile metrics file name');

  my $cluster_density_by_lane = $loader->parsing_interop($loader->tile_metrics_interop_file());
  is($cluster_density_by_lane->{1}->{'cluster density'}->{min}, '787647.75', 'correct value for lane 1 min');
  is($cluster_density_by_lane->{2}->{'cluster density'}->{max}, '1091274.75', 'correct value for lane 2 max');
  is($cluster_density_by_lane->{1}->{'cluster density pf'}->{p50}, '845403.09375', 'correct value for pf lane 1 p50');

  lives_ok {
    $loader->save_to_db({lane=>1, is_pf=>0, min=>9667.00, max=>97777.00, p50=>88888.00});
  } 'no croak when saving one row';

  lives_ok {
    $loader->save_to_db_list($cluster_density_by_lane);
  } 'no croak when saving a list of rows';
}

1;

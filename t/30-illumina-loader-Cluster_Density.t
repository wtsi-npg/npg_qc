use strict;
use warnings;
use Test::More tests => 15;
use Test::Exception;
use npg_testing::db;

BEGIN {
  use_ok(q{npg_qc::illumina::loader::Cluster_Density});
}

$ENV{dev} = 'test';
my $schema = npg_testing::db::deploy_test_db(q[npg_qc::Schema],q[t/data/fixtures]);
my $schema_tracking = npg_testing::db::deploy_test_db(q[npg_tracking::Schema],);
{
  my $monitor;
  lives_ok { $monitor = npg_qc::illumina::loader::Cluster_Density->new(
         schema => $schema,
         schema_npg_tracking => $schema_tracking
      ); } q{loader object creation ok};
  isa_ok( $monitor, q{npg_qc::illumina::loader::Cluster_Density}, q{object test});
  is(scalar keys %{$monitor->runlist_db()}, 0, 'no run in the database');

  $monitor->runfolder_list_todo({4281 => 't/data/nfs/sf44/IL1/outgoing/100121_IL30_4281'});
  is(scalar keys %{$monitor->runfolder_list_todo()}, 1, 'one runfolder to do');
  lives_ok { $monitor->run_all(); } q{save all runs};
  $monitor->clear_runlist_db();
  is(scalar keys %{$monitor->runlist_db()}, 1, '1 run in the database now');
}

{
  my $runfolder_path = qq{t/data/nfs/sf44/IL1/outgoing/080530_IL1_0956};

  my $loader;
  lives_ok { $loader = npg_qc::illumina::loader::Cluster_Density->new({
                            runfolder_path => $runfolder_path,
                            id_run => 956,
                            schema => $schema,
                            schema_npg_tracking => $schema_tracking,
  }); } q{loader object creation ok};

  is($loader->raw_xml_file(), q{t/data/nfs/sf44/IL1/outgoing/080530_IL1_0956/Data/reports/NumClusters By Lane.xml}, 'correct raw xml file name');
  is($loader->pf_xml_file(), q{t/data/nfs/sf44/IL1/outgoing/080530_IL1_0956/Data/reports/NumClusters By Lane PF.xml}, 'correct pf xml file name');

  my $cluster_density_by_lane = $loader->parsing_xml($loader->raw_xml_file());
  is($cluster_density_by_lane->{1}->{min}, '619376.000', 'correct value for lane 1 min');
  is($cluster_density_by_lane->{4}->{max}, '196241.200', 'correct value for lane 4 max');
  is($cluster_density_by_lane->{8}->{p50}, '690931.800', 'correct value for lane 8 p50');

  lives_ok {
    $loader->save_to_db({lane=>1, is_pf=>0, min=>9667.00, max=>97777.00, p50=>88888.00});
  } 'no croak when saving one row';

  lives_ok {
    $loader->save_to_db_list($cluster_density_by_lane, 0);
  } 'no croak when saving a list of rows';
}

1;

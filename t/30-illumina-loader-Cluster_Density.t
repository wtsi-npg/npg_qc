use strict;
use warnings;
use Test::More tests => 7;
use Test::Exception;
use Moose::Meta::Class;
use npg_testing::db;

use_ok(q{npg_qc::illumina::loader::Cluster_Density});

local $ENV{'dev'} = 'test';
my $db_helper =  Moose::Meta::Class->create_anon_class(
  roles => [qw/npg_testing::db/])
  ->new_object({ config_file => q[t/data/config.ini],});
my $schema = $db_helper->deploy_test_db(q[npg_qc::Schema],q[t/data/fixtures]);

{
  my $rs =    $schema->resultset('ClusterDensity');
  is ($rs->search()->count(), 0, 'initially no data present');

  my $rfolders = {13108 => 't/data/nfs/sf44/ILorHSany_sf25/incoming/140601_HS2_13108_A_C37W5ACXX',
                  13169 => 't/data/nfs/sf44/ILorHSany_sf25/incoming/140605_HS36_13169_B_H9FP5ADXX'};
  my $monitor;
  lives_ok {
    $monitor = npg_qc::illumina::loader::Cluster_Density->new(
                 schema => $schema, runfolder_list_todo => $rfolders) 
           } q{loader object creation ok};
  isa_ok( $monitor, q{npg_qc::illumina::loader::Cluster_Density});
  lives_ok { $monitor->run_all(); } q{saves two runs};

  my $expected = {
         '13169' => {'1' => {'0' => ['787647.75','1074773.75','898249.844'],
                             '1' => ['750346.875','999689','845403.094']},
                     '2' => {'1' => ['751032.125','1010533.125','847345.562'],
                             '0' => ['787547.5','1091274.75','897271.031']}},
         '13108' => {'2' => {'0' => ['785185.062','879301.375','829946.344'],
                             '1' => ['726011.438','810253.75','766488.719']},
                     '7' => {'0' => ['777627.75','858515.562','812372.531'],
                             '1' => ['715766.625','794474.625','750332.438']},
                     '4' => {'1' => ['732842.312','809129.812','768436.906'],
                             '0' => ['801550.312','880357.938','836349.438']},
                     '3' => {'0' => ['673020.812','778734.688','728291.469'],
                             '1' => ['632287.125','728198.562','684389.844']},
                     '6' => {'0' => ['738106.25','795061.75','760297'],
                             '1' => ['688180.562','743211.438','711789.906']},
                     '1' => {'1' => ['651105.812','732343.75','686826.906'],
                             '0' => ['691652.75','781259','727939.562']},
                     '5' => {'0' => ['716489.875','798702.75','755355.344'],
                             '1' => ['666030.812','748502.062','705948.594']},
                     '8' => {'1' => ['758469.438','828558.625','792228.938'],
                             '0' => ['838061.75','910182.25','868192.5']}}
                 };

  my $query = {id_run => [keys %{$rfolders}]};
  my $results = {};
  my $rs4runs = $rs->search($query);
  while (my $row = $rs4runs->next) {
    $results->{$row->id_run}->{$row->position}->{$row->is_pf} = [$row->min, $row->max, $row->p50];
  }

  is_deeply($results, $expected, 'data saved correctly to the database');

  $rfolders->{13169} = $rfolders->{13108};
  $expected->{13169} = $expected->{13108};
  npg_qc::illumina::loader::Cluster_Density->new(
    schema => $schema, runfolder_list_todo => $rfolders)->run_all();
  $rs4runs = $rs->search($query);
  while (my $row = $rs4runs->next) {
    $results->{$row->id_run}->{$row->position}->{$row->is_pf} = [$row->min, $row->max, $row->p50];
  }
  is_deeply($results, $expected, 'rows updated correctly');
}

1;

use strict;
use warnings;
use Test::More tests => 6;
use Test::Exception;
use Moose::Meta::Class;
use npg_testing::db;

use_ok q{npg_qc::illumina::loader::Cluster_Density};

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object()->create_test_db(q[npg_qc::Schema]);
my $schema_tracking = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object()->create_test_db(q[npg_tracking::Schema]);

{
  my $rs = $schema->resultset('ClusterDensity');
  is ($rs->search()->count(), 0, 'initially no data present');

  my $rfolders = {13108 => 't/data/nfs/sf44/ILorHSany_sf25/incoming/140601_HS2_13108_A_C37W5ACXX',
                  13169 => 't/data/nfs/sf44/ILorHSany_sf25/incoming/140605_HS36_13169_B_H9FP5ADXX'};

  my $cd = npg_qc::illumina::loader::Cluster_Density->new(
                   schema         => $schema,
                   schema_npg_tracking => $schema_tracking,
                   id_run         => 13108,
                   runfolder_path => $rfolders->{13108});
  isa_ok( $cd, q{npg_qc::illumina::loader::Cluster_Density});
  lives_ok { $cd->run() } q{saves run 13108};

  $cd = npg_qc::illumina::loader::Cluster_Density->new(
                   schema         => $schema,
                   schema_npg_tracking => $schema_tracking,
                   id_run         => 13169,
                   runfolder_path => $rfolders->{13169});
  lives_ok { $cd->run() } q{saves run 13169};

  my $expected = {
         '13169' => {'1' => {'0' => ['787647.75','1074773.75','898249.84'],
                             '1' => ['750346.88','999689.00', '845403.09']},
                     '2' => {'1' => ['751032.12','1010533.12','847345.56'],
                             '0' => ['787547.50','1091274.75','897271.03']}},
         '13108' => {'2' => {'0' => ['785185.06','879301.38','829946.34'],
                             '1' => ['726011.44','810253.75','766488.72']},
                     '7' => {'0' => ['777627.75','858515.56','812372.53'],
                             '1' => ['715766.62','794474.62','750332.44']},
                     '4' => {'1' => ['732842.31','809129.81','768436.91'],
                             '0' => ['801550.31','880357.94','836349.44']},
                     '3' => {'0' => ['673020.81','778734.69','728291.47'],
                             '1' => ['632287.12','728198.56','684389.84']},
                     '6' => {'0' => ['738106.25','795061.75','760297.00'],
                             '1' => ['688180.56','743211.44','711789.91']},
                     '1' => {'1' => ['651105.81','732343.75','686826.91'],
                             '0' => ['691652.75','781259.00','727939.56']},
                     '5' => {'0' => ['716489.88','798702.75','755355.34'],
                             '1' => ['666030.81','748502.06','705948.59']},
                     '8' => {'1' => ['758469.44','828558.62','792228.94'],
                             '0' => ['838061.75','910182.25','868192.50']}}
                 };

  my $query = {id_run => [keys %{$rfolders}]};
  my $results = {};
  my $rs4runs = $rs->search($query);
  while (my $row = $rs4runs->next) {
    $results->{$row->id_run}->{$row->position}->{$row->is_pf} = [
      sprintf("%.2f", $row->min),
      sprintf("%.2f", $row->max),
      sprintf("%.2f", $row->p50)
    ];
  }

  is_deeply($results, $expected, 'data saved correctly to the database');
}

1;

use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;
use Moose::Meta::Class;
use npg_testing::db;

use_ok(q{npg_qc::illumina::loader});

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema]);
my $schema_tracking = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_tracking::Schema]);

{
  my $loader;
  my $runfolder_path = q{t/data/nfs/sf44/ILorHSany_sf25/incoming/140601_HS2_13108_A_C37W5ACXX};
  lives_ok { $loader = npg_qc::illumina::loader->new(
    runfolder_path      => $runfolder_path,
    id_run              => 13108,
    schema              => $schema,
    schema_npg_tracking => $schema_tracking
  ) } q{loader object creation ok};
  isa_ok($loader, q{npg_qc::illumina::loader});
  lives_ok { $loader->run() } q{run 13108 loaded ok};
}

1;

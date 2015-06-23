use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;
use Moose::Meta::Class;

use npg_testing::db;

use_ok('npg_qc_viewer::Util::FileFinder');

subtest 'Basic use' => sub {
  plan tests => 2;
  my $finder;
  lives_ok { $finder = npg_qc_viewer::Util::FileFinder->new(id_run => 22, position => 1); }
    q{create npg_qc_viewer::Util::FileFinder object ok};
  isa_ok($finder, q{npg_qc_viewer::Util::FileFinder});
};

subtest 'Checking initial values after creation' => sub {
  plan tests => 3;
  
  my $finder = npg_qc_viewer::Util::FileFinder->new(id_run => 22, position => 2);
  is ($finder->file_extension, 'fastqcheck', 'default file extension');
  ok (!$finder->qc_schema, 'db schema undefined');
  is ($finder->db_lookup, 0, 'no db lookup');
};

subtest 'Attributes of the customised object' => sub {
  plan tests => 7;

  my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object()->create_test_db(q[npg_qc::Schema]);

  my $finder = npg_qc_viewer::Util::FileFinder->new(
    id_run         => 22,
    position       => 2,
    file_extension => 'bam',
    qc_schema      => $schema);
  is ($finder->file_extension, 'bam', 'custom file extension');
  is ($finder->db_lookup, 0, 'no db lookup');

  $finder = npg_qc_viewer::Util::FileFinder->new(
    id_run         => 22,
    position       => 2,
    location       => [qw/mypath yourpath/],
    qc_schema      => $schema);
  is (@{$finder->location}, 2, 'location is set');
  is ($finder->db_lookup, 0, 'no db lookup');

  $finder = npg_qc_viewer::Util::FileFinder->new(
    id_run         => 22,
    position       => 2,
    qc_schema      => $schema);
  is ($finder->db_lookup, 1, 'db lookup is true');

  $finder = npg_qc_viewer::Util::FileFinder->new(
    id_run         => 22,
    position       => 2,
    archive_path   => 't/data',
    qc_schema      => $schema);
  is ($finder->db_lookup, 1, 'db lookup is true');
  is_deeply ($finder->location, ['t/data', 't/data/lane*'], 'location derived'); 
};

1;

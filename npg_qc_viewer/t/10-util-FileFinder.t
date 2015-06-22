use strict;
use warnings;
use Test::More tests => 5;
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

subtest 'Exceptions' => sub{
  plan tests => 3;
  
  throws_ok { npg_qc_viewer::Util::FileFinder->new(position => 12, id_run => 11) } 
    qr/Validation\ failed\ for\ \'NpgTrackingLaneNumber\'/, 
    'error on passing to the constructor invalid int as a position';
  throws_ok { npg_qc_viewer::Util::FileFinder->new(position => 'dada', id_run => 11) } 
    qr/Validation\ failed\ for\ \'NpgTrackingLaneNumber\'/, 
    'error on passing to the constructor position as string';
  throws_ok { npg_qc_viewer::Util::FileFinder->new(position => 1.2, id_run => 11) } 
    qr/Validation\ failed\ for\ \'NpgTrackingLaneNumber\'/, 
    'error on passing to the constructor position as a float';
};

subtest 'Checking initial values after creation' => sub {
  plan tests => 4;
  
  my $finder = npg_qc_viewer::Util::FileFinder->new(id_run => 22, position => 2);
  is ($finder->file_extension, 'fastqcheck', 'default file extension');
  ok (!$finder->qc_schema, 'db schema undefined');
  ok (!@{$finder->location}, 'location undefined by default');
  is ($finder->db_lookup, 0, 'no db lookup');
};

subtest 'Attributes of the customised object' => sub {
  plan tests => 6;

  my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object()->create_test_db(q[npg_qc::Schema]);

  my $finder = npg_qc_viewer::Util::FileFinder->new(
    id_run         => 22,
    position       => 2,
    file_extension => 'bam',
    qc_schema      => $schema);
  is ($finder->file_extension, 'bam', 'custom file extension');
  ok (!@{$finder->location}, 'location undefined by default');
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
};

1;

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
  lives_ok { $finder = npg_qc_viewer::Util::FileFinder->new( id_run => 22 ); }
    q{create npg_qc_viewer::Util::FileFinder object ok};
  isa_ok($finder, q{npg_qc_viewer::Util::FileFinder});
};

subtest 'Checking initial values after creation' => sub {
  plan tests => 11;
  
  my $finder = npg_qc_viewer::Util::FileFinder->new(id_run    => 22, 
                                                    db_lookup => 0);
  is ($finder->file_extension, 'fastqcheck', 'default file extension');
  ok (!$finder->qc_schema, 'db schema undefined');
  
  $finder = npg_qc_viewer::Util::FileFinder->new(id_run         => 22, 
                                                 db_lookup      => 1, 
                                                 file_extension => 'other');
  is ($finder->file_extension, 'other', 'other file extension');
  ok (!$finder->qc_schema, 'db schema undefined');
  is ($finder->db_lookup, 0, 'db lookup is 0 when using other extension');

  my @locations = (q[\somelocation],);
  my $locations_ref = \@locations;

  $finder = npg_qc_viewer::Util::FileFinder->new(id_run         => 22, 
                                                 db_lookup      => 1,
                                                 location       => $locations_ref);
  is ($finder->file_extension, 'fastqcheck', 'default');
  ok (!$finder->qc_schema, 'db schema undefined');
  is ($finder->db_lookup, 0, 'db_lookup from constructor when using location');
  
  $finder = npg_qc_viewer::Util::FileFinder->new(id_run         => 22, 
                                                 db_lookup      => 1);
  is ($finder->file_extension, 'fastqcheck', 'default');
  ok (!$finder->qc_schema, 'db schema undefined');
  is ($finder->db_lookup, 1, 'db_lookup from constructor when default file extension');
 
};

subtest 'Attributes of the customised object' => sub {
  plan tests => 7;

  my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object()->create_test_db(q[npg_qc::Schema]);

  my $finder = npg_qc_viewer::Util::FileFinder->new(
    id_run         => 22,
    file_extension => 'bam',
    db_lookup      => 0,
    qc_schema      => $schema);
  is ($finder->file_extension, 'bam', 'custom file extension');
  is ($finder->db_lookup, 0, 'no db lookup');

  $finder = npg_qc_viewer::Util::FileFinder->new(
    id_run         => 22,
    location       => [qw/mypath yourpath/],
    db_lookup      => 0);
  is (@{$finder->location}, 2, 'location is set');
  is ($finder->db_lookup, 0, 'no db lookup');

  $finder = npg_qc_viewer::Util::FileFinder->new(
    id_run         => 22,
    db_lookup      => 1,
    qc_schema      => $schema);
  is ($finder->db_lookup, 1, 'db lookup is true');

  $finder = npg_qc_viewer::Util::FileFinder->new(
    id_run         => 22,
    archive_path   => 't/data',
    db_lookup      => 1,
    qc_schema      => $schema);
  is ($finder->db_lookup, 1, 'db lookup is true');
  is_deeply ($finder->location, ['t/data', 't/data/lane*'], 'location derived'); 
};

subtest 'Filename generation' => sub {
  plan tests => 7;

  my $finder = 'npg_qc_viewer::Util::FileFinder';
  is($finder->create_filename(5,1), '5_1');
  is($finder->create_filename(5,1, undef, 1), '5_1_1');
  is($finder->create_filename(5,1, undef, 't'), '5_1_t');
  is($finder->create_filename(5,1, undef, 2), '5_1_2');
  is($finder->create_filename(5,1,3), '5_1#3');
  is($finder->create_filename(5,1,3,1), '5_1_1#3');
  is($finder->create_filename(5,1,3,2), '5_1_2#3');
};

1;

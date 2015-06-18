use strict;
use warnings;
use Test::More tests => 5;
use Test::Exception;
use Test::Deep;

use_ok('npg_qc_viewer::Util::FileFinder');

subtest 'Basic use' => sub {
  plan tests => 2;
  my $finder;
  lives_ok { $finder = npg_qc_viewer::Util::FileFinder->new(id_run => 22, position => 1); }
    q{create npg_qc_viewer::Util::FileFinder object ok};
  isa_ok($finder, q{npg_qc_viewer::Util::FileFinder});
};

subtest 'Exceptions' => sub{
  plan tests => 4;
  
  throws_ok { npg_qc_viewer::Util::FileFinder->new(
    id_run => 22, position => 1, with_t_file => 1, tag_index => 22) }
    qr/tag_index and with_t_file attributes cannot be both set/, 
    'error when attempting to set both with_t_file and tag_index';
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
  plan tests => 5;
  
  my $finder = npg_qc_viewer::Util::FileFinder->new(id_run => 22, position => 2);
  is ($finder->position, 2, 'position set');
  is ($finder->file_extension, 'fastq', 'default file extension');
  is ($finder->with_t_file, 0, 'no _t file by default');
  is ($finder->tag_index, undef, 'tag_index undefined by default');
  is ($finder->tag_label, q[], 'empty string as a tag label');
};

1;

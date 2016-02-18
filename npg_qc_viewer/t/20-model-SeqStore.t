use strict;
use warnings;
use lib 't/lib';
use Test::More tests => 5;
use Test::Exception;
use Test::Deep;
use File::Temp qw/tempdir/;
use File::Path qw/make_path/;

use_ok 'npg_qc_viewer::Model::SeqStore';
isa_ok(npg_qc_viewer::Model::SeqStore->new(), 'npg_qc_viewer::Model::SeqStore');

my $base = tempdir(UNLINK => 1);
my $path = $base . q[/archive];
my $lane3 = $path . q[/lane3];
make_path $lane3;

my @files = qw/1234_1 1234_1_1 1234_1_2
                      1234_2_1 1234_2_2
                      1234_3_1
                      1234_5_1 1234_5_2 1234_5_t
               1234_6                   1234_6_t/;
foreach my $f (@files) {
  open my $fh, '>', $path.q[/].$f.q[.fastqcheck];
  close $fh;
}

subtest 'Finding files on a single path' => sub {
  plan tests => 11;

  my $ref = { position  => 1, id_run    => 1234,};
  my $f = npg_qc_viewer::Model::SeqStore->new();
  my $forward = $path . q[/1234_1.fastqcheck];
  my $expected = { 'forward' => $forward, 'db_lookup' => 0};
  cmp_deeply ($f->files($ref, 0, [$path]), $expected, 'one fastqcheck input file found');

  is (scalar keys %{$f->_file_cache->{'1234'}->{'files'}}, 11,
    'for the path all files are already cached');
  is ($f->_file_cache->{'1234'}->{'db_lookup'}, 0, 'db lookup is false');

  $ref = { position  => 2, id_run    => 1234 };
  $forward = $path . q[/1234_2_1.fastqcheck];
  my $reverse = $path . q[/1234_2_2.fastqcheck];
  $expected = { 'forward' => $forward, 'reverse' => $reverse, db_lookup => 0};
  cmp_deeply ($f->files($ref, 0, [$path]), $expected, 'two fastqcheck input files found');

  $ref = { position => 5, id_run => 1234};
  $forward = $path . q[/1234_5_1.fastqcheck];
  $reverse = $path . q[/1234_5_2.fastqcheck];
  my $t = $path . q[/1234_5_t.fastqcheck];
  $expected = { 'forward' => $forward, 'reverse' => $reverse, 'tags' => $t, 'db_lookup' => 0};
  cmp_deeply ($f->files($ref, 0, [$path]), $expected, 'three fastqcheck input files found');

  $ref = { position => 6, id_run => 1234};
  $forward = $path . q[/1234_6.fastqcheck];
  $t = $path . q[/1234_6_t.fastqcheck];
  $expected = { 'forward' => $forward, 'tags' => $t, 'db_lookup' => 0};
  cmp_deeply ($f->files($ref, 0, [$path]), $expected, 'two fastqcheck input files found');

  $ref = { position  => 3, id_run    => 1234,};
  $forward = $path . q[/1234_3_1.fastqcheck];
  $expected = { 'forward' => $forward, 'db_lookup' => 0};
  cmp_deeply ($f->files($ref, 0, [$path]), $expected,
    'single read fastqcheck input files found; with _1 to identify the end');

  $ref = { position  => 8, id_run    => 1234 };
  is (scalar (keys %{$f->files($ref, 0, [$path])}), 0, 'no input files found');

  $f = npg_qc_viewer::Model::SeqStore->new();
  $ref = { position  => 1,
           id_run    => 1234,
           tag_index => 33,};
  $forward = $lane3 . q[/1234_1_1#33.fastqcheck];
  open my $fh, '>', $forward; close $fh;
  open $fh, '>', $forward.q[.fastqcheck]; close $fh;
  open $fh, '>', $forward.q[.bam]; close $fh;
  $reverse = $lane3 . q[/1234_1_2#33.fastqcheck];
  open $fh, '>', $reverse; close $fh;
  $expected = { 'forward' => $forward, 'reverse' => $reverse, 'db_lookup' => 0, };
  cmp_deeply ($f->files($ref, 0, [$lane3]), $expected, 'two fastqcheck plex-level input files found');
  is (scalar keys %{$f->_file_cache->{'1234'}->{'files'}}, 3, 'all files are cached');
  is ($f->_file_cache->{'1234'}->{'db_lookup'}, 0, 'db lookup is false');
};

subtest 'Finding files on multiple paths' => sub {
  plan tests => 3;

  # The first path has nothing. The data is in the second path and third path.
  my $ref = { position  => 3, id_run => 1234};
  my $f = npg_qc_viewer::Model::SeqStore->new();
  my $forward = $path . q[/1234_3_1.fastqcheck];
  my $expected = { 'forward' => $forward, 'db_lookup' => 0};
  cmp_deeply ($f->files($ref, 0, [$base, $path, $lane3]), $expected,  'found data in second path.');

  ok(exists $f->_file_cache->{'1234'}->{'files'}->{'1234_1_1#33.fastqcheck'} &&
     exists $f->_file_cache->{'1234'}->{'files'}->{'1234_1_2#33.fastqcheck'},
    'files from the third path are already cached');

  $ref = { position  => 1,
           id_run    => 1234,
           tag_index => 33,};
  $forward = $lane3 . q[/1234_1_1#33.fastqcheck];
  my $reverse = $lane3 . q[/1234_1_2#33.fastqcheck];
  $expected = { 'forward' => $forward, 'reverse' => $reverse, 'db_lookup' => 0, };
  cmp_deeply ($f->files($ref, 0, [$lane3]), $expected, 'found data in third path');
};

subtest 'Finding files for two runs' => sub {
  plan tests => 3;

  my $ref = { position => 3, id_run => 1234};
  my $f = npg_qc_viewer::Model::SeqStore->new();
  my $forward = $path . q[/1234_3_1.fastqcheck];
  my $other_forward = $path . q[/1231_3_1.fastqcheck];
  open my $fh, '>', $other_forward; close $fh;
  my $expected = { 'forward' => $forward, 'db_lookup' => 0};
  cmp_deeply ($f->files($ref, 0, [$path]), $expected,  'found for one run');

  ok(exists $f->_file_cache->{'1234'}->{'files'}->{'1234_3_1.fastqcheck'} &&
     exists $f->_file_cache->{'1234'}->{'files'}->{'1231_3_1.fastqcheck'},
    'files for both runs are cached');
 
  $ref = { position => 3, id_run => 1231};
  $expected = { 'forward' => $other_forward, 'db_lookup' => 0, };
  cmp_deeply ($f->files($ref, 0, [$path]), $expected, 'found data in third path');
};

1;

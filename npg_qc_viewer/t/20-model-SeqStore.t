use strict;
use warnings;
use Test::More tests => 8;
use Test::Exception;
use Test::Deep;

{ use_ok 'npg_qc_viewer::Model::SeqStore' }

{
  isa_ok(npg_qc_viewer::Model::SeqStore->new(), 'npg_qc_viewer::Model::SeqStore');
}

# Requires these data files:
#
# npg_qc/npg_qc_viewer/t/data/nfs/sf44/IL2/analysis/123456_IL2_1234/Latest_Summary/archive/
# 1234_1_1#33.fastqcheck, 1234_1_1.fastq, 1234_1_2#33.fastqcheck, 1234_1_2.fastq, 
# 1234_1.fastqcheck, 1234_1_t.fastq, 1234_2_1.fastqcheck, 
# 1234_2_2.fastqcheck, 1234_3_1.fastqcheck, 1234_4.fastq, 1234_4.fastqcheck
#
# npg_qc/npg_qc_viewer/t/data/nfs/sf44/IL2/analysis/123456_IL2_1234/Latest_Summary/archive/lane3/
# 1234_3_1#33.fastq, 1234_3_2#33.fastq

subtest 'Testing create_filename' => sub {
  plan tests => 7;
  
  my $ref = { id_run => 1234,position => 1 };
  my $f = npg_qc_viewer::Model::SeqStore->new()->_build_file_name_helper($ref);

  is ($f->create_filename(q[fastq]), '1234_1.fastq', 'generate filename, no args');

  $ref->{ file_extension } = q[];
  $f = npg_qc_viewer::Model::SeqStore->new()->_build_file_name_helper($ref);
  is ($f->create_filename(), '1234_1', 'generate filename, no args, no ext');
 
  $ref->{ file_extension } = q[fastqcheck];
  $f = npg_qc_viewer::Model::SeqStore->new()->_build_file_name_helper($ref);
  is ($f->create_filename(q[fastqcheck], 2), '1234_1_2.fastqcheck', 'generate filename, end 2');
  is ($f->create_filename(q[fastqcheck], 1), '1234_1_1.fastqcheck', 'generate filename, end 1');
  is ($f->create_filename(q[fastqcheck], q[t]), '1234_1_t.fastqcheck', 'generate filename, end t');
  is ($f->create_filename(q[fastqcheck]), '1234_1.fastqcheck', 'generate filename, single new-style');

  throws_ok { $f->create_filename(q[fastqcheck], q[22]) } qr/Unrecognised end string 22/, 'error for an end that is not 1, 2 or t';
};

subtest 'Building actual paths' => sub {
  plan tests => 4;
  
  my $db_lookup = 0;
  my $ref = { position  => 1,
              id_run    => 2549,
              tag_index => 33,
              db_lookup => $db_lookup };
  my $f = npg_qc_viewer::Model::SeqStore->new()->_build_file_name_helper($ref, $db_lookup);
  is ($f->create_filename(q[fastq]), '2549_1#33.fastq', 'generate filename, no args, tag_index');
  is ($f->create_filename(q[fastq], 1), '2549_1_1#33.fastq', 'generate filename, end 1, tag_index');

  $ref = { position  => 1,
           id_run    => 2549,
           tag_index => 33,
           db_lookup => $db_lookup,
           file_extension => q[fastqcheck] };
  $f = npg_qc_viewer::Model::SeqStore->new()->_build_file_name_helper($ref, $db_lookup);
  
  is ($f->create_filename(q[fastqcheck], 2), '2549_1_2#33.fastqcheck', 'generate filename, end 2, tag_index');
  is ($f->create_filename(q[fastqcheck]), '2549_1#33.fastqcheck', 'generate filename, no args, tag_index'); 
};

subtest 'Finding files' => sub {
  plan tests => 3;
  my $db_lookup = 0;
  my @paths = (q[t/data/nfs/sf44/IL2/analysis/123456_IL2_1234/Latest_Summary/archive],); 
  my $ref = { position  => 1,
              id_run    => 1234,
              file_extension => q[fastqcheck],
              archive_path => q[t/data/nfs/sf44/IL2/analysis/123456_IL2_1234/Latest_Summary/archive],
              db_lookup    => $db_lookup, };
  my $f = npg_qc_viewer::Model::SeqStore->new();
  my $forward = q[t/data/nfs/sf44/IL2/analysis/123456_IL2_1234/Latest_Summary/archive/1234_1.fastqcheck];
  my $expected = { forward => $forward, db_lookup => $db_lookup};
  cmp_deeply ($f->files($ref, $db_lookup, \@paths), $expected, 'one fastqcheck input file found');

  $ref = { position  => 2,
           id_run    => 1234,
           file_extension => q[fastqcheck],
           archive_path => q[t/data/nfs/sf44/IL2/analysis/123456_IL2_1234/Latest_Summary/archive],
           db_lookup    => 0, };
  $f = npg_qc_viewer::Model::SeqStore->new();
  $forward = q[t/data/nfs/sf44/IL2/analysis/123456_IL2_1234/Latest_Summary/archive/1234_2_1.fastqcheck];
  my $reverse = q[t/data/nfs/sf44/IL2/analysis/123456_IL2_1234/Latest_Summary/archive/1234_2_2.fastqcheck];
  $expected = { forward => $forward, reverse => $reverse, db_lookup => $db_lookup};
  cmp_deeply ($f->files($ref, $db_lookup, \@paths), $expected, 'two fastqcheck input files found');

  $ref = { position  => 1,
           id_run    => 1234,
           archive_path => q[t/data/nfs/sf44/IL2/analysis/123456_IL2_1234/Latest_Summary/archive],
           file_extension => q[fastq],
           db_lookup    => 0,
           with_t_file => 1, };
  $f = npg_qc_viewer::Model::SeqStore->new();
  $forward = q[t/data/nfs/sf44/IL2/analysis/123456_IL2_1234/Latest_Summary/archive/1234_1_1.fastq];
  $reverse = q[t/data/nfs/sf44/IL2/analysis/123456_IL2_1234/Latest_Summary/archive/1234_1_2.fastq];
  my $t = q[t/data/nfs/sf44/IL2/analysis/123456_IL2_1234/Latest_Summary/archive/1234_1_t.fastq];
  $expected = { forward => $forward, reverse => $reverse, tags => $t, db_lookup => $db_lookup};
  cmp_deeply ($f->files($ref, $db_lookup, \@paths), $expected, 'three fastq input files found');
};

subtest 'Finding files with tax index' => sub {
  plan tests => 1;
  my $db_lookup = 0;
  my @paths = (q[t/data/nfs/sf44/IL2/analysis/123456_IL2_1234/Latest_Summary/archive],); 
  my $ref = { position  => 1,
              id_run    => 1234,
              tag_index => 33,
              file_extension => q[fastqcheck],
              lane_archive_lookup => 0,
              db_lookup => $db_lookup };
  my $f = npg_qc_viewer::Model::SeqStore->new();
  my $forward = q[t/data/nfs/sf44/IL2/analysis/123456_IL2_1234/Latest_Summary/archive/1234_1_1#33.fastqcheck];
  my $reverse = q[t/data/nfs/sf44/IL2/analysis/123456_IL2_1234/Latest_Summary/archive/1234_1_2#33.fastqcheck];
  my $expected = { forward => $forward, reverse => $reverse, db_lookup => $db_lookup, };
  cmp_deeply ($f->files($ref, $db_lookup, \@paths), $expected, 'two fastqcheck input files found, tag_index');
};

subtest 'Finding files for lane archive' => sub {
  plan tests => 2;
  my $db_lookup = 0;
  my $ref = { position  => 1,
              id_run    => 1234,
              tag_index => 33,
              lane_archive_lookup => 1,
              file_extension => q[fastq],
              archive_path => q[t/data/nfs/sf44/IL2/analysis/123456_IL2_1234/Latest_Summary/archive],
              db_lookup => $db_lookup };
  my $f = npg_qc_viewer::Model::SeqStore->new();
  is(scalar keys %{$f->files($ref, $db_lookup)}, 0, 'no files if they are not in the lane archive');
  
  $ref = { position  => 3,
           id_run    => 1234,
           tag_index => 33,
           lane_archive_lookup => 1,
           file_extension => q[fastq],
           archive_path => q[t/data/nfs/sf44/IL2/analysis/123456_IL2_1234/Latest_Summary/archive],
           db_lookup => $db_lookup };
  $f = npg_qc_viewer::Model::SeqStore->new();
  my $forward = q[t/data/nfs/sf44/IL2/analysis/123456_IL2_1234/Latest_Summary/archive/lane3/1234_3_1#33.fastq];
  my $reverse = q[t/data/nfs/sf44/IL2/analysis/123456_IL2_1234/Latest_Summary/archive/lane3/1234_3_2#33.fastq];
  my $expected = { forward => $forward, reverse => $reverse, db_lookup => $db_lookup };
  cmp_deeply ($f->files($ref, $db_lookup), $expected, 'two fastqcheck input files found, tag_index, lane archive');
};

subtest 'Single files with _1' => sub {
  plan tests => 3;
  my $db_lookup = 0;
  my @paths = (q[t/data/nfs/sf44/IL2/analysis/123456_IL2_1234/Latest_Summary/archive],); 
  my $ref = { position  => 3,
              id_run    => 1234,
              file_extension => q[fastqcheck],
              db_lookup => $db_lookup };
  my $f = npg_qc_viewer::Model::SeqStore->new();
  my $forward = q[t/data/nfs/sf44/IL2/analysis/123456_IL2_1234/Latest_Summary/archive/1234_3_1.fastqcheck];
  my $expected = { forward => $forward, db_lookup => $db_lookup};
  
  cmp_deeply ($f->files($ref, $db_lookup, \@paths), $expected,  'one fastqcheck input files found; with _1 to identify the end');
   
  $ref = { position  => 4,
           id_run    => 1234,
           file_extension => q[fastq],
           archive_path => q[t/data/nfs/sf44/IL2/analysis/123456_IL2_1234/Latest_Summary/archive],
           db_lookup => 0 };
  $f = npg_qc_viewer::Model::SeqStore->new();

  $forward = q[t/data/nfs/sf44/IL2/analysis/123456_IL2_1234/Latest_Summary/archive/1234_4.fastq];
  $expected = { forward => $forward, db_lookup => $db_lookup };
  cmp_deeply ($f->files($ref, $db_lookup, \@paths), $expected,  'one fastqcheck input files found; no _1 to identify the end');   

  $ref = { position  => 8,
           id_run    => 1234,
           archive_path => q[t/data/nfs/sf44/IL2/analysis/123456_IL2_1234/Latest_Summary/archive],
           db_lookup => 0 };
  $f = npg_qc_viewer::Model::SeqStore->new();
  is (scalar (keys %{$f->files($ref, $db_lookup)}), 0, 'no input files found');
};

1;

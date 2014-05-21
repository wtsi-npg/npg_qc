#########
# Author:        jo3
# Maintainer:    $Author$
# Created:       30 July 2009
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

use strict;
use warnings;
use Test::More tests => 20;
use Test::Exception;
use Cwd qw/getcwd/;
use File::Temp qw/tempdir/;

use t::autoqc_util qw/write_samtools_script/;

my $repos = getcwd . '/t/data/autoqc';

use_ok('npg_qc::autoqc::checks::gc_bias');

my $dir = tempdir(UNLINK => 1);
foreach my $e (qw/R window_depth/) {
  my $p = join q[/], $dir, $e;
  `touch $p`;
  `chmod +x $p`;
}

local $ENV{PATH} = join q[:], $dir, $ENV{PATH};

{
   my $check = npg_qc::autoqc::checks::gc_bias->new(
                                                      path      => 't/data/autoqc/090721_IL29_2549/data',
                                                      position  => 2,
                                                      id_run => 2549,
                                                      repository => $repos,
                                                      read_length => undef,
                                                    );
   is ($check->bam_file, 't/data/autoqc/090721_IL29_2549/data/2549_2.bam', 'bam file path for lane 2');
   lives_ok { $check->execute } 'execution ok';
   like ($check->result->comments, qr/Bam file has no reads/, 'comment when bam file is empty');

   $check = npg_qc::autoqc::checks::gc_bias->new(
                                                      path      => 't/data/autoqc/090721_IL29_2549/data',
                                                      position  => 6,
                                                      id_run    => 2549,
                                                      tag_index => 1,
                                                      repository => $repos,
                                                      read_length => 3,
                                                      _bam_is_aligned => 0,
                                                );
   is($check->bam_file, 't/data/autoqc/090721_IL29_2549/data/2549_6#1.bam', 'bam file path for lane 6 tag 1');
   lives_ok { $check->execute } 'execution ok';
   like ($check->result->comments, qr/Bam file is not aligned/, 'comment bam file is not aligned');

   $check = npg_qc::autoqc::checks::gc_bias->new(
                                                      path      => 't/data/autoqc/090721_IL29_2549/data',
                                                      position  => 6,
                                                      id_run    => 2549,
                                                      tag_index => 1,
                                                      repository => $repos,
                                                      read_length => 3,
                                                      _bam_is_aligned => 1,
                                                      gcn_file        => 'non-existing',
                                                );
   lives_ok { $check->execute } 'execution ok';
   like ($check->result->comments, qr/No gcn file non-existing/, 'comment when gcn file does not exist');
   like (npg_qc::autoqc::checks::gc_bias->find_R_library,  qr/lib\/R\/gc_bias_data\.R$/, 'R gc bias lib location');
}


{
   my $st = join q[/], $dir, q[samtools];
   write_samtools_script(join(q[/], $dir, q[samtools]), q[dodo]);

   my $check = npg_qc::autoqc::checks::gc_bias->new(
                                                      path      => 't/data/autoqc/090721_IL29_2549/data',
                                                      position  => 6,
                                                      id_run    => 2549,
                                                      tag_index => 1,
                                                      repository => $repos,
                                                   );
   throws_ok {$check->_bam_is_aligned} qr/Error in pipe/, 'error in test samtools script when reading bam header';
   throws_ok {$check->read_length} qr/Error in pipe/, 'error in test samtools script when reading bam file';

   my $empty = join q[/], $dir, q[empty];
   `touch $empty`;
   write_samtools_script($st, $empty);
   $check = npg_qc::autoqc::checks::gc_bias->new(
                                                      path      => 't/data/autoqc/090721_IL29_2549/data',
                                                      position  => 6,
                                                      id_run    => 2549,
                                                      tag_index => 1,
                                                      repository => $repos,
                                                   );
   lives_ok {$check->read_length} 'read length for an empty file lives';
   is($check->read_length, undef, 'read length is undefined for an empty file');

   write_samtools_script($st, q[t/data/autoqc/gc_bias/sam_unaligned_header]);
   lives_ok {$check->_bam_is_aligned} 'bam alignment from header lives';
   is($check->_bam_is_aligned, 0, 'bam is not aligned');


   $check = npg_qc::autoqc::checks::gc_bias->new(
                                                   path      => 't/data/autoqc/090721_IL29_2549/data',
                                                   position  => 6,
                                                   id_run    => 2549,
                                                   tag_index => 1,
                                                   repository => $repos,
                                                );

   write_samtools_script($st, q[t/data/autoqc/gc_bias/sam-3lines]);
   lives_ok {$check->read_length} 'read length for a non-empty file lives';
   is($check->read_length, 76, 'read length is 76');

   write_samtools_script($st, q[t/data/autoqc/gc_bias/sam_aligned_header]);
   lives_ok {$check->_bam_is_aligned} 'bam alignment from header lives';
   is($check->_bam_is_aligned, 1, 'bam is aligned');
}

1;

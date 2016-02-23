use strict;
use warnings;
use Cwd qw/getcwd/;
use Test::More tests => 16;
use Test::Exception;
use File::Temp qw/ tempdir /;

use_ok ('npg_qc::autoqc::checks::rna_seqc');

my $dir = tempdir( CLEANUP => 1 );
`touch $dir/RNA-SeQC.jar`;


my $repos = getcwd . '/t/data/autoqc';

{
  local $ENV{CLASSPATH} = $dir;

  my $rnaseqc = npg_qc::autoqc::checks::rna_seqc->new(
    id_run => 2,
    path => q[mypath],
    position => 1,
    repository => $repos,
    qc_out => q[t/data]);

  isa_ok ($rnaseqc, 'npg_qc::autoqc::checks::rna_seqc');
  lives_ok { $rnaseqc->result; } 'result object created';

  local $ENV{CLASSPATH} = q[];

  throws_ok {npg_qc::autoqc::checks::rna_seqc->new(id_run => 2, path => q[mypath], position => 1, qc_out => q[t/data])}
         qr/Can\'t find \'RNA-SeQC\.jar\' because CLASSPATH is not set/,
         q[Fails to create object when RNA-SeQC.jar not found];
}

{
  my $qc = npg_qc::autoqc::checks::rna_seqc->new(
    position => 2,
    path => 'nonexisting',
    id_run => 2549,
    repository => $repos,
    qc_out => q[t/data],);
  throws_ok {$qc->execute()} qr/directory nonexisting does not exist/, 'execute: error on nonexisting path';
}

{
  my $check = npg_qc::autoqc::checks::rna_seqc->new(
    path => 't/data/autoqc/rna_seqc/data',
    position => 4,
    id_run => 17550,
    tag_index => 13,
    qc_out => q[t/data],
    _reference_fasta => q[]);
  lives_ok { $check->execute } 'no error when input not found';
}

{
  my $check = npg_qc::autoqc::checks::rna_seqc->new(
    id_run => 2,
    path => 't/data/autoqc/090721_IL29_2549/data',
    position => 2,
    id_run => 2549,
    qc_out => q[t/data],
    _alignments_in_bam => 0);
  is($check->_bam_file, 't/data/autoqc/090721_IL29_2549/data/2549_2.bam', 'bam file path for id run 2549 lane 2');
  lives_ok { $check->execute } 'execution ok';
  like ($check->result->comments, qr/BAM file is not aligned/, 'comment when bam file is not aligned');

  $check = npg_qc::autoqc::checks::rna_seqc->new(
    path => 't/data/autoqc/090721_IL29_2549/data',
    position => 2,
    id_run => 2549,
    qc_out => q[t/data],);
  lives_ok { $check->execute } 'execution ok';
  like ($check->result->comments, qr/Library type is not RNA.*/, 'comment when library type is not RNA');

  $check = npg_qc::autoqc::checks::rna_seqc->new(
    path => 't/data/autoqc/rna_seqc/data',
    position => 3,
    id_run => 17550,
    tag_index => 8,
    qc_out => q[t/data],
    _reference_fasta => q[]);
  is($check->_bam_file, 't/data/autoqc/rna_seqc/data/17550_3#8.bam', 'bam file path for id run 17550 lane 3 tag 8');
  lives_ok { $check->execute } 'execution ok';
  like ($check->result->comments, qr/No reference genome available/, 'comment when reference genome does not exist');

  $check = npg_qc::autoqc::checks::rna_seqc->new(
    path => 't/data/autoqc/rna_seqc/data',
    position => 3,
    id_run => 17550,
    tag_index => 8,
    qc_out => q[t/data],
    _annotation_gtf => q[]);
  lives_ok { $check->execute } 'execution ok';
  like ($check->result->comments, qr/No GTF annotation available/, 'comment when annotation file does not exist');
}

1;

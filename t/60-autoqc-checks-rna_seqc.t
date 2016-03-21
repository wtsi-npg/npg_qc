use strict;
use warnings;
use Cwd qw/getcwd abs_path/;
use Test::More tests => 17;
use Test::Exception;
use File::Temp qw/ tempdir /;

use_ok ('npg_qc::autoqc::checks::rna_seqc');

my $dir = tempdir( CLEANUP => 1 );

local $ENV{'NPG_WEBSERVICE_CACHE_DIR'} = q[t/data/autoqc/rna_seqc];
local $ENV{CLASSPATH} = $dir;
local $ENV{PATH} = join q[:], $dir, $ENV{PATH};

my $repos = getcwd . '/t/data/autoqc/rna_seqc';

`touch $dir/RNA-SeQC.jar`;
`touch $dir/samtools`;
`touch $dir/samtools1`;


{
    my $rnaseqc = npg_qc::autoqc::checks::rna_seqc->new(
        id_run => 17550,
        position => 3,
        tag_index => 8,
        path => q[mypath],
        repository => $repos,
        qc_out => q[t/data],);
    isa_ok ($rnaseqc, 'npg_qc::autoqc::checks::rna_seqc');
    lives_ok { $rnaseqc->result; } 'result object created';
    local $ENV{CLASSPATH} = q[];
    throws_ok {npg_qc::autoqc::checks::rna_seqc->new(id_run => 2, path => q[mypath], position => 1, qc_out => q[t/data])}
        qr/Can\'t find \'RNA-SeQC\.jar\' because CLASSPATH is not set/,
        q[Fails to create object when RNA-SeQC.jar not found];
}

{
    my $qc = npg_qc::autoqc::checks::rna_seqc->new(
        id_run => 17550,
        position => 3,
        tag_index => 8,
        path => q[nonexisting],
        repository => $repos,
        qc_out => q[t/data],);
    throws_ok {$qc->execute()} qr/directory nonexisting does not exist/, 'execute: error on nonexisting path';
}

{
    my $check = npg_qc::autoqc::checks::rna_seqc->new(
        id_run => 17550,
        position => 3,
        tag_index => 13,
        path => 't/data/autoqc/rna_seqc/data',
        repository => $repos,
        qc_out => q[t/data],);
    lives_ok { $check->execute } 'no error when input not found';
}

{
    my $ref_repos_dir = join q[/],$dir,'references';
    my $ref_dir = join q[/], $ref_repos_dir,'Mus_musculus','GRCm38','all';
    `mkdir -p $ref_dir/fasta`;
    `touch $ref_dir/fasta/Mus_musculus.GRCm38.68.dna.toplevel.fa`;
    my $trans_repos_dir = join q[/],$dir,'transcriptomes';
    my $trans_dir = join q[/], $trans_repos_dir,'Mus_musculus','ensembl_75_transcriptome','GRCm38';
    `mkdir -p $trans_dir/gtf`;
    `touch $trans_dir/gtf/ensembl_75_transcriptome-GRCm38.gtf`;
    `mkdir -p $trans_dir/RNA-SeQC`;
    `touch $trans_dir/RNA-SeQC/ensembl_75_transcriptome-GRCm38.gtf`;    

    my $check = npg_qc::autoqc::checks::rna_seqc->new(
        id_run => 17550,
        position => 3,
        tag_index => 8,
        path => 't/data/autoqc/rna_seqc/data',
        repository => $repos,
        ref_repository => $ref_repos_dir,
        transcriptome_repository => $trans_repos_dir,
        _alignments_in_bam => 0,
        qc_out => q[t/data],);
    is($check->_bam_file, 't/data/autoqc/rna_seqc/data/17550_3#8.bam', 'bam file path for id run 17550 lane 3 tag 8');
    lives_ok { $check->execute } 'execution ok for no alignments in BAM';
    like ($check->result->comments, qr/BAM file is not aligned/, 'comment when bam file is not aligned');

    $check = npg_qc::autoqc::checks::rna_seqc->new(
        id_run => 17550,
        position => 3,
        tag_index => 0,
        path => 't/data/autoqc/rna_seqc/data',
        repository => $repos,
        ref_repository => $ref_repos_dir,
        transcriptome_repository => $trans_repos_dir,
        qc_out => q[t/data],);
    is($check->_bam_file, 't/data/autoqc/rna_seqc/data/17550_3#0.bam', 'bam file path for id run 17550 lane 3 tag 0');
    lives_ok { $check->execute } 'execution ok for no RNA alignment';
    like ($check->result->comments, qr/BAM file is not RNA alignment/, 'comment when bam file is not RNA alignment');

    $check = npg_qc::autoqc::checks::rna_seqc->new(
        id_run => 17550,
        position => 1,
        tag_index => 1,
        path => 't/data/autoqc/rna_seqc/data',
        repository => $repos,
        qc_out => q[t/data],
        ref_repository => $ref_repos_dir,
        transcriptome_repository => $trans_repos_dir,);
    throws_ok { $check->execute } qr/Binary fasta reference for Danio_rerio, zv9, all does not exist/,
        'error message when reference genome does not exist';

    $check = npg_qc::autoqc::checks::rna_seqc->new(
        id_run => 17550,
        position => 3,
        tag_index => 8,
        path => 't/data/autoqc/rna_seqc/data',
        repository => $repos,
        qc_out => q[t/data],
        _reference_fasta => q[],
        transcriptome_repository => $trans_repos_dir,);
    lives_ok { $check->execute } 'execution ok for no reference genomefile';
    like ($check->result->comments, qr/No reference genome available/, 'comment when reference genome file is not available');

    $check = npg_qc::autoqc::checks::rna_seqc->new(
        id_run => 17550,
        position => 3,
        tag_index => 8,
        path => 't/data/autoqc/rna_seqc/data',
        repository => $repos,
        qc_out => q[t/data],
        _annotation_gtf => q[],
        ref_repository => $ref_repos_dir,);
    lives_ok { $check->execute } 'execution ok for no annotation file';
    like ($check->result->comments, qr/No GTF annotation available/, 'comment when annotation file is not available');
}

1;

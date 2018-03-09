use strict;
use warnings;
use Cwd qw/getcwd abs_path/;
use Test::More tests => 6;
use Test::Exception;
use Test::Warn;
use File::Temp qw/ tempdir /;

use_ok ('npg_qc::autoqc::checks::rna_seqc');
$ENV{no_proxy} = '';
$ENV{http_proxy} = 'http://wibble.do';

my $dir = tempdir( CLEANUP => 1 );

local $ENV{'NPG_CACHED_SAMPLESHEET_FILE'} = q[t/data/autoqc/rna_seqc/samplesheet_17550.csv];
local $ENV{CLASSPATH} = $dir;
local $ENV{PATH} = join q[:], $dir, $ENV{PATH};

my $repos = getcwd . '/t/data/autoqc/rna_seqc';

`touch $dir/RNA-SeQC.jar`;

my $si = join q[/], $dir, q[samtools];
`touch $si`;
`chmod +x $si`;

subtest 'Find CLASSPATH' => sub {
    plan tests => 3;
    my $rnaseqc = npg_qc::autoqc::checks::rna_seqc->new(
        id_run => 17550,
        position => 3,
        tag_index => 8,
        path => 't/data/autoqc/rna_seqc/data',
        repository => $repos,);
    isa_ok ($rnaseqc, 'npg_qc::autoqc::checks::rna_seqc');
    lives_ok { $rnaseqc->result; } 'result object created';
    local $ENV{CLASSPATH} = q[];
    throws_ok {npg_qc::autoqc::checks::rna_seqc->new(id_run => 2, path => q[mypath], position => 1,)}
        qr/Can\'t find \'RNA-SeQC\.jar\' because CLASSPATH is not set/,
        q[Fails to create object when RNA-SeQC.jar not found];
};

subtest 'Input and output paths' => sub {
    plan tests => 3;
    throws_ok {
      my $qc = npg_qc::autoqc::checks::rna_seqc->new(
        id_run => 17550,
        position => 3,
        tag_index => 8,
        path => q[nonexisting],
        repository => $repos,);
      $qc->execute()
    } qr/directory nonexisting does not exist/, 'execute: error on nonexisting path';
    my $run = 17550;
    my $pos = 3;
    my $tag = 13;
    my $check = npg_qc::autoqc::checks::rna_seqc->new(
        id_run => $run,
        position => $pos,
        tag_index => $tag,
        path => 't/data/autoqc/rna_seqc/data',
        repository => $repos);
    lives_ok { $check->execute } 'no error when input not found';
    my $filename_root = $check->result->filename_root;
    my $output_dir_shouldbe = join q[/], $check->path, $filename_root.q[_rna_seqc];
    is($check->output_dir, $output_dir_shouldbe, q[output directory is formed correctly]);
};

subtest 'Parse metrics' => sub {
    plan tests => 4;
    my $rnaseqc = npg_qc::autoqc::checks::rna_seqc->new(
        id_run => 17550,
        position => 3,
        tag_index => 8,
        path => 't/data/autoqc/rna_seqc/data',
        repository => $repos,);
    my $metrics_hash;
    my $results_hash;
    throws_ok {$rnaseqc->_parse_metrics()} qr/No\ such\ file\ t\/data\/autoqc\/rna_seqc\/data\/17550\_3\#8\_rna\_seqc\/metrics\.tsv\:\ cannot\ parse\ RNA-SeQC\ metrics/,
      'error if metrics file is not found where expected';
    $rnaseqc = npg_qc::autoqc::checks::rna_seqc->new(
        id_run => 18407,
        position => 1,
        tag_index => 7,
        path => 't/data/autoqc/rna_seqc/data',
        repository => $repos,);
    lives_ok {$metrics_hash = $rnaseqc->_parse_metrics()} q[parsing RNA-SeQC metrics.tsv ok];
    warning_like {$results_hash = $rnaseqc->_save_results($metrics_hash)} {carped => qr/Value of .* is 'NaN'/}, q[saving results ok - a NaN carp was caught];
    is ($results_hash->{'end_3_norm'}, undef, q[fields with value NaN are skipped]);
};

subtest 'Argument input files' => sub {
    plan tests => 14;
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

    open my $fh,  q[>], $si;
    print $fh qq[cat $repos/data/17550_3#8.bam\n];
    close $fh;

    my $check = npg_qc::autoqc::checks::rna_seqc->new(
        id_run => 17550,
        position => 3,
        tag_index => 8,
        path => 't/data/autoqc/rna_seqc/data',
        repository => $repos,
        ref_repository => $ref_repos_dir,
        transcriptome_repository => $trans_repos_dir,
        _alignments_in_bam => 0);
    is($check->_bam_file, 't/data/autoqc/rna_seqc/data/17550_3#8.bam', 'bam file path for id run 17550 lane 3 tag 8');
    lives_ok { $check->execute } 'execution ok for no alignments in BAM';
    like ($check->result->comments, qr/BAM file is not aligned/, 'comment when bam file is not aligned');

    $check = npg_qc::autoqc::checks::rna_seqc->new(
        id_run => 17550,
        position => 3,
        tag_index => 8,
        path => 't/data/autoqc/rna_seqc/data',
        repository => $repos,
        _ref_genome => q[],
        transcriptome_repository => $trans_repos_dir,);
    lives_ok { $check->execute } 'execution ok for no reference genome file';
    like ($check->result->comments, qr/No reference genome available/, 'comment when reference genome file is not available');

    $check = npg_qc::autoqc::checks::rna_seqc->new(
        id_run => 17550,
        position => 3,
        tag_index => 8,
        path => 't/data/autoqc/rna_seqc/data',
        repository => $repos,
        _annotation_gtf => q[],
        ref_repository => $ref_repos_dir,);
    lives_ok { $check->execute } 'execution ok for no annotation file';
    like ($check->result->comments, qr/No GTF annotation available/, 'comment when annotation file is not available');

    open $fh,  q[>], $si;
    print $fh qq[cat $repos/data/17550_1#1.bam\n];
    close $fh;

    $check = npg_qc::autoqc::checks::rna_seqc->new(
        id_run => 17550,
        position => 1,
        tag_index => 1,
        path => 't/data/autoqc/rna_seqc/data',
        repository => $repos,
        ref_repository => $ref_repos_dir,
        transcriptome_repository => $trans_repos_dir,);
    throws_ok { $check->execute } qr/Binary fasta reference for Danio_rerio, zv9(, all)? does not exist/,
        'error message when reference genome does not exist';

    $ref_dir = join q[/], $ref_repos_dir,'Danio_rerio','zv9','all';
    `mkdir -p $ref_dir/fasta`;
    `touch $ref_dir/fasta/zv9_toplevel.fa`;

    $check = npg_qc::autoqc::checks::rna_seqc->new(
        id_run => 17550,
        position => 1,
        tag_index => 1,
        path => 't/data/autoqc/rna_seqc/data',
        repository => $repos,
        ref_repository => $ref_repos_dir,
        transcriptome_repository => $trans_repos_dir,);
    is($check->_bam_file, 't/data/autoqc/rna_seqc/data/17550_1#1.bam', 'bam file path for id run 17550 lane 1 tag 1');
    is($check->_is_rna_alignment, 0, 'bam for id run 17550 lane 1 tag 1 from bwa aligner is not RNA alignment');
    lives_ok { $check->execute } 'execution ok for no RNA alignment';
    like ($check->result->comments, qr/BAM file is not RNA alignment/, 'comment when bam file is not RNA alignment');

    open $fh,  q[>], $si;
    print $fh qq[cat $repos/data/17550_3#8.bam\n];
    close $fh;

    $check = npg_qc::autoqc::checks::rna_seqc->new(
        id_run => 17550,
        position => 3,
        tag_index => 8,
        path => 't/data/autoqc/rna_seqc/data',
        repository => $repos,);
    is($check->_is_rna_alignment, 1, 'bam for id run 17550 lane 3 tag 8 from TopHat aligner is RNA alignment');

    open $fh,  q[>], $si;
    print $fh qq[cat $repos/data/6_6#6.bam\n];
    close $fh;

    $check = npg_qc::autoqc::checks::rna_seqc->new(
        id_run => 6,
        position => 6,
        tag_index => 6,
        path => 't/data/autoqc/rna_seqc/data',
        repository => $repos,);
    is($check->_is_rna_alignment, 1, 'bam for id run 6 lane 6 tag 6 from STAR aligner is RNA alignment');

};

subtest 'Role methods' => sub {
    plan tests => 6;
    my ($r, $om_value);
    use_ok('npg_qc::autoqc::role::rna_seqc');
    use_ok ('npg_qc::autoqc::results::rna_seqc');
    lives_ok {$r = npg_qc::autoqc::results::rna_seqc->load('t/data/autoqc/rna_seqc/data/18407_1#7.rna_seqc.json');} 'load serialised valid result';
    lives_ok {$om_value = $r->other_metrics();} 'extract other metrics';
    is_deeply($r->transcripts_detected(), $om_value->{'Transcripts Detected'}, 'value extracted using role method');
    is_deeply($r->intronic_rate(), $om_value->{'Intronic Rate'}, 'value extracted using role method');
};


1;

use strict;
use warnings;
use Cwd qw/getcwd abs_path/;
use Test::More tests => 5;
use Test::Exception;
use Test::Warn;
use Test::Deep;
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
open my $fh,  q[>], $si;
print $fh q{#!/bin/bash}.qq{\n};
print $fh q{rpt_regex='([[:digit:]]+)_([[:digit:]]+)(_([[:alpha:]]+))?(#([[:digit:]]+))?(_([[:alpha:]]+))?'}.qq{\n};
print $fh q{while (( "$#" )); do if [[ "$1" =~ $rpt_regex ]]; then bam=$1; break; fi; shift; done}.qq{\n};
print $fh q{if [ -e $bam ]; then cat $bam; else exit 1; fi;}.qq{\n};
print $fh q{exit 0};
close $fh;

my %results_hash = ('3\' Norm' => '0.71482545','5\' Norm' => '0.33503783','Alternative Aligments' => '586116',
'Base Mismatch Rate' => '0.0025221831','Chimeric Pairs' => '52379','Cumul. Gap Length' => '429908',
'Duplication Rate of Mapped' => '0.06441298','End 1 % Sense' => '2.5279112','End 1 Antisense' => '912869',
'End 1 Mapping Rate' => '0.9488925','End 1 Mismatch Rate' => '0.0029979434','End 1 Sense' => '23675',
'End 2 % Sense' => '97.53547','End 2 Antisense' => '22910','End 2 Mapping Rate' => '0.93876535',
'End 2 Mismatch Rate' => '0.0020412907','End 2 Sense' => '906678','Estimated Library Size' => '9104256',
'Exonic Rate' => '0.8224496','Expression Profiling Efficiency' => '0.77625173','Failed Vendor QC Check' => '0',
'Fragment Length Mean' => '136','Fragment Length StdDev' => '195','Gap %' => '0.2832022',
'Genes Detected' => '13330','Globin % TPM' => '2.71','Intergenic Rate' => '0.034667507',
'Intragenic Rate' => '0.96514183','Intronic Rate' => '0.14269224','Mapped Pairs' => '1077116',
'Mapped Unique Rate of Total' => '0.8830341','Mapped Unique' => '2065996','Mapped' => '2208235',
'Mapping Rate' => '0.94382894','Mean CV' => '0.92831475','Mean Per Base Cov.' => '1.9502662',
'No. Covered 5\'' => '439','Note' => '3521885','Num. Gaps' => '5079',
'Read Length' => '75','rRNA rate' => '0.042643875','rRNA' => '99772',
'Sample' => '20970008','Split Reads' => '445235','Total Purity Filtered Reads Sequenced' => '2339656',
'Transcripts Detected' => '75803','Unique Rate of Mapped' => '0.935587','Unpaired Reads' => '0',);


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

subtest 'Parse metrics' => sub {
    plan tests => 7;
    my $rnaseqc = npg_qc::autoqc::checks::rna_seqc->new(
        id_run => 17550,
        position => 3,
        tag_index => 8,
        path => 't/data/autoqc/rna_seqc/data',
        repository => $repos,);
    throws_ok {$rnaseqc->_parse_rna_seqc_metrics()} qr[No such file.*], q[error if metrics file is not found where expected];

    $rnaseqc = npg_qc::autoqc::checks::rna_seqc->new(
        id_run => 18407,
        position => 1,
        tag_index => 7,
        path => 't/data/autoqc/rna_seqc/data',
        repository => $repos,);
    lives_ok {$rnaseqc->_parse_rna_seqc_metrics()} q[parsing RNA-SeQC metrics.tsv ok];
    warning_like {$rnaseqc->_save_results()} {carped => qr/Value of .* is 'NaN'/}, q[saving results ok - a NaN carp was caught];
    is ($rnaseqc->_get_result('3\' Norm'), undef, q[fields with value NaN are skipped]);

    $rnaseqc = npg_qc::autoqc::checks::rna_seqc->new(
        id_run => 6,
        position => 6,
        tag_index => 6,
        path => 't/data/autoqc/rna_seqc/data',
        globin_genes_csv => 't/data/autoqc/rna_seqc/data/globin_genes.csv',
        repository => $repos,);
    lives_ok {$rnaseqc->_parse_rna_seqc_metrics()} q[parsing RNA-SeQC metrics.tsv ok];
    lives_ok {$rnaseqc->_parse_quant_file()} q[parsing quant.genes.sf ok];
    cmp_deeply ($rnaseqc->_results, \%results_hash, q[compare results hash]);
};

subtest 'Argument input files' => sub {
    plan tests => 16;
    my $ref_repos_dir = join q[/],$dir,'references';
    my $ref_dir = join q[/], $ref_repos_dir,'Mus_musculus','GRCm38','all';
    `mkdir -p $ref_dir/fasta`;
    `touch $ref_dir/fasta/Mus_musculus.GRCm38.68.dna.toplevel.fa`;
    my $rrna_dir = join q[/], $ref_repos_dir,'Mus_musculus','default_rRNA','all';
    `mkdir -p $rrna_dir/bwa`;
    `touch $rrna_dir/bwa/GRCm38.rRNA.fa`;
    my $trans_repos_dir = join q[/],$dir,'transcriptomes';
    my $trans_dir = join q[/], $trans_repos_dir,'Mus_musculus','ensembl_75_transcriptome','GRCm38';
    `mkdir -p $trans_dir/gtf`;
    `touch $trans_dir/gtf/ensembl_75_transcriptome-GRCm38.gtf`;
    `mkdir -p $trans_dir/RNA-SeQC`;
    `touch $trans_dir/RNA-SeQC/ensembl_75_transcriptome-GRCm38.gtf`;

    my $check = npg_qc::autoqc::checks::rna_seqc->new(
        id_run => 17550,
        position => 3,
        tag_index => 1,
        path => 't/data/autoqc/rna_seqc/data',
        repository => $repos,
        ref_repository => $ref_repos_dir,
        transcriptome_repository => $trans_repos_dir,);
    is($check->_bam_file, 't/data/autoqc/rna_seqc/data/17550_3#1.bam', 'bam file path for id run 17550 lane 3 tag 1');
    lives_ok { $check->execute } 'execution ok for no alignments in BAM';
    like ($check->result->comments, qr/BAM file is not aligned/, 'comment when bam file is not aligned');

    $check = npg_qc::autoqc::checks::rna_seqc->new(
        id_run => 17550,
        position => 3,
        tag_index => 8,
        path => 't/data/autoqc/rna_seqc/data',
        repository => $repos,
        ref_genome => q[],
        transcriptome_repository => $trans_repos_dir,);
    lives_ok { $check->execute } 'execution ok for no reference genome file';
    like ($check->result->comments, qr/No reference genome available/, 'comment when reference genome file is not available');

    $check = npg_qc::autoqc::checks::rna_seqc->new(
        id_run => 17550,
        position => 3,
        tag_index => 8,
        path => 't/data/autoqc/rna_seqc/data',
        repository => $repos,
        annotation_gtf => q[],
        ref_repository => $ref_repos_dir,);
    lives_ok { $check->execute } 'execution ok for no annotation file';
    like ($check->result->comments, qr/No GTF annotation available/, 'comment when annotation file is not available');

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

    $check = npg_qc::autoqc::checks::rna_seqc->new(
        id_run => 17550,
        position => 3,
        tag_index => 8,
        path => 't/data/autoqc/rna_seqc/data',
        repository => $repos,);
    is($check->_is_rna_alignment, 1, 'bam for id run 17550 lane 3 tag 8 from TopHat aligner is RNA alignment');

    $check = npg_qc::autoqc::checks::rna_seqc->new(
        id_run => 6,
        position => 6,
        tag_index => 6,
        path => 't/data/autoqc/rna_seqc/data',
        repository => $repos,);
    is($check->_is_rna_alignment, 1, 'bam for id run 6 lane 6 tag 6 from STAR aligner is RNA alignment');

    $check = npg_qc::autoqc::checks::rna_seqc->new(
        id_run => 17550,
        position => 3,
        tag_index => 2,
        path => 't/data/autoqc/rna_seqc/data',
        repository => $repos,);
    lives_ok { $check->execute } 'execution ok for bam file with no reads';
    like ($check->result->comments, qr/BAM file has no reads/, 'comment when BAM file has no reads');
};

subtest 'Role methods' => sub {
    plan tests => 6;
    my ($r, $om_value);
    use_ok('npg_qc::autoqc::role::rna_seqc');
    use_ok ('npg_qc::autoqc::results::rna_seqc');
    lives_ok {$r = npg_qc::autoqc::results::rna_seqc->load('t/data/autoqc/rna_seqc/data/18407_1#7.rna_seqc.json');} 'load serialised valid result';
    lives_ok {$om_value = $r->other_metrics();} 'extract other metrics';
    is($r->transcripts_detected(), $om_value->{'Transcripts Detected'}, 'value extracted using role method');
    is($r->intronic_rate(), $om_value->{'Intronic Rate'}, 'value extracted using role method');
};


1;

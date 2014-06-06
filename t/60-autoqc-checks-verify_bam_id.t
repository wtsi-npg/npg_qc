#########
# Author:        kt6
# Created:       5 June 2104
#

use strict;
use warnings;
use Cwd;
use File::Temp qw/ tempdir /;
use Test::More tests => 24;
use Test::Exception;

my $repos = cwd . '/t/data/autoqc';
my $snv_repository = cwd . '/t/data/autoqc/population_snv';
my $snv_repository_with_vcf = cwd . '/t/data/autoqc/population_snv_with_vcf';

$ENV{NPG_WEBSERVICE_CACHE_DIR} = q[t/data/autoqc];

use_ok ('npg_qc::autoqc::checks::verify_bam_id');

my $dir = tempdir(CLEANUP => 1);
{
    my $r = npg_qc::autoqc::checks::verify_bam_id->new( 
      id_run => 2549, 
      position => 4, 
      input_file_ext => 'bam', 
      path => 't/data/autoqc/', 
      bam_file => 'alignment.bam',
      repository => $repos,
      snv_repository => $snv_repository,
    ); 
    isa_ok ($r, 'npg_qc::autoqc::checks::verify_bam_id');
    lives_ok { $r->result; } 'No error creating result object';
    ok( defined $r->ref_repository(), 'A default reference repository is set' );
    is($r->lims->library_type, undef, 'Library type returned OK');
    is($r->alignments_in_bam, undef, 'Alignments in bam undefined');
    is($r->lims->reference_genome, undef, 'No reference genome');    
    is($r->can_run, 0, 'Not done if library_type is undef');
    is($r->snv_path, undef, 'snv path is not set');
}

{
    my $r = npg_qc::autoqc::checks::verify_bam_id->new( 
      id_run => 2549, 
      position => 1, 
      input_file_ext => 'bam', 
      path => 't/data/autoqc/', 
      bam_file => 'alignment.bam',
      repository => $repos,
      snv_repository => $snv_repository,
    ); 
    isa_ok ($r, 'npg_qc::autoqc::checks::verify_bam_id');
    lives_ok { $r->result; } 'No error creating result object';
    ok( defined $r->ref_repository(), 'A default reference repository is set' );
    is($r->lims->library_type, 'Standard', 'Standard library type returned OK');
    is($r->alignments_in_bam, 1, 'Alignments in bam');
    is($r->snv_path, undef, 'snv path is not set');
    is($r->can_run, 0, 'Not done if library_type is Standard and bam file is aligned BUT there is no VCF file');
}

{
    my $r = npg_qc::autoqc::checks::verify_bam_id->new( 
      id_run => 2549, 
      position => 1, 
      input_file_ext => 'bam', 
      path => 't/data/autoqc/', 
      bam_file => 'alignment.bam',
      repository => $repos,
      snv_repository => $snv_repository_with_vcf,
    ); 
    isa_ok ($r, 'npg_qc::autoqc::checks::verify_bam_id');
    is($r->lims->reference_genome, 'Anopheles_gambiae (PEST)' , 'Has a reference genome');    
    my $snv_path = join '/', cwd, 't/data/autoqc/population_snv_with_vcf/Anopheles_gambiae/default/Standard/PEST';
    is($r->snv_path, $snv_path, 'snv path is set correctly');
    is($r->can_run, 1, 'Done if library_type is Standard and bam file is aligned and there is a VCF file');
}

{
    my $r = npg_qc::autoqc::checks::verify_bam_id->new( 
      id_run => 2549, 
      position => 2, 
      input_file_ext => 'bam', 
      path => 't/data/autoqc/', 
      bam_file => 'alignment.bam',
      repository => $repos,
      snv_repository => $snv_repository_with_vcf,
    ); 
    isa_ok ($r, 'npg_qc::autoqc::checks::verify_bam_id');
    is($r->lims->reference_genome, 'Anopheles_gambiae (PEST)' , 'Has a reference genome');    
    my $snv_path = join '/', cwd, 't/data/autoqc/population_snv_with_vcf/Anopheles_gambiae/default/Standard/PEST';
    is($r->snv_path, $snv_path, 'snv path is set correctly');
    is($r->can_run, 0, 'Not done if library_type is cRNA and bam file is aligned and there is a VCF file');
}

1;

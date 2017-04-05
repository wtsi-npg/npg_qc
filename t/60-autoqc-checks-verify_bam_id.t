use strict;
use warnings;
use Cwd;
use File::Temp qw/ tempdir /;
use Test::More tests => 49;
use Test::Exception;

my $repos = cwd . '/t/data/autoqc';
my $snv_repository = cwd . '/t/data/autoqc/population_snv';
my $snv_repository_with_vcf = cwd . '/t/data/autoqc/population_snv_with_vcf';

$ENV{NPG_WEBSERVICE_CACHE_DIR} = q[t/data/autoqc];

use_ok ('npg_qc::autoqc::checks::verify_bam_id');

my $dir = tempdir(CLEANUP => 1);
{
  my @checks = ();
  push @checks, npg_qc::autoqc::checks::verify_bam_id->new( 
      id_run => 13940, 
      position => 8, 
      qc_in => 't/data/autoqc/', 
      repository => $repos,
      snv_repository => $snv_repository_with_vcf );
  push @checks, npg_qc::autoqc::checks::verify_bam_id->new( 
      rpt_list => '13940:8', 
      qc_in => 't/data/autoqc/', 
      repository => $repos,
      snv_repository => $snv_repository_with_vcf );
  
  foreach my $r (@checks) {
    isa_ok ($r, 'npg_qc::autoqc::checks::verify_bam_id');
    lives_ok { $r->result; } 'No error creating result object';
    ok( defined $r->ref_repository(), 'A default reference repository is set' );
    is($r->lims->library_type, undef, 'Library type returned OK');
    ok($r->alignments_in_bam, 'Alignments in bam true');
    is($r->lims->reference_genome, 'Homo_sapiens (1000Genomes_hs37d5)', 'reference genome');    
    ok($r->can_run, 'Can run at lane level for single plex in pool') or diag $r->result->comments;
    my $snv_path = join '/', cwd, 't/data/autoqc/population_snv_with_vcf/Homo_sapiens/default/Standard/1000Genomes_hs37d5';
    is($r->snv_path, $snv_path, 'snv path is set');
  }
}

{
  my @checks = ();
  push @checks, npg_qc::autoqc::checks::verify_bam_id->new( 
      id_run => 13886, 
      position => 8, 
      qc_in    => 't/data/autoqc/', 
      repository => $repos,
      snv_repository => $snv_repository_with_vcf);
  push @checks, npg_qc::autoqc::checks::verify_bam_id->new( 
      rpt_list => '13886:8', 
      qc_in => 't/data/autoqc/', 
      repository => $repos,
      snv_repository => $snv_repository_with_vcf);

  foreach my $r (@checks) {
    lives_ok { $r->result; } 'No error creating result object';
    ok( defined $r->ref_repository(), 'A default reference repository is set' );
    is($r->lims->library_type, undef, 'Library type returned OK');
    ok($r->alignments_in_bam, 'Alignments in bam true');
    is($r->lims->reference_genome, 'Homo_sapiens (1000Genomes_hs37d5)', 'reference genome');    
    ok((not $r->can_run), 'Cannot run at lane level for multi plex in pool') or diag $r->result->comments;
    my $snv_path = join '/', cwd, 't/data/autoqc/population_snv_with_vcf/Homo_sapiens/default/Standard/1000Genomes_hs37d5';
    is($r->snv_path, $snv_path, 'snv path is set');
  }
}

{
  my $r = npg_qc::autoqc::checks::verify_bam_id->new( 
      id_run => 2549, 
      position => 4, 
      file_type => 'bam', 
      path => 't/data/autoqc/', 
      bam_file => 'alignment.bam',
      repository => $repos,
      snv_repository => $snv_repository,
  ); 
  lives_ok { $r->result; } 'No error creating result object';
  ok( defined $r->ref_repository(), 'A default reference repository is set' );
  is($r->lims->library_type, undef, 'Library type returned OK');
  ok((not $r->alignments_in_bam), 'Alignments in bam false');
  is($r->lims->reference_genome, undef, 'No reference genome');    
  is($r->can_run, 0, 'Not done if library_type is undef');
  is($r->snv_path, undef, 'snv path is not set');
}

{
  my $r = npg_qc::autoqc::checks::verify_bam_id->new( 
      id_run => 2549, 
      position => 1, 
      file_type => 'bam', 
      path => 't/data/autoqc/', 
      bam_file => 'alignment.bam',
      repository => $repos,
      snv_repository => $snv_repository,
  ); 
  lives_ok { $r->result; } 'No error creating result object';
  ok( defined $r->ref_repository(), 'A default reference repository is set' );
  is($r->lims->library_type, 'Standard', 'Standard library type returned OK');
  is($r->alignments_in_bam, 1, 'Alignments in bam');
  is($r->snv_path, undef, 'snv path is not set');
  throws_ok {$r->execute()} qr/Can't find snv file/,
    'Not done if library_type is Standard and bam file is aligned BUT there is no VCF file';
}

{
  my $r = npg_qc::autoqc::checks::verify_bam_id->new( 
      id_run => 2549, 
      position => 1, 
      file_type => 'bam', 
      path => 't/data/autoqc/', 
      bam_file => 'alignment.bam',
      repository => $repos,
      snv_repository => $snv_repository_with_vcf,
  ); 
  is($r->lims->reference_genome, 'Anopheles_gambiae (PEST)' , 'Has a reference genome');    
  my $snv_path = join '/', cwd, 't/data/autoqc/population_snv_with_vcf/Anopheles_gambiae/default/Standard/PEST';
  is($r->snv_path, $snv_path, 'snv path is set correctly');
}

{
  my $r = npg_qc::autoqc::checks::verify_bam_id->new( 
      id_run => 2549, 
      position => 2, 
      file_type => 'bam', 
      path => 't/data/autoqc/', 
      bam_file => 'alignment.bam',
      repository => $repos,
      snv_repository => $snv_repository_with_vcf,
  ); 
  is($r->lims->reference_genome, 'Anopheles_gambiae (PEST)' , 'Has a reference genome');    
  my $snv_path = join '/', cwd, 't/data/autoqc/population_snv_with_vcf/Anopheles_gambiae/default/Standard/PEST';
  is($r->snv_path, $snv_path, 'snv path is set correctly');
  is($r->can_run, 0, 'Not done if library_type is cRNA and bam file is aligned and there is a VCF file');
}

1;

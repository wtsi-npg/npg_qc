use strict;
use warnings;
use Cwd;
use Test::More tests => 54;
use Test::Exception;
use npg_tracking::util::abs_path qw(abs_path);

my $repos                   = 't/data/autoqc';
my $snv_repository          = 't/data';
my $snv_repository_with_vcf = 't/data/autoqc/population_snv_with_vcf';

$ENV{NPG_WEBSERVICE_CACHE_DIR} = q[t/data/autoqc];

use_ok ('npg_qc::autoqc::checks::verify_bam_id');

{
  my @checks = ();
  push @checks, npg_qc::autoqc::checks::verify_bam_id->new(
      id_run         => 13940,
      position       => 8,
      qc_in          => 't/data/autoqc/',
      repository     => $repos,
      snv_repository => $snv_repository_with_vcf );
  push @checks, npg_qc::autoqc::checks::verify_bam_id->new(
      rpt_list       => '13940:8',
      qc_in          => 't/data/autoqc/',
      repository     => $repos,
      snv_repository => $snv_repository_with_vcf );

  foreach my $r (@checks) {
    isa_ok ($r, 'npg_qc::autoqc::checks::verify_bam_id');
    lives_ok { $r->result; } 'No error creating result object';
    ok( defined $r->ref_repository(), 'A default reference repository is set' );
    is($r->lims->library_type, undef, 'Library type returned OK');
    ok($r->alignments_in_bam, 'Alignments in bam true');
    is($r->lims->reference_genome, 'Homo_sapiens (1000Genomes_hs37d5)', 'reference genome');
    ok($r->can_run, 'Can run at lane level for single plex in pool') or diag $r->result->comments;
    my $snv_path = abs_path(join '/', cwd,
      't/data/autoqc/population_snv_with_vcf/Homo_sapiens/default/Standard/1000Genomes_hs37d5');
    is($r->snv_path, $snv_path, 'snv path is set');
  }
}

{
  my @checks = ();
  push @checks, npg_qc::autoqc::checks::verify_bam_id->new(
      id_run         => 13886,
      position       => 8,
      qc_in          => 't/data/autoqc/',
      repository     => $repos,
      snv_repository => $snv_repository_with_vcf);
  push @checks, npg_qc::autoqc::checks::verify_bam_id->new(
      rpt_list       => '13886:8',
      qc_in          => 't/data/autoqc/',
      repository     => $repos,
      snv_repository => $snv_repository_with_vcf);

  foreach my $r (@checks) {
    lives_ok { $r->result; } 'No error creating result object';
    ok( defined $r->ref_repository(), 'A default reference repository is set' );
    is($r->lims->library_type, undef, 'Library type returned OK');
    ok($r->alignments_in_bam, 'Alignments in bam true');
    is($r->lims->reference_genome, 'Homo_sapiens (1000Genomes_hs37d5)', 'reference genome');
    ok((not $r->can_run), 'Cannot run at lane level for multi plex in pool') or diag $r->result->comments;
    my $snv_path = abs_path(join '/', cwd,
      't/data/autoqc/population_snv_with_vcf/Homo_sapiens/default/Standard/1000Genomes_hs37d5');
    is($r->snv_path, $snv_path, 'snv path is set');
  }
}

{
  my $h = {
      id_run         => 2549,
      position       => 4,
      input_files    => [qw(t/data/autoqc/alignment.bam)],
      bam_file       => 'alignment.bam',
      repository     => $repos,
      snv_repository => $snv_repository
  };

  my $r = npg_qc::autoqc::checks::verify_bam_id->new($h);
  lives_ok { $r->result; } 'No error creating result object';
  ok( defined $r->ref_repository(), 'A default reference repository is set' );
  is($r->lims->library_type, undef, 'Library type returned OK');
  ok((not $r->alignments_in_bam), 'Alignments in bam false');
  is($r->lims->reference_genome, undef, 'No reference genome');
  is($r->can_run, 0, 'Not done if library_type is undef');
  is($r->snv_path, undef, 'snv path is not set');

  $h->{'position'}       = 1;
  $h->{'snv_repository'} = $snv_repository_with_vcf;

  $r = npg_qc::autoqc::checks::verify_bam_id->new($h);
  ok( defined $r->ref_repository(), 'A default reference repository is set' );
  is($r->lims->library_type, 'Standard', 'Standard library type returned OK');
  is($r->alignments_in_bam, 1, 'Alignments in bam');
  is($r->lims->reference_genome, 'Anopheles_gambiae (PEST)', 'reference');
  is($r->can_run, 0, 'Not done - reference is not human');

  my $snv_path = abs_path(join '/', cwd,
    't/data/autoqc/population_snv_with_vcf/Anopheles_gambiae/default/Standard/PEST');
  is($r->snv_path, $snv_path, 'snv path is set correctly');

  $h->{'position'}       = 8;
  $h->{'snv_repository'} = $snv_repository;
  $r = npg_qc::autoqc::checks::verify_bam_id->new($h);
  is($r->lims->library_type, 'High complexity',
    '"High complexity" library type returned OK');
  is($r->lims->reference_genome, 'Homo_sapiens (SOME_OR_OTHER)', 'reference');
  is($r->can_run, 1, 'Can run - reference is human');
  throws_ok { $r->execute() } qr/Can't find snv file/,
    'run-time error if no snv file found';
}


{
    my @checks = ();
    # Cases of instances like this have already been tested for above:
    #    npg_qc::autoqc::checks::verify_bam_id->new(
    #       id_run => 27483, position => 1, qc_in => 't/data/autoqc/',
    #       repository => $repos, snv_repository => $snv_repository_with_vcf);
    # These instances test if (cD|R)NA libraries use Exome baits:
    push @checks, npg_qc::autoqc::checks::verify_bam_id->new(
        rpt_list       => '27483:1:1',
        qc_in          => 't/data/autoqc/',
        repository     => $repos,
        snv_repository => $snv_repository_with_vcf);
    foreach my $r (@checks) {
        lives_ok {$r->result;} 'No error creating result object';
        ok(defined $r->ref_repository(), 'A default reference repository is set');
        like($r->lims->library_type, qr/(?:cD|R)NA/sxm, 'Library type returned OK');
        ok($r->alignments_in_bam, 'Alignments in bam true');
        like($r->lims->reference_genome, qr/Homo_sapiens/, 'human reference genome');
        my $snv_path = abs_path(join '/', cwd,
            't/data/autoqc/population_snv_with_vcf/Homo_sapiens/default/Exome/GRCh38_15');
        is($r->snv_path, $snv_path, 'snv path is set');
    }
}

1;

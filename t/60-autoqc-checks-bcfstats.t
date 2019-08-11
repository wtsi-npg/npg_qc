use strict;
use warnings;
use Cwd;
use Test::More tests => 5;
use Test::Exception;
use npg_tracking::util::abs_path qw(abs_path);
use File::Temp qw/ tempdir /;


use_ok ('npg_qc::autoqc::checks::bcfstats');


my $dir = tempdir( CLEANUP => 1 );
my $bt  = join q[/], $dir, q[bcftools];
`touch $bt`;
`chmod +x $bt`;

my $st  = join q[/], $dir, q[samtools];
`touch $st`;
`chmod +x $st`;

local $ENV{PATH} = join q[:], $dir, $ENV{PATH};


my $repos             = 't/data/autoqc';
my $geno_repository   = 't/data/autoqc/geno_refset_repository';

local $ENV{http_proxy} = 'wibble';

## edited for test purposes
local $ENV{'NPG_CACHED_SAMPLESHEET_FILE'} = q[t/data/autoqc/bcfstats/samplesheet_21835.csv];


subtest 'test attributes and simple methods' => sub {
  plan tests => 20;

  my @checks = ();
  push @checks, npg_qc::autoqc::checks::bcfstats->new( 
      id_run                 => 21835,
      position               => 1,
      tag_index              => 1,
      qc_in                  => $repos, 
      repository             => $repos,
      geno_refset_repository => $geno_repository );

  push @checks, npg_qc::autoqc::checks::bcfstats->new( 
      rpt_list               => '21835:1:1', 
      qc_in                  => $repos, 
      repository             => $repos,
      geno_refset_repository => $geno_repository );

   foreach my $r (@checks) {
       isa_ok ($r, 'npg_qc::autoqc::checks::bcfstats');
       lives_ok { $r->result; } 'No error creating result object';
       ok( defined $r->ref_repository(), 'A default reference repository is set' );
       is($r->geno_refset_name, 'study3705', 'Default geno refset name returned OK');

       my $fasta = abs_path(join '/', cwd,
        't/data/autoqc/references/Homo_sapiens/GRCh38_full_analysis_set_plus_decoy_hla/all/fasta/GRCh38_full_analysis_set_plus_decoy_hla.fasta');
       is($r->reference_fasta, $fasta, 'reference_fasta path is set OK');

        my $geno_annotation = abs_path(join '/', cwd,
        't/data/autoqc/geno_refset_repository/study3705/GRCh38_full_analysis_set_plus_decoy_hla/bcftools/study3705.annotation.vcf');
       is($r->geno_refset_annotation_path, $geno_annotation, 'geno annotation path is set OK');
       
       my $geno_bcfdb = abs_path(join '/', cwd,
        't/data/autoqc/geno_refset_repository/study3705/GRCh38_full_analysis_set_plus_decoy_hla/bcfdb/study3705.bcf');
       is($r->geno_refset_bcfdb_path, $geno_bcfdb, 'geno bcfdb path is set OK');
      
       lives_ok { $r->bcftools_cmd } 'No error calling bcftools accessor';      
       lives_ok { $r->samtools_cmd } 'No error calling samtools accessor';      

       ok($r->can_run, 'Can run on tag in multiplexed pool') or diag $r->result->comments;
 
   }
};

subtest 'test can set geno refset' => sub {
    plan tests => 4;

    my $h = {     
      rpt_list               => '21835:1:1',
      qc_in                  => $repos, 
      bam_file               => 'alignment.bam',
      repository             => $repos,
      geno_refset_repository => $geno_repository,
      geno_refset_name       => 'myspecialset'
  };
  my $r = npg_qc::autoqc::checks::bcfstats->new($h);
  lives_ok { $r->result; } 'No error creating result object';
  ok( defined $r->ref_repository(), 'A default reference repository is set' );
  is($r->geno_refset_name, 'myspecialset', 'Specified geno refset name returned OK');
  is($r->can_run, 0, 'Cant run if geno refset repository is undef');
};

subtest 'test cant run on pool at lane level' => sub {
  plan tests => 8;
  
  my @checks = ();
  push @checks, npg_qc::autoqc::checks::bcfstats->new( 
      id_run                 => 21835, 
      position               => 1,
      qc_in                  => $repos, 
      repository             => $repos,
      geno_refset_repository => $geno_repository );

  push @checks, npg_qc::autoqc::checks::bcfstats->new( 
      rpt_list               => '21835:1', 
      qc_in                  => $repos, 
      repository             => $repos,
      geno_refset_repository => $geno_repository );

   foreach my $r (@checks) {
       isa_ok ($r, 'npg_qc::autoqc::checks::bcfstats');
       lives_ok { $r->result; } 'No error creating result object';
       ok( defined $r->ref_repository(), 'A default reference repository is set' );
       ok((not $r->can_run), 'Cant run at lane level on multiplexed pool') or diag $r->result->comments;
   }
};


subtest 'test cant run on incorrect types' => sub {
  plan tests => 3;
  
  my $h = {
      rpt_list               => '21835:8:1',
      qc_in                  => $repos, 
      bam_file               => 'alignment.bam',
      repository             => $repos,
      geno_refset_repository => $geno_repository
  };
  my $r = npg_qc::autoqc::checks::bcfstats->new($h);
  lives_ok { $r->result; } 'No error creating result object';
  ok( defined $r->ref_repository(), 'A default reference repository is set' );
  is($r->can_run, 0, 'Cant run if geno refset repository is undef');

};


1;

use strict;
use warnings;
use Cwd;
use Test::More tests => 4;
use Test::Exception;
use npg_tracking::util::abs_path qw(abs_path);
use File::Temp qw/ tempdir /;


use_ok ('npg_qc::autoqc::checks::genotype_call');


my $dir = tempdir( CLEANUP => 1 );
my $bt  = join q[/], $dir, q[bcftools];
`touch $bt`;
`chmod +x $bt`;

my $st  = join q[/], $dir, q[samtools];
`touch $st`;
`chmod +x $st`;

local $ENV{PATH} = join q[:], $dir, $ENV{PATH};


my $repos             = 't/data/autoqc';
my $gbs_repository    = 't/data/autoqc/gbs_plex_repository';

local $ENV{http_proxy} = 'wibble';
local $ENV{'NPG_CACHED_SAMPLESHEET_FILE'} = q[t/data/autoqc/genotype_call/samplesheet_24135.csv];


subtest 'test attributes and simple methods' => sub {
  plan tests => 20;

  my @checks = ();
  push @checks, npg_qc::autoqc::checks::genotype_call->new( 
      id_run              => 24135, 
      position            => 1,
      tag_index           => 1,
      qc_in               => $repos, 
      repository          => $repos,
      gbs_plex_repository => $gbs_repository );

  push @checks, npg_qc::autoqc::checks::genotype_call->new( 
      rpt_list            => '24135:1:1', 
      qc_in               => $repos, 
      repository          => $repos,
      gbs_plex_repository => $gbs_repository );

   foreach my $r (@checks) {
       isa_ok ($r, 'npg_qc::autoqc::checks::genotype_call');
       lives_ok { $r->result; } 'No error creating result object';
       ok( defined $r->ref_repository(), 'A default reference repository is set' );
       is($r->lims->library_type, 'GbS standard', 'Library type returned OK');
       is($r->lims->gbs_plex_name, 'Hs_MajorQC', 'GbS plex name returned OK');

       my $fasta = abs_path(join '/', cwd,
        't/data/autoqc/gbs_plex_repository/Hs_MajorQC/default/all/fasta/Hs_MajorQC.fa');
       is($r->reference_fasta, $fasta, 'reference_fasta path is set OK');

        my $gbs_annotation = abs_path(join '/', cwd,
        't/data/autoqc/gbs_plex_repository/Hs_MajorQC/default/all/bcftools/Hs_MajorQC.annotation.vcf');
       is($r->gbs_plex_annotation_path, $gbs_annotation, 'gbs_annotation path is set OK');
      
       lives_ok { $r->bcftools_cmd } 'No error calling bcftools accessor';      
       lives_ok { $r->samtools_cmd } 'No error calling samtools accessor';      

       ok($r->can_run, 'Can run on tag in multiplexed pool') or diag $r->result->comments;
 
   }
};

subtest 'test cant run on pool at lane level' => sub {
  plan tests => 8;
  
  my @checks = ();
  push @checks, npg_qc::autoqc::checks::genotype_call->new( 
      id_run              => 24135, 
      position            => 1,
      qc_in               => $repos, 
      repository          => $repos,
      gbs_plex_repository => $gbs_repository );

  push @checks, npg_qc::autoqc::checks::genotype_call->new( 
      rpt_list            => '24135:1', 
      qc_in               => $repos, 
      repository          => $repos,
      gbs_plex_repository => $gbs_repository );

   foreach my $r (@checks) {
       isa_ok ($r, 'npg_qc::autoqc::checks::genotype_call');
       lives_ok { $r->result; } 'No error creating result object';
       ok( defined $r->ref_repository(), 'A default reference repository is set' );
       ok((not $r->can_run), 'Cant run at lane level on multiplexed pool') or diag $r->result->comments;
   }
};


## fake sample sheet
local $ENV{'NPG_CACHED_SAMPLESHEET_FILE'} = q[t/data/autoqc/genotype_call/samplesheet_24135_test.csv];


subtest 'test cant run on incorrect types' => sub {
  plan tests => 3;
  
  my $h = {
      rpt_list            => '24135:1:1',
      qc_in               => $repos, 
      bam_file            => 'alignment.bam',
      repository          => $repos,
      gbs_plex_repository => $gbs_repository
  };
  my $r = npg_qc::autoqc::checks::genotype_call->new($h);
  lives_ok { $r->result; } 'No error creating result object';
  ok( defined $r->ref_repository(), 'A default reference repository is set' );
  is($r->can_run, 0, 'Cant run if gbs plex is undef');

};


1;

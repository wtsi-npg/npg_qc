use strict;
use warnings;
use Cwd;
use File::Temp qw/ tempdir /;
use Test::More tests => 6;
use Test::Exception;

my $ref_repos = cwd . '/t/data/autoqc';
my $archive_qc_path = cwd . '/t/data/autoqc/tag_metrics';
my $tag_sets_repository = cwd . '/t/data/autoqc/tag_sets';

SKIP: { skip 'require bammaskflags', 6, unless `which bammaskflags`;

  use_ok ('npg_qc::autoqc::checks::upstream_tags');

  my $EXIST_EXECUTABLES = `which icd`;

  # ensure we're in the user's iRODs home
  my $have_irods;
  if ($EXIST_EXECUTABLES) {
    `icd`;
    $have_irods = system("imkdir test") == 0 ? 1 : 0;
  }

  my $dir = tempdir(CLEANUP => 1);
  `touch $dir/BamIndexDecoder.jar`;
  local $ENV{CLASSPATH} = $dir; 

  { 
    my $r = npg_qc::autoqc::checks::upstream_tags->new(
      repository => $ref_repos, id_run => 2, path => q[t], position => 1);
    isa_ok ($r, 'npg_qc::autoqc::checks::upstream_tags');
    lives_ok { $r->result; } 'No error creating result object';
  }

  SKIP: {
      unless ($EXIST_EXECUTABLES) {
        skip 'unable to access iRODS executables', 3;
      }
      elsif (!`which samtools_irods`) {
        skip 'require samtools_irods', 3;
      }
      elsif (!$have_irods) {
        skip 'unable to create iRODS test dir (try kinit to log in to iRODS)', 3;
      }

      {
        my $r = npg_qc::autoqc::checks::upstream_tags->new(
          repository => $ref_repos, id_run => 6954,
          qc_in      => $archive_qc_path,
          tag_sets_repository => $tag_sets_repository, position => 1);
        my $expected = $ref_repos . '/tag_sets/sanger168.tags';
        is($r->barcode_filename, $expected, 'correct barcode filename');
      }

      {
        my $r = npg_qc::autoqc::checks::upstream_tags->new(repository => $ref_repos, id_run => 13362,
          qc_in => $archive_qc_path, tag_sets_repository => $tag_sets_repository, position => 1);
        my $expected = $ref_repos . '/tag_sets/sanger168_6.tags';
        is($r->barcode_filename, $expected, 'correct barcode filename');
      }

      {
        my $r = npg_qc::autoqc::checks::upstream_tags->new(repository => $ref_repos, id_run => 12920,
          qc_in => $archive_qc_path, tag_sets_repository => $tag_sets_repository, position => 1);
        my $expected = $ref_repos . '/tag_sets/sanger168_7.tags';
        is($r->barcode_filename, $expected, 'correct barcode filename');
      }
  }
  `irm -r test`;
}

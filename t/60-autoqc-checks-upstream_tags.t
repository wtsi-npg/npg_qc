use strict;
use warnings;
use Cwd;
use File::Temp qw/ tempdir /;
use Test::More tests => 7;
use Test::Exception;

my $ref_repos = cwd . '/t/data/autoqc';
my $archive_qc_path = cwd . '/t/data/autoqc/upstream_tags';
my $tag_sets_repository = cwd . '/t/data/autoqc/tag_sets';

use_ok ('npg_qc::autoqc::checks::upstream_tags');

SKIP: { skip 'require bammaskflags', 6, unless `which bammaskflags`;

  my $dir = tempdir(CLEANUP => 1);
  `touch $dir/BamIndexDecoder.jar`;
  local $ENV{CLASSPATH} = $dir;

  my %h = (
    position            => 1,
    repository          => $ref_repos,
    qc_in               => $archive_qc_path,
    tag_sets_repository => $tag_sets_repository
          );

  my %ref = %h;
  $ref{'id_run'} = 6954;
  my $r = npg_qc::autoqc::checks::upstream_tags->new(\%ref);
  isa_ok ($r, 'npg_qc::autoqc::checks::upstream_tags');
  my $result;
  lives_ok { $result = $r->result; } 'No error creating result object';
  isa_ok ($result, 'npg_qc::autoqc::results::upstream_tags');  
  my $expected = $ref_repos . '/tag_sets/sanger168.tags';
  is($r->barcode_filename, $expected, 'correct barcode filename');

  %ref = %h;
  $ref{'id_run'} = 13362;
  $r = npg_qc::autoqc::checks::upstream_tags->new(\%ref);
  $expected = $ref_repos . '/tag_sets/sanger168_6.tags';
  is($r->barcode_filename, $expected, 'correct barcode filename');

  %ref = %h;
  $ref{'id_run'} = 12920;
  $r = npg_qc::autoqc::checks::upstream_tags->new(\%ref);
  $expected = $ref_repos . '/tag_sets/sanger168_7.tags';
  is($r->barcode_filename, $expected, 'correct barcode filename');
};

1;
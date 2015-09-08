use strict;
use warnings;
use Test::More tests => 5;
use Test::Exception;
use File::Temp qw/ tempdir /;
use Archive::Extract;
use Compress::Zlib;
use Perl6::Slurp;

use npg_tracking::glossary::composition::component::illumina;

my $tempdir = tempdir( CLEANUP => 1);
my $archive = '17448_1_9';
my $ae = Archive::Extract->new(archive => "t/data/autoqc/bam_flagstats/${archive}.tar.gz");
$ae->extract(to => $tempdir) or die $ae->error;
$archive = join q[/], $tempdir, $archive;
my $file1 = join q[/], $archive, '17448_1#9_F0x900.stats';

use_ok ('npg_qc::autoqc::results::samtools_stats');

subtest 'object with an empty composition' => sub {
  plan tests => 8;

  throws_ok { npg_qc::autoqc::results::samtools_stats->new() }
    qr/Attribute \(stats_file\) is required/,
    'no-argument constructor - error';
  throws_ok { npg_qc::autoqc::results::samtools_stats->new(
        stats_file => '/some/file') } 
    qr/Validation failed for 'NpgTrackingReadableFile' with value "\/some\/file"/,
    'stats file does not exist - error';

  my $r;
  lives_ok { $r = npg_qc::autoqc::results::samtools_stats->new(
        stats_file => $file1 ) }
    'one-arg constructor (stats_file) - object created';
  isa_ok ($r, 'npg_qc::autoqc::results::samtools_stats');

  is ($r->num_components, 0, 'no components');
  throws_ok { $r->composition_digest() }
    qr/Composition is empty, cannot compute digest/,
    'composition is empty - error generating digest';
  throws_ok { $r->filter }
    qr/Composition is empty, cannot compute values for subset/,
    'composition is empty - error building filter';
  throws_ok { $r->execute() }
    qr/Empty composition - cannot run/,
    'composition is empty - error running execute()';
};

subtest 'object with an one-component composition' => sub { 
  plan tests => 10;

  my $c = npg_tracking::glossary::composition::component::illumina->new(
    id_run => 17448, position => 1, tag_index => 9);
  my $r = npg_qc::autoqc::results::samtools_stats->new(stats_file => $file1);
  $r->composition->add_component($c);

  is ($r->num_components, 1, 'one component');
  is ($r->composition_digest(),
    'bfc10d33f4518996db01d1b70ebc17d986684d2e04e20ab072b8b9e51ae73dfa', 'digest');
  is ($r->filter, 'F0x900', 'filter');
  is ($r->composition_subset, undef, 'subset undefined');
  ok (!$r->_has_stats, 'stats attribute is not built yet');
  lives_ok { $r->execute() } 'execute() method runs successfully';
  ok ($r->_has_stats, 'stats attribute has been built');
  is (uncompress($r->stats), slurp($file1), 'stats file content saved correctly');
  is ($r->filename_root, '17448_1#9_F0x900', 'filename root');
  is ($r->to_string(),
    'npg_qc::autoqc::results::samtools_stats {"components":[{"id_run":17448,"position":1,"tag_index":9}]}',
    'string representation');
};

subtest 'object with an one-component phix subset composition' => sub { 
  plan tests => 6;

  my $c = npg_tracking::glossary::composition::component::illumina->new(
    id_run => 17448, position => 1, tag_index => 9, subset => 'phix');
  my $file2 = join q[/], $archive, '17448_1#9_phix_F0xB00.stats';
  my $r = npg_qc::autoqc::results::samtools_stats->new(stats_file => $file2);
  $r->composition->add_component($c);
  is ($r->composition_digest(),
    'ca4c3f9e6f8247fed589e629098d4243244ecd71f588a5e230c3353f5477c5cb', 'digest');
  is ($r->filter, 'F0xB00', 'filter');
  is ($r->composition_subset, 'phix', 'phix subset');
  is (uncompress($r->stats), slurp($file2), 'stats file content saved correctly');
  is ($r->filename_root, '17448_1#9_phix_F0xB00', 'filename root');
  is ($r->to_string(),
    'npg_qc::autoqc::results::samtools_stats {"components":[{"id_run":17448,"position":1,"subset":"phix","tag_index":9}]}',
    'string representation');
};

subtest 'serialization and instantiation' => sub { 
  plan tests => 13;

  my $c = npg_tracking::glossary::composition::component::illumina->new(
    id_run => 17448, position => 1, tag_index => 9);
  my $r = npg_qc::autoqc::results::samtools_stats->new(stats_file => $file1);
  $r->composition->add_component($c);
  my $digest = $r->composition_digest;
  ok (!$r->_has_stats, 'stats attribute is not built yet');
  
  my $json = $r->freeze();
  my $r1 = npg_qc::autoqc::results::samtools_stats->thaw($json);
  isa_ok ($r1, 'npg_qc::autoqc::results::samtools_stats');
  is ($r1->to_string, $r->to_string, 'the same string representation');
  is ($r1->composition_digest, $digest, 'the same composition digest');
  ok (!$r1->_has_stats, 'stats attribute is not built yet');
  lives_ok { $r1->execute() } 'execute() method runs successfully';
  ok ($r1->_has_stats, 'stats attribute has been built');
  is ($r1->filter, 'F0x900', 'filter');
  is (uncompress($r1->stats), slurp($file1), 'stats file content generated correctly');

  my $json1 = $r1->freeze();
  isnt ($json, $json1, 'different json representations');
  my $r2 = npg_qc::autoqc::results::samtools_stats->thaw($json1);
  isa_ok ($r2, 'npg_qc::autoqc::results::samtools_stats');
  is ($r2->composition_digest, $digest, 'the same composition digest');
  ok ($r2->_has_stats, 'stats attribute has been built');
};

1;
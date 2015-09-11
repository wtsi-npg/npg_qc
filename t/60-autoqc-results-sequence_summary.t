use strict;
use warnings;
use Test::More tests => 3;
use Test::Exception;
use File::Temp qw/ tempdir /;
use Archive::Extract;
use Perl6::Slurp;

use npg_tracking::glossary::composition::component::illumina;
use t::autoqc_util qw/ write_samtools_script /;

my $tempdir = tempdir( CLEANUP => 1);
my $archive = '17448_1_9';
my $ae = Archive::Extract->new(archive => "t/data/autoqc/bam_flagstats/${archive}.tar.gz");
$ae->extract(to => $tempdir) or die $ae->error;
$archive = join q[/], $tempdir, $archive;

my $samtools_path  = join q[/], $tempdir, 'samtools1';
local $ENV{'PATH'} = join q[:], $tempdir, $ENV{'PATH'};
# Create mock samtools1 that will output the header
my $header_file = join q[/],$archive,'cram.header';
write_samtools_script($samtools_path, $header_file);

my $file = join q[/], $archive, '17448_1#9.cram';

use_ok ('npg_qc::autoqc::results::sequence_summary');

subtest 'simple tests' => sub {
  plan tests => 7;

  throws_ok { npg_qc::autoqc::results::sequence_summary->new() }
    qr/Attribute \(sequence_file\) is required/,
    'no-argument constructor - error';
  throws_ok { npg_qc::autoqc::results::sequence_summary->new(
        sequence_file => '/some/file') } 
    qr/Validation failed for 'NpgTrackingReadableFile' with value "\/some\/file"/,
    'sequence file does not exist - error';

  my $r;
  lives_ok { $r = npg_qc::autoqc::results::sequence_summary->new(
        sequence_file => $file ) }
    'one-arg constructor (sequence_file) - object created';
  isa_ok ($r, 'npg_qc::autoqc::results::sequence_summary');

  is ($r->num_components, 0, 'no components');
  throws_ok { $r->composition_digest() }
    qr/Composition is empty, cannot compute digest/,
    'composition is empty - error generating digest';
  throws_ok { $r->execute() }
    qr/Empty composition - cannot run/,
    'composition is empty - error running execute()';
};

subtest 'object with an one-component composition' => sub {
  plan tests => 7;

  my $c = npg_tracking::glossary::composition::component::illumina->new(
    id_run => 17448, position => 1, tag_index => 9);
  my $r = npg_qc::autoqc::results::sequence_summary->new(sequence_file => $file);
  $r->composition->add_component($c);

  is ($r->num_components, 1, 'one component');
  is ($r->composition_digest(),
    'bfc10d33f4518996db01d1b70ebc17d986684d2e04e20ab072b8b9e51ae73dfa', 'digest');
  is ($r->composition_subset, undef, 'subset undefined');
  lives_ok { $r->execute() } 'execute() method runs successfully';
  is ($r->filename_root, '17448_1#9', 'filename root');
  is ($r->to_string(),
    'npg_qc::autoqc::results::sequence_summary {"components":[{"id_run":17448,"position":1,"tag_index":9}]}',
    'string representation');
  my @header = slurp $header_file;
  my $filter = q[@SQ];
  is ($r->header, join(q[], grep { $_ !~ /\A$filter/ } @header), 'header generated and filtered correctly');
};

1;

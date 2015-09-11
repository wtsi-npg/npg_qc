use strict;
use warnings;
use Test::More tests => 2;
use Test::Exception;
use File::Temp qw/ tempdir /;
use Archive::Extract;

use t::autoqc_util qw/ write_samtools_script /;

my $tempdir = tempdir( CLEANUP => 1);
my $archive = '17448_1_9';
my $ae = Archive::Extract->new(archive => "t/data/autoqc/bam_flagstats/${archive}.tar.gz");
$ae->extract(to => $tempdir) or die $ae->error;
$archive = join q[/], $tempdir, $archive;

my $samtools_path  = join q[/], $tempdir, 'samtools1';
local $ENV{'PATH'} = join q[:], $tempdir, $ENV{'PATH'};
# Create mock samtools1 that will output the header
write_samtools_script($samtools_path, join(q[/],$archive,'cram.header'));

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

  my $file = join q[/], $archive, '17448_1#9.cram';
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

1;

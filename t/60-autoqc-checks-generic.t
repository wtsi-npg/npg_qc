use strict;
use warnings;
use File::Temp qw/tempdir/;
use Test::More tests => 2;
use Test::Exception;

use_ok ('npg_qc::autoqc::checks::generic');

my $tdir = tempdir( CLEANUP => 1 );
local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
  q[t/data/autoqc/verify_bam_id/samplesheet_27483.csv];

subtest 'create object, serialize result' => sub {
  plan tests => 6;

  my $g = npg_qc::autoqc::checks::generic->new(
    rpt_list => '27483:1:4', qc_out => $tdir);
  isa_ok ($g, 'npg_qc::autoqc::checks::generic');
  isa_ok ($g->result, 'npg_qc::autoqc::results::generic',
    'result attribute is built');
  isa_ok ($g->lims, 'st::api::lims', 'lims attribute is built');
  lives_ok { $g->execute() } 'no error running execute() method';
  lives_ok { $g->run() } 'no error running run() method';
  ok (-f "$tdir/27483_1#4.d41d8cd98f00b204e9800998ecf8427e.generic.json",
    'result serialized');
};

1;

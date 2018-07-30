use strict;
use warnings;
use Test::More tests => 4;

use_ok ('npg_qc::autoqc::results::upstream_tags');

my $r = npg_qc::autoqc::results::upstream_tags->new(id_run => 2, position => 1);
isa_ok ($r, 'npg_qc::autoqc::results::upstream_tags');

$r = npg_qc::autoqc::results::upstream_tags->load('t/data/autoqc/upstream_tags/9669_1.upstream_tags.json');
isa_ok ($r, 'npg_qc::autoqc::results::upstream_tags');
is($r->criterion(), q[Currently no pass/fail levels set], 'criteria');

1;


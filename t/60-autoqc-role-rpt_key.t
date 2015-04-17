use strict;
use warnings;
use Test::More tests => 2;

use_ok('npg_qc::autoqc::role::rpt_key');

my @runs = npg_qc::autoqc::role::rpt_key->runs_from_rpt_keys(
  ['5:1', '2:3:456', '4:6', '5:8', '2:4:89']);
is_deeply(\@runs, [2, 4, 5], 'sorted list of three run ids');

1;

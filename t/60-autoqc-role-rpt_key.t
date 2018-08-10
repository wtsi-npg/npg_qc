use strict;
use warnings;
use Test::More tests => 3;

use_ok('npg_qc::autoqc::role::rpt_key');

subtest 'runs from rpt lists' => sub {
  plan tests => 1;
  my @runs = npg_qc::autoqc::role::rpt_key->runs_from_rpt_keys(
    ['5:1', '2:3:456', '4:6', '5:8', '2:4:89']);
  is_deeply(\@runs, [2, 4, 5], 'sorted list of three run ids');
};

subtest 'first rpt key of the rpt lists' => sub {
  plan tests => 3;
  is (npg_qc::autoqc::role::rpt_key->rpt_list2first_rpt_key('5:1'), '5:1');
  is (npg_qc::autoqc::role::rpt_key->rpt_list2first_rpt_key('5:1:2'), '5:1:2');
  is (npg_qc::autoqc::role::rpt_key->rpt_list2first_rpt_key('5:1:2:5:3:4'), '5:1:2');
};

1;

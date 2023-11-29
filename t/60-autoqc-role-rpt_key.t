use strict;
use warnings;
use Test::More tests => 5;

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

subtest 'Unpacking composite RPT strings' => sub {
  plan tests => 1;
  is_deeply(
    npg_qc::autoqc::role::rpt_key->rpt_list2one_hash('1:1:1;1:2:1'),
    {
      id_run => '1',
      position => '1-2',
      tag_index => '1'
    },
    'Composite RPT is turned into a combined object'
  );
};

subtest 'Sorting of lane positions and tag indexes in the /checks/runs library lane view' => sub {
  plan tests => 7;

  my $rpt_tests = [
    [['1:1:888'], ['1:1:888'], 'One in, one out'],
    [['1:1:0', '1:1:1', '1:1:2'], ['1:1:1', '1:1:2', '1:1:0'], 'All-numeric RPTs are sorted, tag 0 last'],
    [['1:20:10', '1:1:9', '1:2:8'], ['1:1:9', '1:2:8', '1:20:10'], 'Positions are sorted numerically over tags'],
    [['1:5:1', '2:1:0', '3:8:888'], ['1:5:1', '2:1:0', '3:8:888'], 'Lanes always win'],
    [['1:1:0', '1:1:1;1:2:1;1:3:1'], ['1:1:1;1:2:1;1:3:1', '1:1:0'], 'Position ranges are sorted first'],
    [['1:1:1;1:2:1;1:3:1', '1:1:0'], ['1:1:1;1:2:1;1:3:1', '1:1:0'], 'Position ranges are sorted first'],
    [['1:1:0', '1:1:1;1:2:1', '1:1:888'], ['1:1:1;1:2:1', '1:1:888', '1:1:0'], 'Merge first, then high tag, then zero']
  ];

  foreach my $rpt (@$rpt_tests) {
    is_deeply([npg_qc::autoqc::role::rpt_key->sort_rpt_keys_zero_last($rpt->[0])], $rpt->[1], $rpt->[2]);
  }
};

1;

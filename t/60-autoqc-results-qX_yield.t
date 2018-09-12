use strict;
use warnings;
use Test::More tests => 3;
use Test::Exception;

use_ok ('npg_qc::autoqc::results::qX_yield');

subtest 'attributes and methods' => sub {
  plan tests => 13;

  my $r = npg_qc::autoqc::results::qX_yield->new(
                  position  => 1,
                  id_run    => 2549);
  isa_ok ($r, 'npg_qc::autoqc::results::qX_yield');
  is($r->check_name(), 'qX yield', 'check name');
  is($r->class_name(), 'qX_yield', 'class name');
  is($r->to_string,
    'npg_qc::autoqc::results::qX_yield {"components":[{"id_run":2549,"position":1}]}',
    'description');
  is($r->threshold_quality, 20, 'default threshold quality');
  $r->threshold_yield1(21);
  $r->threshold_yield2(230);
  $r->yield1(200);
  $r->yield2(30);
  $r->filename1(q[f1]);
  $r->filename2(q[f2]);
  throws_ok {$r->pass_per_read(3)} qr/Invalid read index 3/,
    'error on passing invalid index';
  is($r->pass_per_read(1), 1, 'pass value for read 1');
  is($r->pass_per_read(2), 0, 'pass value for read 2');
  is($r->yield1_q20, 200, 'alternative accessor for yield1');
  is($r->yield2_q20, 30, 'alternative accessor for yield2');

  $r = npg_qc::autoqc::results::qX_yield->new(
                position  => 1,
                id_run    => 2549);
  $r->yield1(200);
  $r->filename1(q[f1]);
  is($r->pass_per_read(1), undef, 'no pass value if threshold undefined');

  $r = npg_qc::autoqc::results::qX_yield->new(
                position  => 1,
                id_run    => 2549);
  $r->threshold_yield1(200);
  $r->filename1(q[f1]);
  is($r->pass_per_read(1), undef, 'no pass value if yield undefined');
  is($r->criterion,
    'yield (number of KBs at and above Q20) is greater than the threshold',
    'criterion string');
};

subtest 'de-serialization from a JSON file' => sub {
  plan tests => 16;

  my $json = 't/data/autoqc/4453_2#0.qX_yield.json';
  my $r;
  lives_ok {$r = npg_qc::autoqc::results::qX_yield->load($json)}
    'loaded JSON for no-file error';
  is($r->pass, undef, 'pass is undef');
  is($r->yield1, undef, 'yield1 is undef');
  is($r->yield2, undef, 'yield2 is undef');
  is($r->threshold_yield1, undef, 'threshold1 is undef');
  is($r->threshold_yield2, undef, 'threshold2 is undef');
  is($r->threshold_quality, 20, 'threshold quality ok');
  is($r->to_string,
    'npg_qc::autoqc::results::qX_yield {"components":[{"id_run":4453,"position":2,"tag_index":0}]}',
    'description');

  $json = 't/data/autoqc/26659_1.qX_yield.json';
  lives_ok {$r = npg_qc::autoqc::results::qX_yield->load($json)}
    'instantiated object from a JSON file';
  is($r->yield1_q20, 2587654, 'q20 yield, forward');
  is($r->yield2_q20, 2158139, 'q20 yield, reverse');
  is($r->yield1_q30, 2541103, 'q30 yield, forward');
  is($r->yield2_q30, 2075662, 'q30 yield, reverse');
  is($r->yield1_q40, 16430, 'q40 yield, forward');
  is($r->yield2_q40, 8248, 'q40 yield, reverse');
  lives_ok { $r->freeze() } 'object can be serialized';
};

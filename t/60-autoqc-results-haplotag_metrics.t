use strict;
use warnings;
use Test::More tests => 2;
use Test::Exception;

use_ok ('npg_qc::autoqc::results::haplotag_metrics');

subtest 'test attributes and simple methods' => sub {
  plan tests => 7;

  my $r = npg_qc::autoqc::results::haplotag_metrics->new(
    tag_index => 1,
    position  => 3,
    id_run    => 45159);
  isa_ok ($r, 'npg_qc::autoqc::results::haplotag_metrics');
  is($r->check_name(), 'haplotag metrics', 'check name');
  is($r->class_name(), 'haplotag_metrics', 'class name');

  my $r3;
  lives_ok {
    $r3 = npg_qc::autoqc::results::haplotag_metrics->load(
          't/data/autoqc/haplotag_metrics/45159_3#1.haplotag_metrics.json'
    );
  } 'Deserializing from JSON serialisation of haplotag result';

  cmp_ok($r3->clear_count, '==', 499, 'Clear count gives correct value');
  cmp_ok($r3->unclear_count, '==', 99, 'UnClear count gives correct value');
  cmp_ok($r3->missing_count, '==', 1, 'Missing count gives correct value');

};

1;

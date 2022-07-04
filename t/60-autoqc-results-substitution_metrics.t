use strict;
use warnings;
use Test::More tests => 2;
use Test::Exception;

use_ok ('npg_qc::autoqc::results::substitution_metrics');

subtest 'test attributes and simple methods' => sub {
  plan tests => 11;

  my $r = npg_qc::autoqc::results::substitution_metrics->new(
    tag_index => 1,
    position  => 3, 
    id_run    => 44918);
  isa_ok ($r, 'npg_qc::autoqc::results::substitution_metrics');
  is($r->check_name(), 'substitution metrics', 'check name');
  is($r->class_name(), 'substitution_metrics', 'class name');
  is($r->filename4serialization(), '44918_3#1.substitution_metrics.json',
    'default file name');
  is($r->subset, undef, 'subset field is not set');
    
  my $r2 = npg_qc::autoqc::results::substitution_metrics->new(
    tag_index => 1,
    position  => 3, 
    id_run    => 44918,
    subset    => 'yhuman');
  ok($r2->has_subset, 'subset attr is set');
  is($r2->check_name(), 'substitution metrics yhuman', 'check name has changed');
  is($r2->filename4serialization(), '44918_3#1_yhuman.substitution_metrics.json',
    'file name contains yhuman flag');

  my $r3;
  lives_ok {
    $r3 = npg_qc::autoqc::results::substitution_metrics->load(
          't/data/autoqc/substitution_metrics/44938_1#1.substitution_metrics.json'
    );
  } 'Deserializing from JSON serialisation of substitution result';

  cmp_ok($r3->ctoa_art_predicted_level, '==', 2, 'C2A artifact gives correct value');
  cmp_ok($r3->titv_mean_ca, '==', 2.77, 'TiTv mean CA gives correct value');

};

1;

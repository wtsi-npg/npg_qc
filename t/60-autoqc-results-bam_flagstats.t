use strict;
use warnings;
use Test::More tests => 2;
use Test::Exception;

use_ok ('npg_qc::autoqc::results::bam_flagstats');

subtest 'test attributes and simple methods' => sub {
  plan tests => 19;

  my $r = npg_qc::autoqc::results::bam_flagstats->new(
            position => 5,
            id_run   => 4783);
  isa_ok ($r, 'npg_qc::autoqc::results::bam_flagstats');
  is($r->check_name(), 'bam flagstats', 'correct check name');
  is($r->filename4serialization(), '4783_5.bam_flagstats.json',
      'default file name');
  is($r->human_split, undef, 'human_split field is not set');
  is($r->subset, undef, 'subset field is not set');
  $r->human_split('human');
  is($r->check_name(), 'bam flagstats', 'check name has not changed');
  ok(!$r->has_subset, 'subset attr is not set');
  $r->_set_subset('human');
  ok($r->has_subset, 'subset attr is set');
  is($r->check_name(), 'bam flagstats human', 'check name has changed');
  is($r->filename4serialization(), '4783_5_human.bam_flagstats.json',
      'file name contains "human" flag');

  $r = npg_qc::autoqc::results::bam_flagstats->new(
            position => 5,
            id_run   => 4783,
            human_split => 'phix');
  is ($r->subset, 'phix', 'subset attr is set correctly');
  my $json = $r->freeze();
  like ($json, qr/\"subset\":\"phix\"/, 'subset field is serialized');
  like ($json, qr/\"human_split\":\"phix\"/, 'human_split field is serialized');

  $r = npg_qc::autoqc::results::bam_flagstats->new(
            position => 5,
            id_run   => 4783,
            subset   => 'phix');
  is ($r->human_split, 'phix', 'human_split attr is set correctly');
  $json = $r->freeze();
  like ($json, qr/\"subset\":\"phix\"/, 'subset field is serialized');
  like ($json, qr/\"human_split\":\"phix\"/, 'human_split field is serialized');

  throws_ok { npg_qc::autoqc::results::bam_flagstats->new(
            position => 5,
            id_run   => 4783,
            subset   => 'phix',
            human_split => 'yhuman')
  } qr/human_split and subset attrs are different: yhuman and phix/,
    'error when human_split and subset attrs are different';

  lives_ok { npg_qc::autoqc::results::bam_flagstats->new(
            position => 5,
            id_run   => 4783,
            subset   => 'yhuman',
            human_split => 'yhuman')
  } 'no error when human_split and subset attrs are consistent';

  $r = npg_qc::autoqc::results::bam_flagstats->
    load('t/data/autoqc/bam_flagstats/4921_3_bam_flagstats.json');
  ok( !$r->total_reads(), 'total reads not available' ) ;
};

1;

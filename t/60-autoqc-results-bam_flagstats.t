use strict;
use warnings;
use Test::More tests => 2;

use_ok ('npg_qc::autoqc::results::bam_flagstats');

subtest 'test attributes and simple methods' => sub {
  plan tests => 12;

  my $r = npg_qc::autoqc::results::bam_flagstats->new(
            position => 5,
            id_run   => 4783);
  isa_ok ($r, 'npg_qc::autoqc::results::bam_flagstats');
  is($r->check_name(), 'bam flagstats', 'correct check name');
  is($r->filename4serialization(), '4783_5.bam_flagstats.json',
      'default file name');
  is($r->subset, undef, 'subset field is not set');

  $r = npg_qc::autoqc::results::bam_flagstats->new(
            position => 5,
            id_run   => 4783,
            subset   => 'human');
  ok($r->has_subset, 'subset attr is set');
  is($r->check_name(), 'bam flagstats human', 'check name has changed');
  is($r->filename4serialization(), '4783_5_human.bam_flagstats.json',
      'file name contains "human" flag');

  $r = npg_qc::autoqc::results::bam_flagstats->new(
            position => 5,
            id_run   => 4783,
            subset   => 'phix');
  like ($r->freeze(), qr/\"subset\":\"phix\"/, 'subset field is serialized');

  $r = npg_qc::autoqc::results::bam_flagstats->
    load('t/data/autoqc/bam_flagstats/4921_3_bam_flagstats.json');
  ok( !$r->total_reads(), 'total reads not available' ) ;
  ok( !$r->target_mapped_bases(), 'target mapped bases not available' ) ;

  $r = npg_qc::autoqc::results::bam_flagstats->new(       
            id_run    => 26074,
            position  => 1,
            tag_index => 13);
  is($r->subset, undef, 'subset field is not set');
 
  $r = npg_qc::autoqc::results::bam_flagstats->
    load('t/data/autoqc/bam_flagstats/26074_1#13.bam_flagstats.json');
  ok($r->target_mapped_bases(), 'target mapped bases available' ) ;

};

1;

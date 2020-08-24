use strict;
use warnings;
use File::Temp qw/tempdir/;
use Test::More tests => 4;
use Test::Exception;

use st::api::lims;

use_ok ('npg_qc::autoqc::checks::generic');

my $tdir = tempdir( CLEANUP => 1 );
local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
  q[t/data/autoqc/verify_bam_id/samplesheet_27483.csv];

subtest 'create check object, serialize result' => sub {
  plan tests => 6;

  my $g = npg_qc::autoqc::checks::generic->new(
    rpt_list => '27483:1:4', qc_out => $tdir);
  isa_ok ($g, 'npg_qc::autoqc::checks::generic');
  isa_ok ($g->result, 'npg_qc::autoqc::results::generic',
    'result attribute is built');
  isa_ok ($g->lims, 'st::api::lims', 'lims attribute is built');
  lives_ok { $g->execute() } 'no error running execute() method';
  lives_ok { $g->run() } 'no error running run() method';
  ok (-f "$tdir/27483_1#4.unknown.generic.json",
    'result serialized');
};

subtest 'sample info' => sub {
  plan tests => 15;

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
    q[t/data/autoqc/generic/samplesheet_34719.csv];
  my $g = npg_qc::autoqc::checks::generic->new(
    rpt_list => '34719:1:4', qc_out => $tdir);

  my $sh = $g->get_sample_info();
  is (keys %{$sh}, 2, 'two key-value pairs are returned');
  is ($sh->{supplier_sample_name}, 'YYYY-130D69', 'supplier sample name');
  is ($sh->{sample_type}, 'real_sample', 'sample type');

  my $lims = st::api::lims->new(rpt_list => '34719:1:4');
  $sh = $g->get_sample_info($lims);
  is (keys %{$sh}, 2, 'two key-value pairs are returned');
  is ($sh->{supplier_sample_name}, 'YYYY-130D69', 'supplier sample name');
  is ($sh->{sample_type}, 'real_sample', 'sample type');

  $lims = st::api::lims->new(rpt_list => '34719:1:6');
  $sh = $g->get_sample_info($lims);
  is (keys %{$sh}, 2, 'two key-value pairs are returned');
  is ($sh->{supplier_sample_name}, 'YYYY-130D78', 'supplier sample name');
  is ($sh->{sample_type}, 'real_sample', 'sample type');

  $lims = st::api::lims->new(rpt_list => '34719:1');
  $sh = $g->get_sample_info($lims);
  is (keys %{$sh}, 1, 'one key-value pair is returned');
  is ($sh->{sample_type}, 'real_sample', 'sample type');

  # control without type
  $lims = st::api::lims->new(rpt_list => '34719:1:257');
  throws_ok { $g->get_sample_info($lims) }
    qr/Control type is not set for a control sample \'Negative control\'/,
    'control type should be defined for a control sample';
  # not control with type
  $lims = st::api::lims->new(rpt_list => '34719:1:196');
  throws_ok { $g->get_sample_info($lims) }
    qr/Control type \'negative\' is set for a non-control sample \'Negative control\'/,
    'non-control sample cannot have control type defined';
  # negative
  $lims = st::api::lims->new(rpt_list => '34719:1:57');
  is_deeply ($g->get_sample_info($lims), {
      'supplier_sample_name' => 'Negative control',
      'sample_type' => 'negative_control'
    }, 'correct info for a negative control');
  # positive
  $lims = st::api::lims->new(rpt_list => '34719:1:194');
  is_deeply ($g->get_sample_info($lims), {
      'supplier_sample_name' => 'Positive control',
      'sample_type' => 'positive_control'
    }, 'correct info for a positive control');
};

subtest 'result object from file name' => sub {
  plan tests => 6;

  my $pkg = q(npg_qc::autoqc::checks::generic);

  my $g = $pkg->new(rpt_list => '27483:1:4', qc_out => $tdir);
  throws_ok { $g->file_name2result() }
    qr/File name argument should be given/,
    'no argument - error';
  throws_ok { $pkg->file_name2result() }
    qr/File name argument should be given/,
    'no argument - error';

  my $r = $g->file_name2result('34719_1#196.bam');
  isa_ok ($r, 'npg_qc::autoqc::results::generic');
  is ($r->composition->freeze2rpt, '34719:1:196', 'correct rpt');
  $r = $pkg->file_name2result('34719_1#196');
  isa_ok ($r, 'npg_qc::autoqc::results::generic');
  is ($r->composition->freeze2rpt, '34719:1:196', 'correct rpt');   
};

1;

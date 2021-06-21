use strict;
use warnings;
use File::Temp qw/tempdir/;
use Test::More tests => 6;
use Test::Exception;

use st::api::lims;
use npg_tracking::glossary::composition;
use npg_tracking::glossary::composition::component::illumina;

use_ok ('npg_qc::autoqc::checks::generic');
use_ok ('npg_qc::autoqc::results::generic');
 
my $tdir = tempdir( CLEANUP => 1 );
local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
  q[t/data/autoqc/verify_bam_id/samplesheet_27483.csv];

subtest 'create check object, serialize result' => sub {
  plan tests => 5;

  my $g = npg_qc::autoqc::checks::generic->new(
    rpt_list => '27483:1:4', qc_out => $tdir, pp_name => 'abc');
  isa_ok ($g, 'npg_qc::autoqc::checks::generic');
  is_deeply ($g->result, [], 'default result is empty');
  isa_ok ($g->lims, 'st::api::lims', 'lims attribute is built');
  lives_ok { $g->execute() } 'no error running execute() method';
  lives_ok { $g->run() } 'no error running run() method';
};

subtest 'sample info' => sub {
  plan tests => 15;

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
    q[t/data/autoqc/generic/samplesheet_34719.csv];
  my $g = npg_qc::autoqc::checks::generic->new(
    rpt_list => '34719:1:4', qc_out => $tdir, pp_name => 'abc');

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

  my $g = $pkg->new(
    rpt_list => '27483:1:4', qc_out => $tdir, pp_name => 'abc');
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

subtest 'set common result object attributes' => sub {
  plan tests => 3;

  my $c = npg_tracking::glossary::composition->new(
    components => [
    npg_tracking::glossary::composition::component::illumina->new(
      id_run => 3, position => 1, tag_index => 4)
  ]);

  my $url = 'https://github.com/google/it-cert-automation-practice';
  my $name = 'it-cert-automation-practice';
  my $check_version = $npg_qc::autoqc::results::generic::VERSION;
  my $result = npg_qc::autoqc::results::generic->new(composition  => $c);
  
  my $check = npg_qc::autoqc::checks::generic->new(
    rpt_list => '3:1:4',
    qc_out   => $tdir,
    pp_name  => $name,
    pp_repo_url   => $url,
  );
  $check->set_common_result_attrs($result);
  is ($result->pp_name, $name, 'pipeline name attribute is set');
  my $expected_info = {
    Pipeline_name      => $name,
    Pipeline_repo_url  => $url,
    Check              => 'npg_qc::autoqc::checks::generic',
    Check_version      => $check_version
  };
  is_deeply( $result->info(), $expected_info, 'info is set');

  $check = npg_qc::autoqc::checks::generic->new(
    rpt_list => '3:1:4',
    qc_out   => $tdir,
    pp_name  => $name,
    pp_version => '2.01',
    pp_repo_url   => $url,
  );
  $check->set_common_result_attrs($result, '3.5');
  $expected_info->{Pipeline_version} = '2.01 3.5';
  is_deeply( $result->info(), $expected_info, 'info is set');
};

1;

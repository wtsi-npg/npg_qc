use strict;
use warnings;
use Test::More tests => 2;

use npg_tracking::glossary::composition;
use npg_tracking::glossary::composition::component::illumina;

use_ok ('npg_qc::autoqc::results::generic');

subtest 'attributes and methods' => sub {
  plan tests => 18;

  my $c = npg_tracking::glossary::composition->new(components => [
    npg_tracking::glossary::composition::component::illumina->new(
      id_run => 3, position => 1, tag_index => 4)
  ]);

  my $r = npg_qc::autoqc::results::generic->new(
                  composition     => $c,
                  pp_name         => 'pp1',
                  pp_metrics_name => 'm1'
  );
  isa_ok ($r, 'npg_qc::autoqc::results::generic');
  is ($r->check_name(), 'generic', 'check name');
  is ($r->class_name(), 'generic', 'class name');
  is ($r->pp_name(), 'pp1', 'pp_name');
  is ($r->pp_metrics_name(), 'm1', 'pp_metrics_name');
  is ($r->pp_version(), undef, 'pp_version is undefined');
  is_deeply ($r->metrics(), {}, 'metrics is an empty hash by default');
  is_deeply ($r->supplimentary_info(), {}, 'supplimentary_info is an empty hash by default');
  is ($r->filename_root, '3_1#4.838be96c1332bd8bb9eb6622684d0bb3', 'file name root');

  $r = npg_qc::autoqc::results::generic->new(
                  composition     => $c,
                  pp_name         => 'pp1',
                  pp_version      => 'v0.4.0',
                  pp_metrics_name => 'm1',
                  metrics => {qc_pass => 'TRUE', num_aligned_reads => 3},
                  supplimentary_info => {sample_type => 'negative_control'}
  );
  isa_ok ($r, 'npg_qc::autoqc::results::generic');
  is ($r->check_name(), 'generic', 'check name');
  is ($r->class_name(), 'generic', 'class name');
  is ($r->pp_name(), 'pp1', 'pp_name');
  is ($r->pp_metrics_name(), 'm1', 'pp_metrics_name');
  is ($r->pp_version(), 'v0.4.0', 'pp_version');
  is_deeply ($r->metrics(), {qc_pass => 'TRUE', num_aligned_reads => 3},
    'metrics hash');
  is_deeply ($r->supplimentary_info(), {sample_type => 'negative_control'},
    'supplimentary_info hash');
  is ($r->filename_root, '3_1#4.c9aba72e3dc4262ceefa8bc749a2823b', 'file name root');
};

1;

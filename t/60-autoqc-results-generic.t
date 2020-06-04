use strict;
use warnings;
use Test::More tests => 2;

use npg_tracking::glossary::composition;
use npg_tracking::glossary::composition::component::illumina;

use_ok ('npg_qc::autoqc::results::generic');

subtest 'attributes and methods' => sub {
  plan tests => 12;

  my $c = npg_tracking::glossary::composition->new(components => [
    npg_tracking::glossary::composition::component::illumina->new(
      id_run => 3, position => 1, tag_index => 4)
  ]);

  my $r = npg_qc::autoqc::results::generic->new(
              composition  => $c
  );
  isa_ok ($r, 'npg_qc::autoqc::results::generic');
  is ($r->check_name(), 'generic', 'check name');
  is ($r->class_name(), 'generic', 'class name');
  is ($r->desc(), undef, 'descriptor is undefined');
  is ($r->doc(), undef, 'doc is undefined');
  is ($r->filename_root, '3_1#4.unknown', 'file name root');

  $r = npg_qc::autoqc::results::generic->new(
              composition => $c,
              desc        => 'pp1',
              doc         => {qc_pass => 'TRUE', num_aligned_reads => 3},
  );
  isa_ok ($r, 'npg_qc::autoqc::results::generic');
  is ($r->check_name(), 'generic', 'check name');
  is ($r->class_name(), 'generic', 'class name');
  is ($r->desc(), 'pp1', 'descriptor');
  is_deeply ($r->doc(), {qc_pass => 'TRUE', num_aligned_reads => 3},
    'metrics hash');
  is ($r->filename_root, '3_1#4.pp1', 'file name root');
};

1;

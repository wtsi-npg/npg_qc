use strict;
use warnings;
use Test::More tests => 2;
use Test::Exception;

use npg_tracking::glossary::composition;
use npg_tracking::glossary::composition::component::illumina;

use_ok ('npg_qc::autoqc::results::cscreen');

subtest 'attributes and methods' => sub {
  plan tests => 4;

  my $c = npg_tracking::glossary::composition->new(components => [
    npg_tracking::glossary::composition::component::illumina->new(
      id_run => 3, position => 1, tag_index => 4)
  ]);

  my $r = npg_qc::autoqc::results::cscreen->new(composition => $c);
  isa_ok ($r, 'npg_qc::autoqc::results::cscreen');
  is ($r->filename_root, '3_1#4', 'file name root');
  is ($r->class_name, 'cscreen', 'class name');
  is ($r->check_name, 'cscreen', 'check name');
};

1;

use strict;
use warnings;
use Test::More tests => 2;
use Test::Exception;

use_ok('npg_qc::autoqc::checks::interop');

subtest 'result object properties' => sub {
  plan tests => 12;

  my $i = npg_qc::autoqc::checks::interop->new(qc_in => 't', rpt_list => '34:1;34:2;34:3');
  isa_ok ($i, 'npg_qc::autoqc::checks::interop');
  is (ref $i->result, 'ARRAY', 'result is an array');
  is (scalar @{$i->result}, 3, 'three result objects');
  my $position = 1;
  for my $r (@{$i->result}) {
    isa_ok ($r, 'npg_qc::autoqc::results::interop');
    is ($r->composition->freeze2rpt, join(q[:], 34, $position),
      'composition object is for a single lane');
    is ($r->filename4serialization, q[34_] . $position . q[.interop.json],
      'file name for serialisation');
    $position++;
  }
};

1;
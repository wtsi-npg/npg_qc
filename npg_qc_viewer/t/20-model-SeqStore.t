use strict;
use warnings;
use Test::More tests => 2;

{ use_ok 'npg_qc_viewer::Model::SeqStore' }


{
  isa_ok(npg_qc_viewer::Model::SeqStore->new(), 'npg_qc_viewer::Model::SeqStore');
}


1;

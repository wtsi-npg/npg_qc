use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;

use_ok ('npg_qc::autoqc::results::rna_seqc');

{
    my $r = npg_qc::autoqc::results::rna_seqc->new(id_run => 12, position => 3, path => q[mypath]);
    isa_ok ($r, 'npg_qc::autoqc::results::rna_seqc');
    is($r->check_name(), 'rna seqc', 'check name');
    is($r->class_name(), 'rna_seqc', 'class name');
}

1;
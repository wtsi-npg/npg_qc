#########
# Author:        mg8
# Created:       2 May 2012
#

use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;

use_ok ('npg_qc::autoqc::results::pulldown_metrics');

{
    my $r = npg_qc::autoqc::results::pulldown_metrics->new(id_run => 12, position => 3, path => q[mypath]);
    isa_ok ($r, 'npg_qc::autoqc::results::pulldown_metrics');
    is($r->check_name(), 'pulldown metrics', 'check name');
    is($r->class_name(), 'pulldown_metrics', 'class name');
}

1;
#########
# Author:        mg8
# Maintainer:    $Author$
# Created:       2 May 2012
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;

our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/mx; $r; };

use_ok ('npg_qc::autoqc::results::pulldown_metrics');

{
    my $r = npg_qc::autoqc::results::pulldown_metrics->new(id_run => 12, position => 3, path => q[mypath]);
    isa_ok ($r, 'npg_qc::autoqc::results::pulldown_metrics');
    is($r->check_name(), 'pulldown metrics', 'check name');
    is($r->class_name(), 'pulldown_metrics', 'class name');
}

1;
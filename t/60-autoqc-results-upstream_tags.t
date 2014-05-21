#########
# Author:        kl2
# Maintainer:    $Author$
# Created:       6 September 2013
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;

use_ok ('npg_qc::autoqc::results::upstream_tags');
use_ok ('npg_qc::autoqc::results::collection');

{
    my $r = npg_qc::autoqc::results::upstream_tags->new(id_run => 2, path => q[mypath], position => 1);
    isa_ok ($r, 'npg_qc::autoqc::results::upstream_tags');
}

{
    my $c=npg_qc::autoqc::results::collection->new();
    $c->add_from_dir(q[t/data/autoqc/upstream_tags], [1], 9669);
    $c=$c->slice('class_name', 'upstream_tags');

    is($c->results->[0]->criterion(), q[Currently no pass/fail levels set], 'criteria');
}


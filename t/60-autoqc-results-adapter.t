#########
# Author:        jo3
# Maintainer:    $Author$
# Created:       30 July 2009
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

use strict;
use warnings;
use Test::More tests => 10;
use Test::Deep;
use English qw(-no_match_vars);
use Carp;

use_ok('npg_qc::autoqc::results::adapter');

{
    my $r = npg_qc::autoqc::results::adapter
                ->new(id_run => 12, position => 3, path => q[mypath]);
    isa_ok ($r, 'npg_qc::autoqc::results::adapter');
    is($r->check_name(), 'adapter', 'check name');
    is($r->class_name(), 'adapter', 'class name');
}


{
    my $r = npg_qc::autoqc::results::adapter
                ->new(id_run => 12, position => 3, path => q[mypath]);
    $r->reverse_fasta_read_count(23);
    $r->forward_fasta_read_count(24);
    $r->reverse_contaminated_read_count(3);
    $r->forward_contaminated_read_count(4);
    is ($r->forward_percent_contam_reads(), '16.67',
        'forward read persent of contam reads');
    is ($r->reverse_percent_contam_reads(), '13.04',
        'reverse read persent of contam reads');
}


{
    my $r = npg_qc::autoqc::results::adapter
                ->new(id_run => 12, position => 3, path => q[mypath]);
   
    ok (!$r->forward_percent_contam_reads(), 'forward read persent undefined');
    ok (!$r->reverse_percent_contam_reads(), 'reverse read persent undefined');

    $r->forward_fasta_read_count(0);
    $r->forward_contaminated_read_count(4);
    ok (!$r->forward_percent_contam_reads(), 'forward read persent undefined if total count is zero');

    $r->reverse_fasta_read_count(0);
    $r->reverse_contaminated_read_count(4);
    ok (!$r->forward_percent_contam_reads(), 'reverse read persent undefined if total count is zero');
}

1;

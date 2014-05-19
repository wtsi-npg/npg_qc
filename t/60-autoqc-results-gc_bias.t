#########
# Author:        jo3
# Created:       30 July 2009
#

use strict;
use warnings;
use Test::More 'no_plan';
use Test::Deep;
use Test::Exception;
use English qw(-no_match_vars);
use Carp;

use_ok('npg_qc::autoqc::results::gc_bias');

my $r = npg_qc::autoqc::results::gc_bias->new( id_run   => 12,
                                               position => 3,
                                               path     => q[mypath] );

isa_ok ( $r, 'npg_qc::autoqc::results::gc_bias' );
is( $r->check_name(), 'gc bias', 'Check name' );
is( $r->class_name(), 'gc_bias', 'Class name' );

1;

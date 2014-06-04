#########
# Author:        mg8
# Created:       04 January 2010
#

use strict;
use warnings;
use Test::More tests => 11;
use Test::Exception;
use Carp;

use_ok ('npg_qc::autoqc::results::gc_fraction');

{
    my $r = npg_qc::autoqc::results::gc_fraction->new(id_run => 2, path => q[mypath], position => 1);
    isa_ok ($r, 'npg_qc::autoqc::results::gc_fraction');
}


{
    my $r = npg_qc::autoqc::results::gc_fraction->new(
                                                position  => 1,
                                                path      => 't/data/autoqc/090721_IL29_2549/data',
                                                id_run    => 2549,
                                                threshold_difference => 20,
                                                  );
    is($r->check_name(), 'gc fraction', 'check name');
    is($r->class_name(), 'gc_fraction', 'class name');
    is($r->criterion, q[The difference between actual and expected GC percent is less than 20], 'criterion string');
}

{
    my $json = 't/data/autoqc/4453_2#0.gc_fraction.json';
    my $r;
    lives_ok {$r = npg_qc::autoqc::results::gc_fraction->load($json)} 'loaded json for no-file error';
    is($r->pass, undef, 'pass is undef');
    is($r->ref_gc_percent, undef, 'ref_gc_percent is undef');
    is($r->forward_read_gc_percent, undef, 'forward_read_gc_percent is undef');
    is($r->reverse_read_gc_percent, undef, 'reverse_read_gc_percent is undef');
    is($r->criterion, q[], 'threshold difference is an empty string');
}

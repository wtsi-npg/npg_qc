use strict;
use warnings;
use Test::More tests => 2;
use Test::Exception;

use_ok ('npg_qc::autoqc::results::mapd');

subtest 'Loading check' => sub {
    plan tests => 4;
    my $r = npg_qc::autoqc::results::mapd->new(id_run => 27128, position => 1, tag_index => 1, path => q[mypath]);
    isa_ok ($r, 'npg_qc::autoqc::results::mapd');
    is($r->check_name(), 'mapd', 'check name');
    is($r->class_name(), 'mapd', 'class name');
    is ($r->filename4serialization(), '27128_1#1.mapd.json', 'default file name');
};

#subtest 'Testing utility methods' => sub {
#  plan tests => 2;
#  my $r;
#  lives_ok {$r = npg_qc::autoqc::results::mapd->load('t/data/autoqc/rna_seqc/data/15911_1#1.rna_seqc.json');} 'load serialised empty result';
#  lives_ok {$r = npg_qc::autoqc::results::mapd->load('t/data/autoqc/rna_seqc/data/18407_1#7.rna_seqc.json');} 'load serialised valid result';
#};


1;
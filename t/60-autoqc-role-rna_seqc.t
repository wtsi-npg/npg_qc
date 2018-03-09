use strict;
use warnings;
use Test::More tests => 2;
use Test::Exception;

use_ok('npg_qc::autoqc::role::rna_seqc');

subtest 'Testing role methods' => sub {
    plan tests => 5;
    my ($r, $om_value);
    use_ok ('npg_qc::autoqc::results::rna_seqc');
    lives_ok {$r = npg_qc::autoqc::results::rna_seqc->load('t/data/autoqc/rna_seqc/data/18407_1#7.rna_seqc.json');} 'load serialised valid result';
    lives_ok {$om_value = $r->other_metrics();} 'extract other metrics';
    is_deeply($r->transcripts_detected(), $om_value->{'Transcripts Detected'}, 'value extracted using role method');
    is_deeply($r->intronic_rate(), $om_value->{'Intronic Rate'}, 'value extracted using role method');
};

1;

use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;

use_ok ('npg_qc::autoqc::results::rna_seqc');

subtest 'Loading check' => sub {
    plan tests => 4;
    my $r = npg_qc::autoqc::results::rna_seqc->new(id_run => 18407, position => 1, tag_index => 7, path => q[mypath]);
    isa_ok ($r, 'npg_qc::autoqc::results::rna_seqc');
    is($r->check_name(), 'rna seqc', 'check name');
    is($r->class_name(), 'rna_seqc', 'class name');
    is ($r->filename4serialization(), '18407_1#7.rna_seqc.json', 'default file name');
};

subtest 'Testing utility methods' => sub {
  plan tests => 2;
  my $r;
  lives_ok {$r = npg_qc::autoqc::results::rna_seqc->load('t/data/autoqc/rna_seqc/data/15911_1#1.rna_seqc.json');} 'load serialised empty result';
  lives_ok {$r = npg_qc::autoqc::results::rna_seqc->load('t/data/autoqc/rna_seqc/data/18407_1#7.rna_seqc.json');} 'load serialised valid result';
};

subtest 'Testing attribute calls' => sub {
  plan tests => 2;
  my $r;
  lives_ok {$r = npg_qc::autoqc::results::rna_seqc->load('t/data/autoqc/rna_seqc/data/26855_1#9.rna_seqc.json');} 'load serialised valid result';
  is($r->rna_seqc_report_path, undef, "rna_seqc report path undefined as expected");
};

1;
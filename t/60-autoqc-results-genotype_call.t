use strict;
use warnings;
use Test::More tests => 5;
use Test::Exception;


use_ok ('npg_qc::autoqc::results::genotype_call');
use_ok ('npg_qc::autoqc::results::collection');


subtest q[Object type] => sub {
    plan tests => 4;
    my $r = npg_qc::autoqc::results::genotype_call->new(id_run => 24135, position => 1, tag_index => 1, path => q[mypath]);
    isa_ok ($r, 'npg_qc::autoqc::results::genotype_call');
    is($r->check_name(), 'genotype call', 'check name');
    is($r->class_name(), 'genotype_call', 'class name');
    is ($r->filename4serialization(), '24135_1#1.genotype_call.json', 'default file name');
};


subtest q[Criterion from info] => sub {
	plan tests => 3;
  my $r_from_json;
  my $json_path = q[t/data/autoqc/genotype_call/data/24135_1#1.genotype_call.json];
  lives_ok{ $r_from_json = npg_qc::autoqc::results::genotype_call->load($json_path); }
            q[Loaded from json];
  isa_ok ( $r_from_json, 'npg_qc::autoqc::results::genotype_call' );
  is( $r_from_json->criterion, q[Genotype passed rate >= 0.7], q[Criterion from json] );
};


subtest q[Collection] => sub {
  plan tests => 1;
  my $c=npg_qc::autoqc::results::collection->new();
  $c->add_from_dir(q[t/data/autoqc/genotype_call/data], [1], 24135);                             
  $c=$c->slice('class_name', 'genotype_call');
  is($c->results->[0]->criterion(), q[Genotype passed rate >= 0.7], q[Criterion returned] );
};

1;

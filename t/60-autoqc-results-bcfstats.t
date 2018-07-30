use strict;
use warnings;
use Test::More tests => 5;
use Test::Exception;


use_ok ('npg_qc::autoqc::results::bcfstats');
use_ok ('npg_qc::autoqc::results::collection');


subtest q[Object type] => sub {
    plan tests => 4;
    my $r = npg_qc::autoqc::results::bcfstats->new(id_run => 21835, position => 1, tag_index => 1, path => q[mypath]);
    isa_ok ($r, 'npg_qc::autoqc::results::bcfstats');
    is($r->check_name(), 'bcfstats', 'check name');
    is($r->class_name(), 'bcfstats', 'class name');
    is ($r->filename4serialization(), '21835_1#1.bcfstats.json', 'default file name');
};

subtest q[JSON] => sub {
	plan tests => 5;
  my $r_from_json;
  my $json_path = q[t/data/autoqc/bcfstats/data/21835_5.bcfstats.json];
  lives_ok{ $r_from_json = npg_qc::autoqc::results::bcfstats->load($json_path); }
            q[Loaded from json];
  isa_ok ( $r_from_json, 'npg_qc::autoqc::results::bcfstats' );
  is( $r_from_json->criterion, q[NRD % < 2], q[Criterion from json] );
  is( $r_from_json->genotypes_passed, q[74], q[Genotypes passed returned] );
  is( $r_from_json->percent_condordance, q[100.00], q[Percent concordance returned] );
};

subtest q[Collection] => sub {
  plan tests => 3;
  my $c=npg_qc::autoqc::results::collection->new();
  $c->add_from_dir(q[t/data/autoqc/bcfstats/data], [5], 21835);                             
  $c=$c->slice('class_name', 'bcfstats');
  is($c->results->[0]->criterion, q[NRD % < 2], q[Criterion returned] );
  is($c->results->[0]->genotypes_passed, q[74], q[Genotypes passed returned] );
  is($c->results->[0]->percent_condordance, q[100.00], q[Percent concordance returned] );
};

1;

use strict;
use warnings;
use Test::More tests => 6;
use Test::Exception;
use Moose::Meta::Class;
use JSON;

use npg_testing::db;
use t::autoqc_util;

use_ok('npg_qc::Schema::Result::TagDecodeStats');

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema]);

my $json = q { 
{"info":{},"errors_good":{"1":"1505","0":"275562","no_match":"2078"},"distribution_good":{"6":"23457","11":"25566","3":"29903","7":"17","9":"27002","2":"31480","12":"86","8":"28186","4":"29251","1":"25715","10":"28255","5":"28149"},"position":8,"distribution_all":{"6":"26355","11":"28326","3":"33464","7":"20","9":"30205","2":"35221","12":"97","8":"31821","4":"32824","1":"29259","10":"31898","5":"31491"},"id_run":4360,"errors_all":{"1":"6627","0":"304354","no_match":"7512"},"tag_code":{"6":"GCCAAT","11":"GGCTAC","3":"TTAGGC","7":"CAGATC","9":"GATCAG","2":"CGATGT","12":"CTTGTA","8":"ACTTGA","4":"TGACCA","1":"ATCACG","10":"TAGCTT","5":"ACAGTG"}}
};

my $values = from_json($json);
$values->{'id_seq_composition'} =
  t::autoqc_util::find_or_save_composition($schema,
    {id_run => 4360, position => 8});
my $rs = $schema->resultset('TagDecodeStats');
isa_ok($rs->new_result($values), 'npg_qc::Schema::Result::TagDecodeStats');
{
  my %values1 = %{$values};
  my $v1 = \%values1;
  lives_ok {$rs->find_or_new($v1)->set_inflated_columns($v1)->update_or_insert()} 'record inserted';
  my $rs1 = $rs->search({});
  is ($rs1->count, 1, q[one row created in the table]);
  my $row = $rs1->next;
  is(ref $row->tag_code, 'HASH', 'tag_code returned as hash ref');
  is_deeply($row->tag_code, $values->{'tag_code'},
    'tag_code hash content is correct'); 
}

1;

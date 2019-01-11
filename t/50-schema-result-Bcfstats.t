use strict;
use warnings;
use Test::More tests => 3;
use Test::Exception;
use Perl6::Slurp;
use JSON;

use npg_testing::db;
use t::autoqc_util;

use_ok('npg_qc::Schema::Result::Bcfstats');


my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema]);
my $archive = q[t/data/autoqc/bcfstats/data];
my $rs = $schema->resultset('Bcfstats');
my $rc = $rs->result_class;

sub _get_data {
  my $file_name = shift;
  my $json = slurp join(q[/], $archive, $file_name);
  my $values = from_json($json);
  foreach my $key (keys %{$values}) {
    if (!$rc->has_column($key)) {
      delete $values->{$key};
    }
  }
  return $values;
}


subtest 'result with criterion in json' => sub {
  plan tests => 5;

  my $values = _get_data('21835_5.bcfstats.json');
  $values->{'id_seq_composition'} =
    t::autoqc_util::find_or_save_composition($schema,
    {id_run => 21835, position => 5});
  my %values1 = %{$values};
  my $v1 = \%values1;

  $rs->deflate_unique_key_components($v1);
  lives_ok {$rs->find_or_new($v1)->set_inflated_columns($v1)->update_or_insert()}
    'Check record inserted';
  my $rs1 = $rs->search({});
  is($rs1->count, 1, q[one row created in the table]);
  my $row = $rs1->next;
  is(ref $row->info, 'HASH', 'info returned as hash ref');
  is_deeply($row->info, $values->{'info'}, 'info hash content is correct');
  is($row->criterion, q[NRD % < 2],
    q[Correct criterion for checks with criterion in json]);
  $rs1->delete_all;
};

subtest 'load results with a composition fk' => sub {
  plan tests => 4;

  my $values =  _get_data('21835_5.bcfstats.json');
  my $fk_row = $schema->resultset('SeqComposition')->create({digest => '21835', size => 1});

  my $object = $rs->new_result($values);
  isa_ok($object, 'npg_qc::Schema::Result::Bcfstats');
  throws_ok {$object->insert()}
    qr/NOT NULL constraint failed: bcfstats.id_seq_composition/,
    'foreign key referencing the composition table absent - error';

  $object->id_seq_composition($fk_row->id_seq_composition);
  lives_ok { $object->insert() } 'insert with fk is ok';
  my $a_rs = $rs->search({});
  is ($a_rs->count, 1, q[one row created in the table]);
  $a_rs->delete_all;
};


1;

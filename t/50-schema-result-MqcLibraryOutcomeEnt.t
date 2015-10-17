use strict;
use warnings;
use Test::More tests => 2;
use Test::Exception;
use Moose::Meta::Class;
use npg_testing::db;
use DateTime;

my $table = 'MqcLibraryOutcomeEnt';

#Test model mapping
use_ok('npg_qc::Schema::Result::' . $table);

my $schema = Moose::Meta::Class->create_anon_class(
           roles => [qw/npg_testing::db/])
           ->new_object({})->create_test_db(q[npg_qc::Schema], 't/data/fixtures');

#Test insert
subtest 'Test insert' => sub {
  plan tests => 6;

  my $values = {
    'id_run'         => 1, 
    'position'       => 1,
    'tag_index'      => 1,
    'id_mqc_outcome' => 0, 
    'username'       => 'user', 
    'last_modified'  => DateTime->now(),
    'modified_by'    => 'user'};
    
  my $object = $schema->resultset($table)->create($values);
  isa_ok($object, 'npg_qc::Schema::Result::' . $table);

  my $rs = $schema->resultset($table)->search({});
  is ($rs->count, 1, q[one row created in the table]);
  $object = $rs->next;
  is($object->tag_index, 1, 'tag_index is 1');
  
  delete $values->{'tag_index'};
  $object = $schema->resultset($table)->create($values);
  isa_ok($object, 'npg_qc::Schema::Result::' . $table);

  $rs = $schema->resultset($table)->search({});
  is ($rs->count, 2, q[Two rows in the table]);
  $rs = $schema->resultset($table)->search({'id_run' => 1, 'position' => 1, 'tag_index' => -1});
  is ($rs->count, 1, q[One row in table with undef tag_index as -1]);
  #TODO add extra search to be sure I can get something inserted with !defined tag_index.
};

1;
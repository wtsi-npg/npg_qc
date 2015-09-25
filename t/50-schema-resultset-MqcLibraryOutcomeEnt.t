use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;
use Moose::Meta::Class;
use npg_testing::db;
use DateTime;

my $table = 'MqcLibraryOutcomeEnt';

#Test model mapping
use_ok('npg_qc::Schema::ResultSet::' . $table);
use_ok('npg_qc::Schema::Result::' . $table);

my $schema = Moose::Meta::Class->create_anon_class(
           roles => [qw/npg_testing::db/])
           ->new_object({})->create_test_db(q[npg_qc::Schema], 't/data/fixtures');

subtest q[search library outcome ent] => sub {
  plan tests => 5;
  
  my $id_run   = 1;
  my $position = 2;
  my $tag_index = 1;
  my $username = q[user];
  
  my $resultset = $schema->resultset($table);
  my $rs = $resultset->search({'id_run' => $id_run, 'position' => $position}); 
  is($rs->count, 0, q[No outcomes in table for run]);
  
  my $ent = $resultset->search_library_outcome_ent($id_run, $position, $tag_index, $username);
  ok(!$ent->in_storage, q[Entity not in storage]);
  is($rs->count, 0, q[One entity created but not in database]);
  $ent->update_outcome('Undecided', $username);
  ok($ent->in_storage, q[Entity in storage]);
  is($rs->count, 1, q[One entity in database]);
};

subtest q[get outcomes as hash] => sub {
  plan tests => 5;

  my $id_run   = 2;
  my $position = 2;

  my $values = {
    'id_run'         => $id_run, 
    'position'       => $position,
    'tag_index'      => 1,
    'id_mqc_outcome' => 0, 
    'username'       => 'user', 
    'last_modified'  => DateTime->now(),
    'modified_by'    => 'user'
  };

  my $resultset = $schema->resultset($table);
  my $object = $resultset->create($values);
  isa_ok($object, 'npg_qc::Schema::Result::' . $table);
  $object->update_outcome('Undecided', 'user');
  my $rs = $resultset->search({'id_run' => $id_run});
  is($rs->count, 1, q[one row created in the table]);
  my $outcome_hash = $resultset->get_outcomes_as_hash($id_run, $position);
  cmp_ok($outcome_hash->{'1'}, q[eq], q[Undecided], q[Resulting hash contains correct value for tag_index 1]);

  $values->{'tag_index'} = 2;
  $values->{'id_mqc_outcome'} = 1;

  my $object2 = $resultset->create($values);
  $outcome_hash = $resultset->get_outcomes_as_hash($id_run, $position);
  cmp_ok($outcome_hash->{'1'}, q[eq], q[Undecided], q[Resulting hash contains correct value for tag_index 1]);
  cmp_ok($outcome_hash->{'2'}, q[eq], q[Accepted preliminary], q[Resulting hash contains correct value for tag_index 2]);
};

1;
use strict;
use warnings;
use Test::More tests => 5;
use Test::Exception;
use Moose::Meta::Class;
use npg_testing::db;
use DateTime;

my $table = 'MqcLibraryOutcomeEnt';
my $hist_table = 'MqcLibraryOutcomeHist';

#Test model mapping
use_ok('npg_qc::Schema::Result::' . $table);

my $schema = Moose::Meta::Class->create_anon_class(
           roles => [qw/npg_testing::db/])
           ->new_object({})->create_test_db(q[npg_qc::Schema], 't/data/fixtures');

#Test insert
subtest 'Test insert' => sub {
  plan tests => 9;

  my $values = {
    'id_run'         => 1,
    'position'       => 1,
    'tag_index'      => 1,
    'id_mqc_outcome' => 2,
    'username'       => 'user',
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
  $values = {
    'id_run'         => 2,
    'position'       => 10,
    'id_mqc_outcome' => 2,
    'username'       => 'user',
    'modified_by'    => 'user'
  };
  $rs = $schema->resultset($table);
  $rs->result_class->deflate_unique_key_components($values);
  is($values->{'tag_index'}, -1, 'tag index deflated');
  lives_ok {$rs->find_or_new($values)
               ->set_inflated_columns($values)
               ->update_or_insert()} 'lane record inserted';
  my $rs1 = $rs->search({'id_run' => 2});
  is ($rs1->count, 1, q[one row created in the table]);
  my $row = $rs1->next;
  is($row->tag_index, undef, 'tag index inflated');

  my $temp = $rs->search({'id_run' => 2})->next;
};

subtest 'Test insert with historic defined' => sub {
  plan tests => 4;
  my $values = {
    'id_run'         => 10,
    'position'       => 1,
    'id_mqc_outcome' => 1,
    'tag_index'      => 100,
    'username'       => 'user',
    'modified_by'    => 'user'
  };

  my $hist_object_rs = $schema->resultset($hist_table)->search({
    'id_run'=>10,
    'position'=>1,
    'tag_index'=>100,
    'id_mqc_outcome'=>1
  });
  is ($hist_object_rs->count, 0, q[no row matches in the historic table before insert in entity]);

  my $object = $schema->resultset($table)->create($values);
  isa_ok($object, 'npg_qc::Schema::Result::'.$table);

  my $rs = $schema->resultset($table)->search({
    'id_run'=>10,
    'position'=>1,
    'tag_index'=>100,
    'id_mqc_outcome'=>1
  });
  is ($rs->count, 1, q[one row created in the entity table]);

  $hist_object_rs = $schema->resultset($hist_table)->search({'id_run'=>10,
    'position'=>1,
    'tag_index'=>100,
    'id_mqc_outcome'=>1
  });
  is ($hist_object_rs->count, 1, q[one row matches in the historic table after insert in entity]);
};

subtest 'Test insert with historic' => sub {
  plan tests => 6;
  my $values = {
    'id_run'         => 20,
    'position'       => 3,
    'id_mqc_outcome' => 1,
    'username'       => 'user',
    'modified_by'    => 'user'
  };

  my $values_for_search = {};
  $values_for_search->{'id_run'}         = 20;
  $values_for_search->{'position'}       = 3;
  $values_for_search->{'tag_index'}      = undef;
  $values_for_search->{'id_mqc_outcome'} = 1;

  my $rs = $schema->resultset($table);
  $rs->result_class->deflate_unique_key_components($values_for_search);

  my $hist_object_rs = $schema->resultset($hist_table)->search($values_for_search);
  is ($hist_object_rs->count, 0, q[no row matches in the historic table before insert in entity]);

  my $object = $schema->resultset($table)->create($values);
  isa_ok($object, 'npg_qc::Schema::Result::'.$table);

  $rs = $schema->resultset($table)->search({'id_run'=>20, 'position'=>3, 'id_mqc_outcome'=>1});
  is ($rs->count, 1, q[one row created in the entity table]);

  $hist_object_rs = $schema->resultset($hist_table)->search($values_for_search);
  is ($hist_object_rs->count, 1, q[one row matches in the historic table after insert in entity]);
  is ($object->tag_index, undef, q[tag_index inflated in entity]);
  is ($hist_object_rs->next->tag_index, undef, q[tag_index inflated in historic]);
};

subtest 'Update to final' => sub {
  plan tests => 9;

  my $values = {
    'id_run'         => 300,
    'position'       => 1,
    'tag_index'      => 1,
    'id_mqc_outcome' => 1, #Accepted pre
    'username'       => 'user',
    'modified_by'    => 'user'
  };
  
  my $username = 'someusername';
  
  my $object = $schema->resultset($table)->create($values);
  ok ( $object->is_accepted && !$object->has_final_outcome,
         'Entity has accepted not final.');
  ok ( $object->update_to_final_outcome($username), 'Can update as final outcome' );
  ok ( $object->is_accepted && $object->has_final_outcome,
         'Entity has accepted final.');
  
  $values->{'tag_index'} = 2;
  $values->{'id_mqc_outcome'} = 2; #Rejected pre
  $object = $schema->resultset($table)->create($values);
    ok ( $object->is_rejected && !$object->has_final_outcome,
         'Entity has rejected not final.');
  ok ( $object->update_to_final_outcome($username), 'Can update as final outcome' );
  ok ( $object->is_rejected && $object->has_final_outcome, 
         'Entity has rejected final.');
  
  $values->{'tag_index'} = 3;
  $values->{'id_mqc_outcome'} = 5; #Undecided
  $object = $schema->resultset($table)->create($values);
  ok ( $object->is_undecided,
         'Entity has undecided.');
  ok ( $object->update_to_final_outcome($username), 'Can update as final outcome' );
  ok ( $object->is_undecided && $object->has_final_outcome, 
         'Entity has undecided final.');
};

1;


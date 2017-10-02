use strict;
use warnings;
use Test::More tests => 9;
use Test::Exception;
use Moose::Meta::Class;
use npg_testing::db;
use DateTime;
use t::autoqc_util;

use_ok('npg_qc::Schema::Result::UqcOutcomeEnt');

my $schema = Moose::Meta::Class->create_anon_class(
     roles => [qw/npg_testing::db/])
     ->new_object({})->create_test_db(q[npg_qc::Schema], 't/data/fixtures');

my $table      = 'UqcOutcomeEnt';
my $hist_table = 'UqcOutcomeHist';
my $dict_table = 'UqcOutcomeDict';

subtest 'Test insert' => sub {
  plan tests => 8;

  my $values = {
    'id_uqc_outcome'=>1,
    'username'=>'user',
    'last_modified'=>DateTime->now(),
    'modified_by'=>'user',
    'rationale'=>'rationale something'
  };
  my $id_seq_comp = t::autoqc_util::find_or_save_composition($schema, {
        id_run => 9001, position => 1, tag_index => 1
  });
  $values->{'id_seq_composition'} = $id_seq_comp;
  isa_ok($schema->resultset($table)->create($values),
    'npg_qc::Schema::Result::' . $table);

  my $rs = $schema->resultset($table)->search({});
  is ($rs->count, 1, q[one row created in the table]);
  my $object = $rs->next;
  is($object->id_uqc_outcome, 1, 'id_uqc_outcome is 1');

  $id_seq_comp = t::autoqc_util::find_or_save_composition($schema, {
        id_run => 9001, position => 1
  });
  $values->{'id_seq_composition'} = $id_seq_comp;
  isa_ok($schema->resultset($table)->create($values),
    'npg_qc::Schema::Result::' . $table);
  $rs = $schema->resultset($table)->search({});
  is ($rs->count, 2, q[Two rows in the table]);


  $values = {
    'id_uqc_outcome'=>2,
    'username'=>'user',
    'last_modified'=>DateTime->now(),
    'modified_by'=>'user',
    'rationale'=>'rationale something'
  };
  my $query = {id_run => 9002, position => 2};
  $id_seq_comp = t::autoqc_util::find_or_save_composition($schema, $query);
  $values->{'id_seq_composition'} = $id_seq_comp;
  $rs->deflate_unique_key_components($values);
  lives_ok {$rs->find_or_new($values)
               ->set_inflated_columns($values)
               ->update_or_insert()} 'lane record inserted';
   my $rs1 = $rs->search($query, {
                    prefetch => [{
                    seq_composition =>
                    {seq_component_compositions => 'seq_component'}
                    }, 'uqc_outcome']});
   is ($rs1->count, 1, q[one row created in the table]);
   my $row = $rs1->next;
   is($row->seq_composition->seq_component_compositions->next->seq_component->tag_index, undef, 'tag index inflated');
};

subtest 'Test insert with historic defined' => sub {
  plan tests => 4;

  my $values = {
    'id_uqc_outcome'=>1,
    'username'=>'user',
    'last_modified'=>DateTime->now(),
    'modified_by'=>'user',
    'rationale'=>'rationale something'
  };
  my $id_seq_comp = t::autoqc_util::find_or_save_composition($schema, {id_run => 9010, position => 1, tag_index => 100});
  $values->{'id_seq_composition'} = $id_seq_comp;
  my $hist_object_rs = $schema->resultset($hist_table)->search({
    'id_seq_composition'=>$id_seq_comp,
    'id_uqc_outcome'=>1
  });
  is ($hist_object_rs->count, 0, q[no row matches in the historic table before insert in entity]);
  my $object = $schema->resultset($table)->create($values);
  isa_ok($object, 'npg_qc::Schema::Result::'.$table);
  my $rs = $schema->resultset($table)->search({
    id_seq_composition=>$id_seq_comp,
    id_uqc_outcome=>1
  });
  is ($rs->count, 1, q[one row created in the entity table]);
  $hist_object_rs = $schema->resultset($hist_table)->search({
    id_seq_composition=>$id_seq_comp,
    id_uqc_outcome=>1
  });
  is ($hist_object_rs->count, 1, q[one row matches in the historic table after insert in entity]);
};


subtest 'insert with historic' => sub {
  plan tests => 6;

  my $values = {
    'id_uqc_outcome'=>1,
    'username'=>'user',
    'last_modified'=>DateTime->now(),
    'modified_by'=>'user',
    'rationale'=>'rationale something'
  };
  my $id_seq_comp = t::autoqc_util::find_or_save_composition($schema, {
        id_run => 9020, position => 3
  });
  $values->{'id_seq_composition'} = $id_seq_comp;

  my $values_for_search = {};
  $values_for_search->{'id_run'}         = 9020;
  $values_for_search->{'position'}       = 3;
  $values_for_search->{'tag_index'}      = undef;
  $values_for_search->{'me.id_uqc_outcome'} = 1;
  my $rs = $schema->resultset($table);
  $rs->deflate_unique_key_components($values_for_search);
  is ($schema->resultset($hist_table)->search($values_for_search, {
                    prefetch => [{
                    seq_composition =>{seq_component_compositions => 'seq_component'}},
                    'uqc_outcome']})->count, 0,
                    q[no row matches in the historic table before insert in entity]);

  my $object = $schema->resultset($table)->create($values);
  isa_ok ($object, 'npg_qc::Schema::Result::'.$table);
  is ($object->seq_composition->seq_component_compositions->next->seq_component->tag_index,
   undef, q[tag_index inflated in entity]);

  $rs = $schema->resultset($table)->search({'id_seq_composition'=>$id_seq_comp, 'id_uqc_outcome'=>1});
  is ($rs->count, 1, q[one row created in the entity table]);

  my $hist_object_rs = $schema->resultset($hist_table)->search($values_for_search, {
                    prefetch => [{
                    seq_composition =>{seq_component_compositions => 'seq_component'}},
                    'uqc_outcome']});
  is ($hist_object_rs->count, 1,
    q[one row matches in the historic table after insert in entity]);
  is ($hist_object_rs->next->
      seq_composition->
      seq_component_compositions->next->
      seq_component->tag_index,
   undef, q[tag_index inflated in historic]);
};

subtest q[update] => sub {
  plan tests => 14;

  my $rs = $schema->resultset($table);
  my $hrs = $schema->resultset($hist_table);
  my $args = {
    'id_uqc_outcome'=>1,
    'username'=>'user',
    'last_modified'=>DateTime->now(),
    'modified_by'=>'user',
    'rationale'=>'rationale something'
  };
  my $id_seq_comp = t::autoqc_util::find_or_save_composition($schema, {
        id_run => 9444, position => 1, tag_index => 2
  });
  $args->{'id_seq_composition'} = $id_seq_comp;

  my $new_row = $rs->new_result($args);
  my $outcome = 'Rejected';
  lives_ok { $new_row->update_outcome($outcome, 'cat','cat', 'rationale other') }
    'uqc outcome saved';
  ok ($new_row->in_storage, 'new object has been saved');

  my $hist_rs = $hrs->search({'id_seq_composition'=>$id_seq_comp, 'id_uqc_outcome'=>2});
  is ($hist_rs->count, 1, 'one historic is created');
  my $hist_new_row = $hist_rs->next();

  isa_ok ($new_row->last_modified, 'DateTime');
  ok ($new_row->is_rejected, 'is rejected');
  ok (!$new_row->is_final_accepted, 'not final accepted');

  for my $row (($new_row, $hist_new_row)) {
    is ($row->uqc_outcome->short_desc(), $outcome, 'correct prelim. outcome');
    is ($row->username, 'cat', 'username');
    is ($row->modified_by, 'cat', 'modified_by');
    ok ($row->last_modified, 'timestamp is set');
  }
};


subtest 'Basic operations tests' => sub {
  plan tests => 20;
  is ($schema->resultset($table)->search({}), 6,
    q[starting with 4 exiting rows in the table]);
  my $values = {
    'id_uqc_outcome'=>1,
    'username'=>'user',
    'last_modified'=>DateTime->now(),
    'modified_by'=>'user',
    'rationale'=>'rationale something'
  };
  $values->{'id_seq_composition'} = t::autoqc_util::find_or_save_composition($schema, {
        id_run => 9225, position => 1
  });
  isa_ok($schema->resultset($table)->create($values),
    'npg_qc::Schema::Result::UqcOutcomeEnt');
  is ($schema->resultset($table)->search({}), 7,
    q[one row created in the table]);
  $values = {
    'id_uqc_outcome'=>2
  };
  $values->{'id_seq_composition'} = t::autoqc_util::find_or_save_composition($schema, {
        id_run => 9225, position => 2
  });
  my %values1 = %{$values};
  $values1{'username'} = 'user2';
  $values1{'modified_by'} = 'user2';
  $values1{'last_modified'}=DateTime->now();
  $values1{'rationale'}='rationale something';
  is ($schema->resultset($hist_table)->search($values)->count, 0,
    q[no historic entry for entity about to be inserted]);
  isa_ok($schema->resultset($table)->create(\%values1),
    'npg_qc::Schema::Result::UqcOutcomeEnt');
  is ($schema->resultset($table)->search($values), 1,
    q[one row created in the entity table]);
  is ($schema->resultset($hist_table)->search($values)->count, 1,
    q[one matching row created in the entity table]);

  my $temp_id_seq_comp=t::autoqc_util::find_or_save_composition($schema, {
        id_run => 9225, position => 3
  });
  $values = {'id_seq_composition'=> $temp_id_seq_comp,
      'id_uqc_outcome'=>0,
      'username'=>'user3',
      'last_modified'=>DateTime->now(),
      'modified_by'=>'user3',
      'rationale'=>'rationale something'
  };

  isa_ok($schema->resultset($table)->create($values),
    'npg_qc::Schema::Result::UqcOutcomeEnt');
  is ($schema->resultset($table)->search({'id_seq_composition'=>$temp_id_seq_comp})
     ->count, 1, q[one row matches in the table]);
  $temp_id_seq_comp=t::autoqc_util::find_or_save_composition($schema, {
    id_run => 9225, position => 4
  });
  $values = {'id_seq_composition'=> $temp_id_seq_comp,
    'id_uqc_outcome'=>0,
    'username'=>'user4',
    'last_modified'=>DateTime->now(),
    'modified_by'=>'user4',
    'rationale'=>'rationale something'
  };
  $schema->resultset($table)->create($values);
  $schema->resultset($table)->find({'id_seq_composition'=>$temp_id_seq_comp})
    ->update({'id_uqc_outcome'=>2});
  my $rs = $schema->resultset($table)->search({'id_seq_composition'=>$temp_id_seq_comp});
  is ($rs->count, 1, q[one row matches in the entity table after update]);
  my $ent = $rs->next;
  is($ent->id_uqc_outcome, 2, 'correct outcome id');
  is($ent->username, $ent->modified_by, 'Username equals modified_by');

  $temp_id_seq_comp=t::autoqc_util::find_or_save_composition($schema, {
    id_run => 9220, position => 1
  });
  $values = {'id_seq_composition'=> $temp_id_seq_comp,
    'id_uqc_outcome' => 3,
    'username'       => 'user5',
    'last_modified'  => DateTime->now(),
    'modified_by'    => 'user5',
    'rationale'=>'rationale something'
  };

  my $object = $schema->resultset($table)->create($values);
  isa_ok($object, 'npg_qc::Schema::Result::UqcOutcomeEnt');
  ok(!$object->has_final_outcome(),
    q[has_final_outcome() returns false on newly created uqc entity]);
  $rs = $schema->resultset($table)->search({'id_seq_composition'=> $temp_id_seq_comp,
    'id_uqc_outcome'=>3});
  is ($rs->count, 1, q[one row created in the table]);
  $object = $rs->next();
  is($object->id_uqc_outcome, 3, q[The outcome scalar is there and has correct value]);
  ok(defined $object->uqc_outcome, q[The outcome is defined when searching.]);

  $temp_id_seq_comp=t::autoqc_util::find_or_save_composition($schema, {
    id_run => 9100, position => 4
  });
  $values = {'id_seq_composition'=> $temp_id_seq_comp,
    'id_uqc_outcome' => 1,
    'username'       => 'user6',
    'last_modified'  => DateTime->now(),
    'modified_by'    => 'user6',
    'rationale'=>'rationale something'
  };

  my $query = {'id_seq_composition'=> $temp_id_seq_comp,
    'id_uqc_outcome'=>3
  };

  is ($schema->resultset($hist_table)->search($query)->count, 0,
    q[no row matches in the historic table before update in entity]);
  $schema->resultset($table)->create($values);
  $schema->resultset($table)->find({'id_seq_composition'=> $temp_id_seq_comp})
    ->update({'id_uqc_outcome'=>3});
  is ($schema->resultset($table)->search($query)->count, 1,
    q[one row matches in the entity table after update]);
  is ($schema->resultset($hist_table)->search($query)->count, 1,
    q[one row matches in the historic table after update in entity]);
};

subtest 'Misc tests' => sub {
  plan tests => 18;
  my $temp_id_seq_comp=t::autoqc_util::find_or_save_composition($schema, {
    id_run => 9210, position => 5
  });
  my $values = {'id_seq_composition'=> $temp_id_seq_comp,
    'id_uqc_outcome' => 1,
    'username'       => 'user7',
    'last_modified'  => DateTime->now(),
    'modified_by'    => 'randomuser',
    'rationale'=>'rationale something'
  };
  isa_ok($schema->resultset($table)->create($values),
    'npg_qc::Schema::Result::UqcOutcomeEnt');
  my $rs = $schema->resultset($table)->search({
    'id_seq_composition'=> $temp_id_seq_comp,
    'id_uqc_outcome'=>1
  });
  is ($rs->count, 1, q[one row created in the table]);
  my $object = $rs->next();
  is($object->id_uqc_outcome, 1, q[The outcome id is Accepted -correct-]);
  ok(defined $object->uqc_outcome, q[The outcome is defined when searching.]);
  ok(!$object->has_final_outcome, q[The outcome is not final]);
  is($object->username, 'user7', q[username is set correctly]);
  is($object->modified_by, 'randomuser', q[modified_by is set correctly]);

  $object->update_outcome('Rejected', 'new_user', 'RT#356789', 'rationale something');
  my $row = $schema->resultset($table)
    ->search({'id_seq_composition'=> $temp_id_seq_comp})->next;
  ok($row->is_rejected, q[The outcome is Rejected]);
  ok(!$row->has_final_outcome, q[has_final_outcome() returns negative]);
  is($row->username, 'RT#356789', q[username is reset]);
  is($row->modified_by, 'new_user', q[modified_by is reset]);
  is ($row->seq_composition->seq_component_compositions->next->seq_component->id_run, 9210,
    q[DBIX relationship connects id_seq_composition with id_run]);
  is ($row->seq_composition->seq_component_compositions->next->seq_component->position, 5,
    q[DBIX relationship connects id_seq_composition with position]);

  throws_ok {$object->update_outcome('some invalid', 'user')}
    qr/Outcome some invalid is invalid/,
    'error updating to an invalid string outcome';
  throws_ok {$object->update_outcome(123, 'user')}
    qr/Outcome 123 is invalid/,
    'error updating to invalid integer status';
  throws_ok {$object->update_outcome('Rejected final')}
    qr/User name required/,
    'username should be given';
  throws_ok {$object->update_outcome(undef, 'user')}
    qr/Outcome required/,
     'outcome should be given';
  throws_ok {$object->update_outcome('Accepted', 'cat', 'RT#1000')}
    qr/Rationale is required/,
     'fails when rationale is not provided';
};

subtest 'Data for historic' => sub {
  plan tests => 12;

  my $temp_id_seq_comp=t::autoqc_util::find_or_save_composition($schema, {
    id_run => 9001, position => 3
  });
  my $values = {'id_seq_composition'=> $temp_id_seq_comp,
    'id_uqc_outcome' => 1,
    'username'       => 'user01',
    'modified_by'    => 'user01',
  };

  my $entity = $schema->resultset($table)->new_result($values);
  my $historic = $entity->data_for_historic;
  is($entity->id_seq_composition, $historic->{'id_seq_composition'}, 'Id_seq_composition matches');
  is($entity->id_uqc_outcome, $historic->{'id_uqc_outcome'}, 'Id uqc outcome matches');
  is($entity->username, $historic->{'username'}, 'Username matches');
  is($entity->modified_by, $historic->{'modified_by'}, 'Modified by matches');
  is($entity->last_modified, $historic->{'last_modified'}, 'Last modified matches');

  $values->{'last_reported'} = DateTime->now();
  $entity = $schema->resultset($table)->new_result($values);
  $historic = $entity->data_for_historic;
  is($entity->id_seq_composition, $historic->{'id_seq_composition'}, 'id_seq_composition matches');
  is($entity->id_uqc_outcome, $historic->{'id_uqc_outcome'}, 'Id uqc outcome matches');
  is($entity->username, $historic->{'username'}, 'Username matches');
  is($entity->modified_by, $historic->{'modified_by'}, 'Modified by matches');
  is($entity->last_modified, $historic->{'last_modified'}, 'Last modified matches');
  ok($entity->last_reported, 'There is value for last_reported in entity');
  ok(!defined $historic->{'reported'}, 'There is no value for reported in historic');
};

subtest q[update on a new result] => sub {
  plan tests => 29;

  my $rs = $schema->resultset($table);
  my $hrs = $schema->resultset($hist_table);
  my $temp_id_seq_comp=t::autoqc_util::find_or_save_composition($schema, {
    id_run => 9444, position => 1
  });
  my $args = {
    'id_seq_composition'=> $temp_id_seq_comp
  };
  my $new_row = $rs->new_result($args);
  my $outcome = 'Accepted';
  $new_row->rationale('user reason for change 8');
  lives_ok { $new_row->update_outcome(
    $outcome,
    'cat',
    'cat',
    'rationale something') } 'accepted outcome saved';
  ok ($new_row->in_storage, 'new object has been saved');

  my $hist_rs = $hrs->search($args);
  is ($hist_rs->count, 1, 'one historic is created');
  my $hist_new_row = $hist_rs->next();

  isa_ok ($new_row->last_modified, 'DateTime');
  ok ($new_row->is_accepted, 'is acepted');

  for my $row (($new_row, $hist_new_row)) {
     is ($row->uqc_outcome->short_desc(), $outcome, 'correct outcome');
     is ($row->username, 'cat', 'username');
     is ($row->modified_by, 'cat', 'modified_by');
     ok ($row->last_modified, 'timestamp is set');
  }

  $outcome = 'Rejected';

  $new_row = $rs->new_result($args);
  throws_ok { $new_row->update_outcome($outcome, 'dog', 'cat','rationale something') }
    qr /UNIQUE constraint failed/,
    'error creating a record for existing entity';
  my $another_id_seq_comp=t::autoqc_util::find_or_save_composition($schema, {
    id_run => 9444, position => 2
  });
  $args->{'id_seq_composition'} = $another_id_seq_comp;
  $new_row = $rs->new_result($args);
  $new_row->update_outcome($outcome, 'dog', 'cat','rationale something');

  $hist_rs = $hrs->search($args);
  is ($hist_rs->count, 1, 'one historic is created');
  $hist_new_row = $hist_rs->next();

  my $new_row_via_search = $rs->search($args)->next;
  isa_ok ($new_row->last_modified, 'DateTime');
  ok ($new_row->is_rejected, 'is rejected');

  for my $row (($new_row, $new_row_via_search, $hist_new_row)) {
    is ($row->uqc_outcome->short_desc(), $outcome, 'correct outcome');
    is ($row->username, 'cat', 'username');
    is ($row->modified_by, 'dog', 'modified_by');
    ok ($row->last_modified, 'timestamp is set');
  }
  $new_row->delete();
};

1;

use strict;
use warnings;
use Test::More tests => 6;
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
  plan tests => 9;

  my $id_run   = 1;
  my $position = 2;
  my $tag_index = 1;
  my $username = q[user];

  my $resultset = $schema->resultset($table);
  my $rs = $resultset->search({
    'id_run' => $id_run,
    'position' => $position
  }); 
  is($rs->count, 0, q[No outcomes in table for run]);

  my $ent = $resultset->search_library_outcome_ent($id_run, $position, $tag_index, $username);
  ok(!$ent->in_storage, q[Entity not in storage]);
  is($rs->count, 0, q[One entity created but not in database]);
  $ent->update_outcome('Undecided', $username);
  ok($ent->in_storage, q[Entity in storage]);
  is($rs->count, 1, q[One entity in database]);

  $id_run = 1;
  $position = 3;
  $tag_index = undef;
  my $rs2 = $resultset->search({
    'id_run' => $id_run,
    'position' => $position
  }); 
  $ent = $resultset->search_library_outcome_ent($id_run, $position, $tag_index, $username);
  ok(!$ent->in_storage, q[Entity not in storage]);
  is($rs2->count, 0, q[One entity created but not in database]);
  $ent->update_outcome('Undecided', $username);
  ok($ent->in_storage, q[Entity in storage]);
  is($rs2->count, 1, q[Two entities in database]);
};

subtest q[get outcomes as hash] => sub {
  plan tests => 16;

  my $id_run   = 2;
  my $position = 2;

  my $values = {
    'id_run'         => $id_run, 
    'position'       => $position,
    'tag_index'      => 1,
    'id_mqc_outcome' => 2, #Rejected preliminary
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

  $values = {
    'id_run'         => 200, 
    'position'       => 20,
    'id_mqc_outcome' => 1, 
    'username'       => 'user', 
    'last_modified'  => DateTime->now(),
    'modified_by'    => 'user'
  };
  $rs = $schema->resultset($table);
  $rs->result_class->deflate_unique_key_components($values);
  is($values->{'tag_index'}, -1, 'tag index deflated');
  lives_ok {$rs->find_or_new($values)->set_inflated_columns($values)->update_or_insert()} 'entity record inserted';
  my $rs1 = $rs->search({'id_run' => 200});
  is ($rs1->count, 1, q[one row created in the table]);
  my $row = $rs1->next;
  is($row->tag_index, undef, 'tag index inflated');

  my $temp = $rs->search({'id_run' => 200})->next;
  is($temp->id_run, 200, 'Correct id_run');
  is($temp->position, 20, 'Correct position');
  is($temp->tag_index, undef, 'Correct tag_index (undef)');
  
  $values->{'tag_index'} = 1;
  $values->{'id_mqc_outcome'} = 2;
  lives_ok {$rs->find_or_new($values)->set_inflated_columns($values)->update_or_insert()} 'entity record inserted';
  $outcome_hash = $resultset->get_outcomes_as_hash(200, 20);
  is(scalar keys %{$outcome_hash}, 2, 'Correct number of keys');
  is($outcome_hash->{''}, 'Accepted preliminary', q[Correct outcome for tag_index undef]);
  is($outcome_hash->{'1'}, 'Rejected preliminary', q[Correct outcome for tag_index 1]);
};

subtest q[batch update libraries] => sub {
  plan tests => 9;

  my $id_run   = 400;
  my $position = 2;
  my $username = q[user];

  my $values_lane = {
    'id_run'         => $id_run,
    'position'       => $position,
    'id_mqc_outcome' => 1, #Accepted preeliminary
    'username'       =>$username, 
    'last_modified'  =>DateTime->now(),
    'modified_by'    =>$username};
    
  my $object_lane = $schema->resultset(q[MqcOutcomeEnt])->create($values_lane);
  isa_ok($object_lane, 'npg_qc::Schema::Result::MqcOutcomeEnt');

  my $values_plex = {
    'id_run'         => $id_run, 
    'position'       => $position,
    'username'       => $username, 
    'last_modified'  => DateTime->now(),
    'modified_by'    => $username
  };
  
  my $rs = $schema->resultset($table);

  $values_plex->{'tag_index'}      = 10;
  $values_plex->{'id_mqc_outcome'} = 1; #Accepted preeliminary
  my $object_plex = $rs->create($values_plex);
  ok($object_plex->in_storage, q[New plex in database]);

  $values_plex->{'tag_index'}      = 20;
  $values_plex->{'id_mqc_outcome'} = 2; #Rejected preeliminary
  $object_plex = $rs->create($values_plex);
  ok($object_plex->in_storage, q[New plex in database]);

  $values_plex->{'tag_index'}      = 30;
  $values_plex->{'id_mqc_outcome'} = 5; #Undecided
  $object_plex = $rs->create($values_plex);
  ok($object_plex->in_storage, q[New plex in database]);

  my $tag_indexes_lims = [undef, 10, 20, 30, 40];
  
  $rs->batch_update_libraries($object_lane, $tag_indexes_lims, $username);

  my $values_search = {
    'id_run' => $id_run, 
    'position' => $position,
  };

  my $changed_entities_rs = $rs->search($values_search);

  my $new_desc = $changed_entities_rs->search({'tag_index' => 10})->first->mqc_outcome->short_desc;
  is($new_desc, 'Accepted final', 'Updated to Accepted final');
  $new_desc = $changed_entities_rs->search({'tag_index' => 20})->first->mqc_outcome->short_desc;
  is($new_desc, 'Rejected final', 'Updated to Rejected final');
  $new_desc = $changed_entities_rs->search({'tag_index' => 30})->first->mqc_outcome->short_desc;
  is($new_desc, 'Undecided final', 'Updated to Undecided final');
  $new_desc = $changed_entities_rs->search({'tag_index' => 40})->first->mqc_outcome->short_desc;
  is($new_desc, 'Undecided final', 'Updated to Undecided final');
  #Tag_index undef
  $values_search->{'tag_index'} = undef;
  $rs->result_class->deflate_unique_key_components($values_search);
  $new_desc = $changed_entities_rs->search($values_search)->first->mqc_outcome->short_desc;
  is($new_desc, 'Undecided final', 'Updated to Undecided final for tag_index undef');
};

subtest q[batch update libraries errors] => sub {
  plan tests => 6;
  
  my $id_run   = 500;
  my $position = 1;
  my $username = q[user];

  my $values_lane = {
    'id_run'         => $id_run,
    'position'       => $position,
    'id_mqc_outcome' => 1, #Accepted preeliminary
    'username'       =>$username, 
    'last_modified'  =>DateTime->now(),
    'modified_by'    =>$username};
    
  my $object_lane = $schema->resultset(q[MqcOutcomeEnt])->create($values_lane);
  isa_ok($object_lane, 'npg_qc::Schema::Result::MqcOutcomeEnt');

  my $values_plex = {
    'id_run'         => $id_run, 
    'position'       => $position,
    'tag_index'      => 100,
    'id_mqc_outcome' => 4, #Rejected final
    'username'       => $username, 
    'last_modified'  => DateTime->now(),
    'modified_by'    => $username
  };
  
  my $rs = $schema->resultset($table);
  
  my $object = $rs->create($values_plex);
  
  my $values_search = {
    'id_run'    => $id_run, 
    'position'  => $position,
    'tag_index' => 100,
  };

  my $tag_indexes_lims = [100];

  my $entities_rs = $rs->search($values_search);
  is($entities_rs->count, 1, 'One plex in database with previous outcome');
  throws_ok {$rs->batch_update_libraries($object_lane, $tag_indexes_lims, $username);}
    qr/Unexpected plex libray qc final outcome was found for id_run 500 position 1 outcome Rejected final./,
    'Throws exception when trying to update something final';
    
  my $rs_dict = $schema->resultset('MqcLibraryOutcomeDict');
  my $values_dict = {};
  $values_dict->{'short_desc'} = 'Waiting';
  $values_dict->{'long_desc'}  = 'A new outcome';
  $values_dict->{'iscurrent'}  = 1;
  $values_dict->{'isvisible'}  = 1;
  my $dict_obj = $rs_dict->create($values_dict);
  is($rs_dict->search({})->count, 7, 'New unknown dictinary value');
  $object->update({ 'id_mqc_outcome' => $dict_obj->id_mqc_library_outcome });
  my $entities_rs = $rs->search($values_search);
  is($entities_rs->count, 1, 'One plex in database with previous outcome');
  throws_ok {$rs->batch_update_libraries($object_lane, $tag_indexes_lims, $username);}
    qr/Unable to update unexpected outcome to final for id_run 500 position 1 outcome Waiting./,
    'Throws exception when trying to transit from unknown outcome';
};

1;



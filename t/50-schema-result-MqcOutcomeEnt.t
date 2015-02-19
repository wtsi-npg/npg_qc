use strict;
use warnings;
use Test::More tests => 42;
use Test::Exception;
use Moose::Meta::Class;
use npg_testing::db;
use DateTime;

#Test model mapping
use_ok('npg_qc::Schema::Result::MqcOutcomeEnt');

my $schema = Moose::Meta::Class->create_anon_class(
           roles => [qw/npg_testing::db/])
           ->new_object({})->create_test_db(q[npg_qc::Schema], 't/data/fixtures', ':memory:');

my $table = 'MqcOutcomeEnt';
my $hist_table = 'MqcOutcomeHist';
my $dict_table = 'MqcOutcomeDict';

#Test insert
{
  my $values = {'id_run'=>1, 
    'position'=>1,
    'id_mqc_outcome'=>0, 
    'username'=>'user', 
    'last_modified'=>DateTime->now()};
    
  my $object = $schema->resultset($table)->create($values);
  isa_ok($object, 'npg_qc::Schema::Result::MqcOutcomeEnt');

  my $rs = $schema->resultset($table)->search({});
  is ($rs->count, 1, q[one row created in the table]);
}

#Test insert with historic
{
  my $values = {'id_run'=>10, 
    'position'=>1,
    'id_mqc_outcome'=>1, 
    'username'=>'user', 
    'last_modified'=>DateTime->now()};

  my $hist_object_rs = $schema->resultset($hist_table)->search({'id_run'=>10, 'position'=>1, 'id_mqc_outcome'=>1}); #Search historic that matches latest change
  is ($hist_object_rs->count, 0, q[no row matches in the historic table before insert in entity]);

  my $object = $schema->resultset($table)->create($values);
  isa_ok($object, 'npg_qc::Schema::Result::MqcOutcomeEnt');

  my $rs = $schema->resultset($table)->search({'id_run'=>10, 'position'=>1, 'id_mqc_outcome'=>1});
  is ($rs->count, 1, q[one row created in the entity table]);
  
  $hist_object_rs = $schema->resultset($hist_table)->search({'id_run'=>10, 'position'=>1, 'id_mqc_outcome'=>1}); #Search historic that matches latest change
  is ($hist_object_rs->count, 1, q[one row matches in the historic table after insert in entity]);
}

{ 
  my $all = $schema->resultset($table)->get_ready_to_report();
  is($all->count, 0, q[There are no entities ready to report]);
}

#Test select
{
  my $values = {'id_run'=>1, 
      'position'=>2,
      'id_mqc_outcome'=>0, 
      'username'=>'user', 
      'last_modified'=>DateTime->now()};

  my $object = $schema->resultset($table)->create($values);
  isa_ok($object, 'npg_qc::Schema::Result::MqcOutcomeEnt');

  my $rs = $schema->resultset($table)->search({'id_run'=>1, 'position'=>2});
  is ($rs->count, 1, q[one row matches in the table]);  
}

#Test update
{
  my $values = {'id_run'=>1, 
    'position'=>3,
    'id_mqc_outcome'=>0, 
    'username'=>'user', 
    'last_modified'=>DateTime->now()};

  my $object = $schema->resultset($table)->create($values); #Insert new entity
  my $rs = $schema->resultset($table);
  $rs->find({'id_run'=>1, 'position'=>3})->update({'id_mqc_outcome'=>2}); #Find and update the outcome in the new outcome
  $rs = $schema->resultset($table)->search({'id_run'=>1, 'position'=>3, 'id_mqc_outcome'=>2}); #Search the new outcome
  is ($rs->count, 1, q[one row matches in the entity table after update]);
}

#Test update with historic
{
  my $values = {'id_run'=>100, 
    'position'=>4,
    'id_mqc_outcome'=>0, 
    'username'=>'user', 
    'last_modified'=>DateTime->now()};

  #There should not be a previous historic
  my $hist_object_rs = $schema->resultset($hist_table)->search({'id_run'=>100, 'position'=>4, 'id_mqc_outcome'=>3}); #Search historic that matches latest change
  is ($hist_object_rs->count, 0, q[no row matches in the historic table before update in entity]);

  my $object = $schema->resultset($table)->create($values); #Insert new entity
  my $rs = $schema->resultset($table);
  $rs->find({'id_run'=>100, 'position'=>4})->update({'id_mqc_outcome'=>3}); #Find and update the outcome in the new outcome
  $rs = $schema->resultset($table)->search({'id_run'=>100, 'position'=>4, 'id_mqc_outcome'=>3}); #Search the new outcome
  is ($rs->count, 1, q[one row matches in the entity table after update]);
  
  #The historic should be generated automatically and saved
  $hist_object_rs = $schema->resultset($hist_table)->search({'id_run'=>100, 'position'=>4, 'id_mqc_outcome'=>3}); #Search historic that matches latest change
  is ($hist_object_rs->count, 1, q[one row matches in the historic table after update in entity]);
  
  #Test there is one record ready to be reported (final outcome and null reported)
  my $all = $schema->resultset($table)->get_ready_to_report();
  is($all->count, 1, q[There is one entity ready to be reported]);
  
  #Test the entity has accepted outcome
  ok($rs->next->is_accepted, q[The outcome is considered accepted.]);
}

#Test update (create) status of new entity and store
{ 
  my $id_run = 110; 
  my $position = 1;
  my $status = 1;
  my $username = 'username';
  
  my $values = {'id_run' => $id_run, 'position' => $position};
  
  my $object = $schema->resultset($table)->find_or_new($values);
  $object->last_modified(DateTime->now());
  my $in = $object->in_storage; #Row status from database
  if($in) { #Entity exists
    my $outcome_dict = $schema->resultset($dict_table)->find($object->id_mqc_outcome);
    if($outcome_dict->is_final_outcome) {
      print("Problem trying to update final outcome");
    } else {
      $object->update({'id_mqc_outcome' => $status});      
    }
  } else {
    $object->id_mqc_outcome($status);
    $object->insert();
  }
  my $rs = $schema->resultset($table)->search({'id_run'=>110, 'position'=>1, 'id_mqc_outcome'=>1});
  is ($rs->count, 1, q[one row matches in the entity table after outcome update]);
}

#Test update (existing) status of entity and store
{
  ##### Setting up the entity and checking fk with dictionary
  my $values = {'id_run'=>210,
    'position'       => 1,
    'id_mqc_outcome' => 1,
    'username'       => 'user', 
    'last_modified'  => DateTime->now()};

  my $object = $schema->resultset($table)->create($values);
  isa_ok($object, 'npg_qc::Schema::Result::MqcOutcomeEnt');
  
  my $outcome_dict = $schema->resultset($dict_table)->find(1);
  ok(defined $outcome_dict, q[The dictionary is defined for outcome]);
  is($outcome_dict->id_mqc_outcome, 1, q[The dictionary object has correct value for key]);

  my $rs = $schema->resultset($table)->search({'id_run'=>210, 'position'=>1, 'id_mqc_outcome'=>1});
  is ($rs->count, 1, q[one row created in the table]);
  $object = $rs->next();
  is($object->id_mqc_outcome, 1, q[The outcome scalar is there and has correct value]);
  ok(defined $object->mqc_outcome, q[The outcome is defined when searching.]);
  ok(!$object->has_final_outcome, q[The outcome before update is not final]);
  
  ##### Running the test
  my $id_run = 210;
  my $position = 1;
  my $status = 'Rejected final';
  my $username = 'randomuser';
  
  $values = {'id_run' => $id_run, 'position' => $position};
  
  $object = $schema->resultset($table)->find_or_new($values);
  $object->update_outcome($status, $username);
  
  $rs = $schema->resultset($table)->search({'id_run'=>210, 'position'=>1, 'id_mqc_outcome'=>4});
  is ($rs->count, 1, q[One row matches in the entity table after outcome update]);
  
  #Test the entity has a non accepted outcome
  ok(!$rs->next->is_accepted, q[The outcome is not considered accepted.]);

  throws_ok {$object->update_outcome('some invalid', $username)}
    qr/Error while trying to transit id_run 210 position 1 to a non-existing outcome \"some invalid\"/,
    'error updating to invalid string status';
  throws_ok {$object->update_outcome(123, $username)}
    qr/Error while trying to transit id_run 210 position 1 to a non-existing outcome \"123\"/,
    'error updating to invalid integer status';
  throws_ok {$object->update_outcome($status, 789)}
    qr/Have a number 789 instead as username/, 'username can be an integer';
  throws_ok {$object->update_outcome($status)}
    qr/Mandatory parameter 'username' missing in call/,
    'username should be given';
  throws_ok {$object->update_outcome()}
    qr/Mandatory parameter 'outcome' missing in call/,
    'outcome should be given';
}

#Test update existing status of entity and store
{
  ##### Setting up the entity and checking fk with dictionary
  my $values = {'id_run'=>220, 
    'position'       => 1,
    'id_mqc_outcome' => 3, 
    'username'       => 'user', 
    'last_modified'  => DateTime->now()};

  my $object = $schema->resultset($table)->create($values);
  isa_ok($object, 'npg_qc::Schema::Result::MqcOutcomeEnt');
  ok($object->has_final_outcome(), q[The newly created entity has a final outcome]);
  
  my $outcome_dict = $schema->resultset($dict_table)->find(3);
  ok(defined $outcome_dict, q[The dictionary is defined for outcome]);
  is($outcome_dict->id_mqc_outcome, 3, q[The dictionary object has correct value for key]);
  
  my $rs = $schema->resultset($table)->search({'id_run'=>220, 'position'=>1, 'id_mqc_outcome'=>3});
  is ($rs->count, 1, q[one row created in the table]);
  $object = $rs->next();
  is($object->id_mqc_outcome, 3, q[The outcome scalar is there and has correct value]);
  ok(defined $object->mqc_outcome, q[The outcome is defined when searching.]);
  
  ##### Running the test
  my $id_run = 220;
  my $position = 1;
  my $status = 4;
  my $username = 'randomuser';
  
  $values = {'id_run' => $id_run, 'position' => $position};
  
  $object = $schema->resultset($table)->find_or_new($values);
  my $in = $object->in_storage; #Row status from database
  throws_ok { $object->update_outcome($status, $username) } qr/update a final outcome/, 'Invalid outcome transition croak';
  
  $rs = $schema->resultset($table)->search({'id_run'=>220, 'position'=>1, 'id_mqc_outcome'=>3});
  is ($rs->count, 1, q[One row matches in the entity table because there was no update]);
}

{
  my $rs = $schema->resultset($table)->get_ready_to_report();
  is ($rs->count, 3, q[3 entities ready to be reported]);
  
  while (my $obj = $rs->next) {
    $obj->update_reported();
  }
  
  my $rs2 = $schema->resultset($table)->get_ready_to_report();
  is ($rs2->count, 0, q[No entities to be reported]);
}

1;
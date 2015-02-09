use strict;
use warnings;
use Test::More tests => 13;
use Test::Exception;
use Test::Deep;
use JSON;
use Moose::Meta::Class;
use npg_testing::db;
use DateTime;

#Test model mapping
use_ok('npg_qc::Schema::Result::MqcOutcomeEnt', "Model check");

my $schema = Moose::Meta::Class->create_anon_class(
           roles => [qw/npg_testing::db/])
           ->new_object({})->create_test_db(q[npg_qc::Schema]);

my $table = 'MqcOutcomeEnt';
my $hist_table = 'MqcOutcomeHist';

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
      'id_mqc_outcome'=>0, 
      'username'=>'user', 
      'last_modified'=>DateTime->now()};

  my $hist_object_rs = $schema->resultset($hist_table)->search({'id_run'=>10, 'position'=>1, 'id_mqc_outcome'=>0}); #Search historic that matches latest change
  is ($hist_object_rs->count, 0, q[no row matches in the historic table before insert in entity]);

  my $object = $schema->resultset($table)->create($values);
  isa_ok($object, 'npg_qc::Schema::Result::MqcOutcomeEnt');

  my $rs = $schema->resultset($table)->search({'id_run'=>10, 'position'=>1, 'id_mqc_outcome'=>0});
  is ($rs->count, 1, q[one row created in the entity table]);
  
  $hist_object_rs = $schema->resultset($hist_table)->search({'id_run'=>10, 'position'=>1, 'id_mqc_outcome'=>0}); #Search historic that matches latest change
  is ($hist_object_rs->count, 1, q[one row matches in the historic table after insert in entity]);
}

$table = 'MqcOutcomeEnt';

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

  my $hist_object_rs = $schema->resultset($hist_table)->search({'id_run'=>100, 'position'=>4, 'id_mqc_outcome'=>3}); #Search historic that matches latest change
  is ($hist_object_rs->count, 0, q[no row matches in the historic table before update in entity]);

  my $object = $schema->resultset($table)->create($values); #Insert new entity
  my $rs = $schema->resultset($table);
  $rs->find({'id_run'=>100, 'position'=>4})->update({'id_mqc_outcome'=>3}); #Find and update the outcome in the new outcome
  $rs = $schema->resultset($table)->search({'id_run'=>100, 'position'=>4, 'id_mqc_outcome'=>3}); #Search the new outcome
  is ($rs->count, 1, q[one row matches in the entity table after update]);
  
  $hist_object_rs = $schema->resultset($hist_table)->search({'id_run'=>100, 'position'=>4, 'id_mqc_outcome'=>3}); #Search historic that matches latest change
  is ($hist_object_rs->count, 1, q[one row matches in the historic table after update in entity]);
}

#Test status workflow validation
#TODO 

#__PACKAGE__->meta->make_immutable;

1;
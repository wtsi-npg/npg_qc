#########
# Author:        jmtc
#

use strict;
use warnings;
use Test::More tests => 6;
use Test::Exception;
use Test::Deep;
use JSON;
use Moose::Meta::Class;
use npg_testing::db;
use DateTime;

use_ok('npg_qc::Schema::Result::MqcOutcomeEnt', "Model check");

my $schema = Moose::Meta::Class->create_anon_class(
           roles => [qw/npg_testing::db/])
           ->new_object({})->create_test_db(q[npg_qc::Schema]);

my $table = 'MqcOutcomeEnt';

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
  is ($rs->count, 1, q[one row matches in the table after update]);  
}

#Test status workflow validation
#TODO 
1;
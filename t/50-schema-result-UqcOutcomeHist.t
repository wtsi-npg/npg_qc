use strict;
use warnings;
use Test::More tests => 11;
use Test::Exception;
use Moose::Meta::Class;
use npg_testing::db;
use DateTime;
use t::autoqc_util;

use_ok('npg_qc::Schema::Result::UqcOutcomeHist');

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema]);

my $table = 'UqcOutcomeHist';

#Test insert
 {
   my $values = {'id_uqc_outcome'=>1,
       'username'=>'user',
       'last_modified'=>DateTime->now(),
       'modified_by'=>'cat'};
   $values->{'id_seq_composition'} = t::autoqc_util::find_or_save_composition($schema, {
        id_run => 9001, position => 1
   });
   my $object = $schema->resultset($table)->create($values);
   isa_ok($object, 'npg_qc::Schema::Result::UqcOutcomeHist');
   my $rs = $schema->resultset($table)->search({});
   is ($rs->count, 1, q[One row created in the table]);
 }

#Test select
 {
   my $values = {'id_uqc_outcome'=>0,
       'username'=>'user',
       'last_modified'=>DateTime->now(),
       'modified_by'=>'user'};
   my $temp_id_seq_comp=t::autoqc_util::find_or_save_composition($schema, {
    id_run => 9001, position => 2
   });
   $values->{'id_seq_composition'} = $temp_id_seq_comp;

   my $object = $schema->resultset($table)->create($values);
   isa_ok($object, 'npg_qc::Schema::Result::UqcOutcomeHist');

   my $rs = $schema->resultset($table)->search({'id_seq_composition'=>$temp_id_seq_comp});
   is ($rs->count, 1, q[One row matches in the table]);
   my $row=$rs->next();
   is ($row->seq_composition->seq_component_compositions->next->seq_component->id_run, 9001,
    q[DBIX relationship connects id_seq_composition with id_run]);
   is ($row->seq_composition->seq_component_compositions->next->seq_component->position, 2,
    q[DBIX relationship connects id_seq_composition with position]);
 }

 #Test update
 {
   my $values = {'id_uqc_outcome'=>3,
       'username'=>'user',
       'last_modified'=>DateTime->now(),
       'modified_by'=>'user'};
   my $temp_id_seq_comp=t::autoqc_util::find_or_save_composition($schema, {
    id_run => 9001, position => 3
   });
   $values->{'id_seq_composition'} = $temp_id_seq_comp;
   my $rs = $schema->resultset($table);
   lives_ok {$rs->create($values)} 'Insert new entity';
   is ($schema->resultset($table)->search({'id_seq_composition'=>$temp_id_seq_comp,
    'id_uqc_outcome'=>2})->count,
     0, q[No row matches in the table before update]);
   lives_ok {$rs->find({'id_seq_composition'=>$temp_id_seq_comp})->update({
    'id_uqc_outcome'=>2})}
     'Find and update the outcome in the new entity';
   is ($schema->resultset($table)->search({'id_seq_composition'=>$temp_id_seq_comp,
    'id_uqc_outcome'=>2})->count, 1, q[One row matches in the table after update]);
 }

1;
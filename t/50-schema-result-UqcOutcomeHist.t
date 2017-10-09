use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;
use Moose::Meta::Class;
use npg_testing::db;
use DateTime;
use t::autoqc_util;

use_ok('npg_qc::Schema::Result::UqcOutcomeHist');

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema], 't/data/fixtures');

my $table = 'UqcOutcomeHist';

#Test insert
 subtest 'insert tests' => sub {
  plan tests => 8;
   my $values = {'id_uqc_outcome'=>1,
       'username'=>'user',
       'last_modified'=>DateTime->now(),
       'modified_by'=>'cat',
       'rationale'=>'some rationale'};
   $values->{'id_seq_composition'} = t::autoqc_util::find_or_save_composition($schema, {
        id_run => 9001, position => 1
   });
   my $object = $schema->resultset($table)->create($values);
   isa_ok($object, 'npg_qc::Schema::Result::UqcOutcomeHist');
   my $rs = $schema->resultset($table)->search({});
   is ($rs->count, 1, q[One row created in the table]);

   my @notNullFields = ('id_seq_composition',
                        'id_uqc_outcome',
                        'username',
                        'last_modified',
                        'modified_by',
                        'rationale');
   foreach my $nnf (@notNullFields){
     my $tempval = $values->{$nnf};
     $values->{$nnf} = undef;
     throws_ok { $schema->resultset($table)->create($values); }
       qr/NOT NULL constraint failed/,
       "Absent $nnf throws error";
     $values->{$nnf} = $tempval;
   }
 };

#Test select
 subtest 'select tests' => sub{
  plan tests => 6;
   my $values = {'id_uqc_outcome'=>1,
       'username'=>'user',
       'last_modified'=>DateTime->now(),
       'modified_by'=>'user',
       'rationale'=>'some rationale'};
   my $temp_id_seq_comp=t::autoqc_util::find_or_save_composition($schema, {
    id_run => 9001, position => 2
   });
   $values->{'id_seq_composition'} = $temp_id_seq_comp;
   my $rs = $schema->resultset($table)->search({'id_seq_composition'=>$temp_id_seq_comp});
   is ($rs->count, 0, q[Row absent in the table before creation]);

   my $object = $schema->resultset($table)->create($values);
   isa_ok($object, 'npg_qc::Schema::Result::UqcOutcomeHist');

   $rs = $schema->resultset($table)->search({'id_seq_composition'=>$temp_id_seq_comp});
   is ($rs->count, 1, q[One row matches in the table]);
   my $row=$rs->next();
   is ($row->seq_composition->seq_component_compositions->next->seq_component->id_run, 9001,
    q[DBIX relationship connects id_seq_composition with id_run]);
   is ($row->seq_composition->seq_component_compositions->next->seq_component->position, 2,
    q[DBIX relationship connects id_seq_composition with position]);
   is ($row->uqc_outcome->short_desc, 'Accepted',
    q[DBIX relationship connects uqc_outcome with Dictionary]);
 };

 #Test update
 subtest 'update tests' => sub{
  plan tests => 4;
   my $values = {'id_uqc_outcome'=>3,
       'username'=>'user',
       'last_modified'=>DateTime->now(),
       'modified_by'=>'user',
       'rationale'=>'some rationale'};
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
 };




1;
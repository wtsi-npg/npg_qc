use strict;
use warnings;
use Test::More tests => 6;
use Test::Exception;
use Moose::Meta::Class;

use npg_testing::db;
use t::autoqc_util;

my $table      = 'MqcLibraryOutcomeEnt';
my $hist_table = 'MqcLibraryOutcomeHist';

use_ok('npg_qc::Schema::Result::' . $table);

my $schema = Moose::Meta::Class->create_anon_class(
     roles => [qw/npg_testing::db/])
     ->new_object({})->create_test_db(q[npg_qc::Schema], 't/data/fixtures');

subtest 'Test insert' => sub {
  plan tests => 9;

  my $values = {
    'id_run'         => 1,
    'position'       => 1,
    'tag_index'      => 1,
    'id_mqc_outcome' => 2,
    'username'       => 'user',
    'modified_by'    => 'user'};

  throws_ok {$schema->resultset($table)->create($values)}
    qr/NOT NULL constraint failed: mqc_library_outcome_ent\.id_seq_composition/,
    'composition foreign key is needed';

  $values->{'id_seq_composition'} = t::autoqc_util::find_or_save_composition(
                $schema, {'id_run'    => 1,
                          'position'  => 1,
                          'tag_index' => 1});
  isa_ok($schema->resultset($table)->create($values),
    'npg_qc::Schema::Result::' . $table);

  my $rs = $schema->resultset($table)->search({});
  is ($rs->count, 1, q[one row created in the table]);
  my $object = $rs->next;
  is($object->tag_index, 1, 'tag_index is 1');

  delete $values->{'tag_index'};
  $values->{'id_seq_composition'} = t::autoqc_util::find_or_save_composition(
                $schema, {'id_run'    => 1,
                          'position'  => 1});
  isa_ok($schema->resultset($table)->create($values),
    'npg_qc::Schema::Result::' . $table);

  $rs = $schema->resultset($table)->search({});
  is ($rs->count, 2, q[Two rows in the table]);

  $values = {
    'id_run'         => 2,
    'position'       => 8,
    'id_mqc_outcome' => 2,
    'username'       => 'user',
    'modified_by'    => 'user'
  };
  $values->{'id_seq_composition'} = t::autoqc_util::find_or_save_composition(
                $schema, {'id_run'    => 2,
                          'position'  => 8});
  $rs = $schema->resultset($table);

  lives_ok {$rs->find_or_new($values)
               ->update_or_insert()} 'lane record inserted';
  my $rs1 = $rs->search({'id_run' => 2});
  is ($rs1->count, 1, q[one row created in the table]);
  my $row = $rs1->next;
  is($row->tag_index, undef, 'tag index undefined');
};

subtest 'Test insert with historic defined' => sub {
  plan tests => 5;
  my $values = {
    'id_run'         => 10,
    'position'       => 1,
    'id_mqc_outcome' => 1,
    'tag_index'      => 100,
    'username'       => 'user',
    'modified_by'    => 'user'
  };
  $values->{'id_seq_composition'} = t::autoqc_util::find_or_save_composition(
                $schema, {'id_run'    => 10,
                          'position'  => 1});
  my $hist_object_rs = $schema->resultset($hist_table)->search({
    'id_run'         => 10,
    'position'       => 1,
    'tag_index'      => 100,
    'id_mqc_outcome' => 1
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
  is ($hist_object_rs->next->id_seq_composition, $object->id_seq_composition,
    'rows from two tables refer to teh same composition');
};

subtest 'insert with historic' => sub {
  plan tests => 7;

  my $values = {
    'id_run'         => 20,
    'position'       => 3,
    'id_mqc_outcome' => 1,
    'username'       => 'user',
    'modified_by'    => 'user'
  };
  $values->{'id_seq_composition'} = t::autoqc_util::find_or_save_composition(
                $schema, {'id_run'    => 20,
                          'position'  => 3});

  my $values_for_search = {};
  $values_for_search->{'id_run'}         = 20;
  $values_for_search->{'position'}       = 3;
  $values_for_search->{'tag_index'}      = undef;
  $values_for_search->{'id_mqc_outcome'} = 1;

  my $rs = $schema->resultset($table);
  is ($schema->resultset($hist_table)->search($values_for_search)->count, 0,
    q[no row matches in the historic table before insert in entity]);

  my $object = $schema->resultset($table)->create($values);
  isa_ok ($object, 'npg_qc::Schema::Result::'.$table);
  is ($object->tag_index, undef, q[tag_index inflated in entity]);

  $rs = $schema->resultset($table)->search({'id_run'=>20, 'position'=>3, 'id_mqc_outcome'=>1});
  is ($rs->count, 1, q[one row created in the entity table]);

  my $hist_object_rs = $schema->resultset($hist_table)->search($values_for_search);
  is ($hist_object_rs->count, 1,
    q[one row matches in the historic table after insert in entity]);
  my $hist = $hist_object_rs->next;
  is ($hist->tag_index, undef, q[tag_index is undefined in historic]);
  is ($hist->id_seq_composition, $object->id_seq_composition,
    'rows from two tables refer to teh same composition');
};

subtest q[update] => sub {
  plan tests => 50;
  
  my $rs = $schema->resultset($table);
  my $hrs = $schema->resultset($hist_table);

  my $args = {'id_run' => 444, 'position' => 1, 'tag_index' => 2};
  $args->{'id_seq_composition'} = t::autoqc_util::find_or_save_composition(
                $schema, $args);
  my $new_row = $rs->new_result($args);
  my $outcome = 'Accepted preliminary';
  lives_ok { $new_row->update_outcome($outcome, 'cat') }
    'preliminary outcome saved';
  ok ($new_row->in_storage, 'new object has been saved');

  my $hist_rs = $hrs->search($args);
  is ($hist_rs->count, 1, 'one historic is created');
  my $hist_new_row = $hist_rs->next();

  ok (!$new_row->has_final_outcome, 'not final outcome');
  ok ($new_row->is_accepted, 'is accepted');
  ok (!$new_row->is_final_accepted, 'not final accepted');

  for my $row (($new_row, $hist_new_row)) {
    is ($row->mqc_outcome->short_desc(), $outcome, 'correct prelim. outcome');
    is ($row->username, 'cat', 'username');
    is ($row->modified_by, 'cat', 'modified_by');
    ok ($row->last_modified, 'timestamp is set');
    isa_ok ($row->last_modified, 'DateTime');
  } 
  
  $outcome = 'Accepted final';
 
  $new_row = $rs->new_result($args);
  throws_ok { $new_row->update_outcome($outcome, 'dog', 'cat') }
    qr /UNIQUE constraint failed/,
    'error creating a record for existing entity';

  $args->{'position'} = 2;
  $args->{'id_seq_composition'} = t::autoqc_util::find_or_save_composition(
                $schema, {'id_run' => 444, 'position' => 2, 'tag_index' => 2});
  $new_row = $rs->new_result($args);
  lives_ok { $new_row->update_outcome($outcome, 'dog', 'cat') }
    'final outcome saved';
  ok ($new_row->in_storage, 'new object has been saved');

  $hist_rs = $hrs->search($args);
  is ($hist_rs->count, 1, 'one historic is created');
  $hist_new_row = $hist_rs->next();

  my $new_row_via_search = $rs->search($args)->next;

  for my $row (($new_row, $new_row_via_search, $hist_new_row)) {
    is ($new_row->mqc_outcome->short_desc(), $outcome, 'correct prelim. outcome');
    is ($new_row->username, 'cat', 'username');
    is ($new_row->modified_by, 'dog', 'modified_by');
    ok ($new_row->last_modified, 'timestamp is set');
    isa_ok ($new_row->last_modified, 'DateTime');
    ok ($new_row->has_final_outcome, 'is final outcome');
    ok ($new_row->is_accepted, 'is accepted');
    ok ($new_row->is_final_accepted, 'is final accepted');
  }

  $new_row->delete();

  $args = {'id_run' => 444, 'position' => 3, tag_index => 3};
  $args->{'id_seq_composition'} = t::autoqc_util::find_or_save_composition(
                $schema, $args);
  $new_row = $rs->new_result($args);
  $outcome = 'Accepted final';
  lives_ok { $new_row->update_outcome($outcome, 'cat') }
    'final outcome saved';
  ok ($new_row->in_storage, 'outcome has been saved');
  is ($new_row->mqc_outcome->short_desc, $outcome, 'final outcome');

  $outcome = 'Rejected final';
  lives_ok { $new_row->update_outcome($outcome, 'cat') }
    'can update final outcome';
  ok ($new_row->in_storage, 'outcome has been saved');
  is ($new_row->mqc_outcome->short_desc, $outcome, 'new final outcome');

  $new_row->delete();
};

subtest q[toggle final outcome] => sub {
  plan tests => 11;

  my $rs = $schema->resultset($table);

  my $args = {'id_run' => 444, 'position' => 3, tag_index => 4};
  $args->{'id_seq_composition'} = t::autoqc_util::find_or_save_composition(
                $schema, $args);
  my $new_row = $rs->new_result($args);

  throws_ok { $new_row->toggle_final_outcome('cat', 'dog') }
    qr/Record is not stored in the database yet/,
    'cannot toggle a new object';
  lives_ok { $new_row->update_outcome('Accepted preliminary', 'cat') }
    'prelim outcome saved';
  throws_ok { $new_row->toggle_final_outcome('cat', 'dog') }
    qr/Cannot toggle non-final outcome Accepted preliminary/,
    'cannot toggle a non-final outcome';
  lives_ok { $new_row->update_outcome('Undecided final', 'cat') }
    'undecided final outcome saved';
  throws_ok { $new_row->toggle_final_outcome('cat', 'dog') }
    qr/Cannot toggle undecided final outcome/,
    'cannot toggle an undecided outcome';

  my $old_outcome = 'Accepted final';
  lives_ok { $new_row->update_outcome($old_outcome, 'cat') }
    'final outcome saved';
  is($new_row->mqc_outcome->short_desc, $old_outcome, 'final outcome is set');

  my $outcome = 'Rejected final';
  lives_ok { $new_row->toggle_final_outcome('cat', 'dog') }
    'can toggle final outcome';
  is($new_row->mqc_outcome->short_desc, $outcome, 'new outcome');
  
  lives_ok { $new_row->toggle_final_outcome('cat', 'dog') }
    'can toggle final outcome once more';
  is($new_row->mqc_outcome->short_desc, $old_outcome, 'old outcome again');

  $new_row->delete();
};

1;


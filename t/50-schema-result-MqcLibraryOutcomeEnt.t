use strict;
use warnings;
use Test::More tests => 9;
use Test::Exception;
use Moose::Meta::Class;
use DateTime;

use npg_testing::db;
use t::autoqc_util;

my $table      = 'MqcLibraryOutcomeEnt';
my $dict_table = 'MqcLibraryOutcomeDict';
my $hist_table = 'MqcLibraryOutcomeHist';

use_ok('npg_qc::Schema::Result::' . $table);

my $schema = Moose::Meta::Class->create_anon_class(
     roles => [qw/npg_testing::db/])
     ->new_object({})->create_test_db(q[npg_qc::Schema], 't/data/fixtures');

sub _outcome {
  my $description = shift;
  return {'mqc_outcome' => $description};
}

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
    'rows from two tables refer to the same composition');
};

subtest q[update] => sub {
  plan tests => 55;

  my $rs = $schema->resultset($table);
  my $hrs = $schema->resultset($hist_table);

  my $args = {'id_run' => 444, 'position' => 1, 'tag_index' => 2};
  $args->{'id_seq_composition'} = t::autoqc_util::find_or_save_composition(
                $schema, $args);
  my $new_row = $rs->new_result($args);
  my $outcome = 'Accepted preliminary';
  lives_ok { $new_row->update_outcome(_outcome($outcome), 'cat') }
    'preliminary outcome saved';
  ok ($new_row->in_storage, 'new object has been saved');

  my $hist_rs = $hrs->search($args);
  is ($hist_rs->count, 1, 'one historic is created');
  my $hist_new_row = $hist_rs->next();

  ok (!$new_row->has_final_outcome, 'not final outcome');
  ok ($new_row->is_accepted, 'is accepted');
  ok (!$new_row->is_final_accepted, 'not final accepted');
  is ($new_row->description, 'Accepted preliminary', 'outcome description');

  for my $row (($new_row, $hist_new_row)) {
    is ($row->mqc_outcome->short_desc(), $outcome, 'correct prelim. outcome');
    is ($row->username, 'cat', 'username');
    is ($row->modified_by, 'cat', 'modified_by');
    ok ($row->last_modified, 'timestamp is set');
    isa_ok ($row->last_modified, 'DateTime');
  }

  $outcome = 'Accepted final';

  $new_row = $rs->new_result($args);
  throws_ok { $new_row->update_outcome(_outcome($outcome), 'dog', 'cat') }
    qr /UNIQUE constraint failed/,
    'error creating a record for existing entity';

  $args->{'position'} = 2;
  $args->{'id_seq_composition'} = t::autoqc_util::find_or_save_composition(
                $schema, {'id_run' => 444, 'position' => 2, 'tag_index' => 2});
  $new_row = $rs->new_result($args);
  lives_ok { $new_row->update_outcome(_outcome($outcome), 'dog', 'cat') }
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
  lives_ok { $new_row->update_outcome(_outcome($outcome), 'cat') }
    'final outcome saved';
  ok ($new_row->in_storage, 'outcome has been saved');
  is ($new_row->mqc_outcome->short_desc, $outcome, 'final outcome');
  my $dt = DateTime->now();
  is ($new_row->last_modified()->year, $dt->year, 'the "now" year');

  $outcome = 'Rejected final';

  my $h = _outcome($outcome);
  # pre-set the date
  $h->{'last_modified'} = DateTime->new(year => 2016, month => 10, day => 25);
  lives_ok { $new_row->update_outcome($h, 'cat') }
    'can update final outcome';
  ok ($new_row->in_storage, 'outcome has been saved');
  is ($new_row->mqc_outcome->short_desc, $outcome, 'new final outcome');
  $dt = $new_row->last_modified();
  is ($dt->year, 2016, 'year as set, no overwrite by the current time');
  is ($dt->month, 10, 'month as set');
  is ($dt->day, 25, 'day as set');

  $new_row->delete();
};

subtest q[validity for update] => sub {
  plan tests => 11;

  my $values = {'id_run' => 45, 'position' => 2};
  $values->{'id_seq_composition'} = t::autoqc_util::find_or_save_composition(
                $schema, $values);
  my $outcome = $schema->resultset($table)->new_result($values);

  throws_ok {$outcome->valid4update()}
    qr/Outcome hash is required/, 'outcome arg is required';
  throws_ok {$outcome->valid4update('Rejected preliminary')}
    qr/Outcome hash is required/, 'outcome arg should be a hash';
  throws_ok {$outcome->valid4update(_outcome(undef))}
    qr/Outcome description is missing/, 'outcome should be defined';
  throws_ok {$outcome->valid4update(_outcome(q[]))}
    qr/Outcome description is missing/, 'outcome cannot be an empty string';
  throws_ok {$outcome->valid4update({'some_outcome' => 'Rejected preliminary'})}
    qr/Outcome description is missing/, 'matching outcome type should be used';

  lives_and {
    is $outcome->valid4update(_outcome('Rejected preliminary')), 1 }
    'in-memory object can be updated to a prelim outcome';
  lives_and {
    is $outcome->valid4update(_outcome('Rejected final')), 1 }
    'in-memory object can be updated to a final outcome';

  my $dict_id_prel =
    $schema->resultset($dict_table)->search(
    {'short_desc' => 'Undecided'})->next->id_mqc_library_outcome;
  my $dict_id_final =
    $schema->resultset($dict_table)->search(
    {'short_desc' => 'Undecided final'})->next->id_mqc_library_outcome;

  $values = {'id_run' => 47, 'position' => 2, tag_index => 3};
  $values->{'id_seq_composition'} = t::autoqc_util::find_or_save_composition(
                $schema, $values);
  $outcome = $schema->resultset($table)->new_result($values);
  is($outcome->valid4update(_outcome('some outcome')), 1,
    'in-memory object can be updated');

  $values = {'id_run' => 47, 'position' => 2, 'tag_index' => 3};
  $values->{'id_seq_composition'} = t::autoqc_util::find_or_save_composition(
                $schema, $values);
  $values->{'id_mqc_outcome'} = $dict_id_prel;
  $values->{'username'} = 'cat';
  $values->{'modified_by'} = 'dog';
  $outcome = $schema->resultset($table)->create($values);
  is($outcome->valid4update(_outcome('some outcome')), 1,
    'stored lib outcome can be updated to a different outcome');
  is($outcome->valid4update(_outcome($outcome->mqc_outcome->short_desc)), 0,
    'stored lib outcome cannot be updated to the same outcome');

  $outcome->update({'id_mqc_outcome' => $dict_id_final});
  throws_ok { $outcome->valid4update(_outcome('some outcome')) }
    qr/Final outcome cannot be updated/,
    'error updating a final stored lib outcome to another final outcome';
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
  lives_ok { $new_row->update_outcome(_outcome('Accepted preliminary'), 'cat') }
    'prelim outcome saved';
  throws_ok { $new_row->toggle_final_outcome('cat', 'dog') }
    qr/Cannot toggle non-final outcome Accepted preliminary/,
    'cannot toggle a non-final outcome';
  lives_ok { $new_row->update_outcome(_outcome('Undecided final'), 'cat') }
    'undecided final outcome saved';
  throws_ok { $new_row->toggle_final_outcome('cat', 'dog') }
    qr/Cannot toggle undecided final outcome/,
    'cannot toggle an undecided outcome';

  my $old_outcome = 'Accepted final';
  lives_ok { $new_row->update_outcome(_outcome($old_outcome), 'cat') }
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

subtest 'dynamically defined methods exist' => sub {
  plan tests => 8;

  my @methods = qw/dict_rel_name has_final_outcome is_accepted
                   is_final_accepted is_undecided is_rejected
                   description/;
  for my $m (@methods) {
    ok (npg_qc::Schema::Result::UqcOutcomeEnt->can($m),
        "method $m exists");
  }

  throws_ok {npg_qc::Schema::Result::UqcOutcomeEnt->add_common_ent_methods()}
    qr/One of the methods is already defined/,
    'these methods cannot be added second time'; 
};

subtest 'qc outcome relationship name' => sub {
  plan tests => 2; 

  is (npg_qc::Schema::Result::MqcLibraryOutcomeEnt->dict_rel_name(),
    'mqc_outcome', 'as class method');
  my $row = $schema->resultset($table)->search({})->next();
  is ($row->dict_rel_name(), 'mqc_outcome', 'as instance method');
};

1;


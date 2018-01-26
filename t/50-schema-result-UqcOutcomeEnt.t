use strict;
use warnings;
use Test::More tests => 6;
use Test::Exception;
use Moose::Meta::Class;
use DateTime;

use npg_testing::db;
use t::autoqc_util;

use_ok('npg_qc::Schema::Result::UqcOutcomeEnt');

my $schema = Moose::Meta::Class->create_anon_class(
     roles => [qw/npg_testing::db/])
     ->new_object({})->create_test_db(q[npg_qc::Schema], 't/data/fixtures');

my $rs_ent  = $schema->resultset('UqcOutcomeEnt');
my $rs_hist = $schema->resultset('UqcOutcomeHist');
my $rs_dict = $schema->resultset('UqcOutcomeDict');

my $id_seq_comp_9444_1_2 = t::autoqc_util::find_or_save_composition(
  $schema, {id_run => 9444, position => 1, tag_index => 2});

subtest 'Testing initial assumptions' => sub {
  plan tests => 3;
  
  is ($rs_ent->search({})->count(),  0, 'ent table is empty');
  is ($rs_hist->search({})->count(), 0, 'hist table is empty');
  is ($rs_dict->search({})->count(), 3, 'dict table contains 3 rows');  
};

subtest 'test insert' => sub {
  plan tests => 30;

  my $values = {
    'id_uqc_outcome' => 1,
    'username'       => 'user1',
    'last_modified'  => DateTime->now(),
    'modified_by'    => 'user2',
    'rationale'      => 'rationale something'
  };
  my $id_seq_comp = t::autoqc_util::find_or_save_composition($schema, {
        id_run => 9001, position => 1, tag_index => 1
  });
  $values->{'id_seq_composition'} = $id_seq_comp;
  my $rs = $rs_ent->search({});
  is ($rs->count, 0, q[no existing row found in the ent table before insertion]);
  $rs = $rs_hist->search({});
  is ($rs->count, 0, q[no existing row found in the hist table before insertion]);
  isa_ok($rs_ent->create($values), 'npg_qc::Schema::Result::UqcOutcomeEnt');
  $rs = $rs_ent->search({});
  is ($rs->count, 1, q[one row found in the ent table after insertion]);
  my $object = $rs->next;
  is ($object->id_seq_composition, $id_seq_comp, 'id_seq_composition value is correct');
  is ($object->id_uqc_outcome, 1, 'id_uqc_outcome is correct');
  is ($object->username, 'user1', 'username correct');
  is ($object->modified_by, 'user2', 'modified_by correct');
  is ($object->rationale, 'rationale something', 'rationale correct');
  my $outcome = $object->uqc_outcome;
  ok ($outcome, 'linked outcome row');
  isa_ok ($outcome, 'npg_qc::Schema::Result::UqcOutcomeDict');
  is ($outcome->short_desc, 'Accepted', 'correct outcome description');
  ok ($object->description(), 'outcome description is "Accepted"');
  my $seq_composition = $object->seq_composition;
  ok ($seq_composition, 'linked composition row');
  isa_ok ($seq_composition, 'npg_qc::Schema::Result::SeqComposition');
  is ($seq_composition->id_seq_composition, $id_seq_comp, 'linked to correct composition row');

  $rs = $rs_hist->search({});
  is ($rs->count, 1, q[one row found in the hist table after insertion]);
  $object = $rs->next; 
  is ($object->id_seq_composition, $id_seq_comp, 'id_seq_composition value is correct');
  is ($object->id_uqc_outcome, 1, 'id_uqc_outcome is correct');
  is ($object->username, 'user1', 'username correct');
  is ($object->modified_by, 'user2', 'modified_by correct');
  is ($object->rationale, 'rationale something', 'rationale correct');
  $outcome = $object->uqc_outcome;
  ok ($outcome, 'linked outcome row');
  isa_ok($outcome, 'npg_qc::Schema::Result::UqcOutcomeDict');
  is ($outcome->short_desc, 'Accepted', 'correct outcome description');
  $seq_composition = $object->seq_composition;
  ok ($seq_composition, 'linked composition row');
  isa_ok($seq_composition, 'npg_qc::Schema::Result::SeqComposition');
  is ($seq_composition->id_seq_composition, $id_seq_comp, 'linked to correct composition row');

  $id_seq_comp = t::autoqc_util::find_or_save_composition($schema, {
        id_run => 9001, position => 1, tag_index => 2
  });
  $values->{'id_seq_composition'} = $id_seq_comp;
  $rs_ent->create($values);
  is ($rs_ent->search({})->count,  2, q[Two rows in the ent table]);
  is ($rs_hist->search({})->count, 2, q[Two rows in the hist table]);
};

subtest 'test non null constraints' => sub {
  plan tests => 5;

  my $values = {
    'id_seq_composition' => t::autoqc_util::find_or_save_composition(
                            $schema, {id_run => 9020, position => 3 }),
    'id_uqc_outcome'     => 1,
    'username'           => 'user',
    'modified_by'        => 'user',
    'rationale'          => 'rationale something'
  };

  foreach my $col_name (sort keys %{$values}) {
    my $tempval = $values->{$col_name};
    $values->{$col_name} = undef;
    throws_ok { $rs_ent->create($values) } qr/NOT NULL constraint failed/,
      "NOT NULL constraint is set on $col_name";
    $values->{$col_name} = $tempval;
  }
};

subtest 'update tests' => sub {
  plan tests => 11;
  my $id_seq_comp = t::autoqc_util::find_or_save_composition($schema, {
        id_run => 9010, position => 2, tag_index => 1
  });
  my $values = {
    'id_uqc_outcome'     => 1,
    'id_seq_composition' => $id_seq_comp,
    'username'           => 'user1',
    'last_modified'      => DateTime->now(),
    'modified_by'        => 'user2',
    'rationale'          => 'rationale1'
  };
  my $row;
  is ($rs_hist->search({'id_seq_composition' => $id_seq_comp})->count(), 0,
    "no historic entry before inserting entity for id_seq_comp:$id_seq_comp");
  lives_ok{$row = $rs_ent->create($values)} 'creates new uqc record correctly';
  is ($rs_hist->search({'id_seq_composition' => $id_seq_comp})->count(), 1,
    "an historic entry for id_seq_comp:$id_seq_comp exists after creating the entity (but before update)");
  is ($row->id_uqc_outcome, 1, 'id_uqc_outcome is Accepted before update');
  throws_ok {$row->update_outcome() } qr/Outcome required/,
      'A hash with outcome field is required';
  my $rptkey_attributes = {};
  throws_ok {$row->update_outcome($rptkey_attributes, 'cat') } qr/Outcome required/,
      'Outcome value is required in the input hash';
  $rptkey_attributes = {'uqc_outcome' => 'Rejected'};
  throws_ok {$row->update_outcome($rptkey_attributes, 'cat') } qr/Rationale required/,
      'Rationale is required in the input hash when updating a uqc outcome';
  $rptkey_attributes->{'rationale'} = 'rationale2';
  throws_ok {$row->update_outcome($rptkey_attributes) } qr/User name required/,
      'Modify_by value is required in the input hash';
  lives_ok{$row->update_outcome($rptkey_attributes, 'cat')} 'updates existing uqc record correctly';
  is ($row->id_uqc_outcome, 2, 'id_uqc_outcome is -Rejected- after update');

  is ($rs_hist->search({'id_seq_composition' => $id_seq_comp})->count(), 2,
    "another historic entry has been added after the update of id_seq_comp:$id_seq_comp");
};

subtest 'test dict relationship' => sub {
  plan tests => 2;

  my $values = {
    'id_uqc_outcome' => 1,
    'username'       => 'user1',
    'last_modified'  => DateTime->now(),
    'modified_by'    => 'user2',
    'rationale'      => 'rationale something'
  };
  my $id_seq_comp = t::autoqc_util::find_or_save_composition($schema, {
        id_run => 90, position => 1, tag_index => 1
  });
  $values->{'id_seq_composition'} = $id_seq_comp;
  my $o = $rs_ent->create($values);
  isa_ok($o, 'npg_qc::Schema::Result::UqcOutcomeEnt');
  is ($o->_dict_relation(), 'uqc_outcome', 'The created entity has a uqc_outcome dictionary relationship');
};

1;

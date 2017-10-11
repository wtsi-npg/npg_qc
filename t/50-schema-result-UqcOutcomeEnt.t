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
  plan tests => 27;

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
  isa_ok($rs_ent->create($values), 'npg_qc::Schema::Result::UqcOutcomeEnt');
  my $rs = $rs_ent->search({});
  is ($rs->count, 1, q[one row found in the ent table]);
  my $object = $rs->next;
  is ($object->id_seq_composition, $id_seq_comp, 'id_seq_composition valueis correct');
  is ($object->id_uqc_outcome, 1, 'id_uqc_outcome is correct');
  is ($object->username, 'user1', 'username correct');
  is ($object->modified_by, 'user2', 'modified_by correct');
  is ($object->rationale, 'rationale something', 'rationale correct');
  my $outcome = $object->uqc_outcome;
  ok ($outcome, 'linked outcome row');
  isa_ok ($outcome, 'npg_qc::Schema::Result::UqcOutcomeDict');
  is ($outcome->short_desc, 'Accepted', 'correct outcome description');
  my $seq_composition = $object->seq_composition;
  ok ($seq_composition, 'linked composition row');
  isa_ok ($seq_composition, 'npg_qc::Schema::Result::SeqComposition');
  is ($seq_composition->id_seq_composition, $id_seq_comp, 'linked to correct composition row');

  $rs = $rs_hist->search({});
  is ($rs->count, 1, q[one row found in the hist table]);
  $object = $rs->next; 
  is ($object->id_seq_composition, $id_seq_comp, 'id_seq_composition valueis correct');
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

subtest q[update a new result via update_outcome] => sub {
  plan tests => 22;

  my $args = {
    'id_uqc_outcome'     => 1,
    'username'           => 'user',
    'last_modified'      => DateTime->now(),
    'modified_by'        => 'user',
    'rationale'          => 'rationale something',
    'id_seq_composition' => $id_seq_comp_9444_1_2
  };
  
  is($rs_hist->search({'id_seq_composition' => $id_seq_comp_9444_1_2})->count(), 0,
    'prerequisite: hist table does not have a row with ' . 
    "id_seq_composition $id_seq_comp_9444_1_2");

  my $new_row = $rs_ent->new_result($args);
  ok (!$new_row->in_storage, 'new object has not been saved yet');

  throws_ok {!$new_row->update_outcome('some invalid', 'user')}
    qr/Outcome some invalid is invalid/,
    'error updating to an invalid string outcome';
  throws_ok {!$new_row->update_outcome(123, 'user')}
    qr/Outcome 123 is invalid/,
    'error updating to invalid integer status';
  throws_ok {!$new_row->update_outcome('Rejected')}
    qr/User name required/,
    'username should be given';
  throws_ok {!$new_row->update_outcome(undef, 'user')}
    qr/Outcome required/,
     'outcome should be given';
  throws_ok { $new_row->update_outcome('Accepted', 'cat', 'RT#1000')}
    qr/Rationale is required/,
     'fails when rationale is not provided';

  lives_ok { $new_row->update_outcome('Rejected', 'cat1','cat2', 'rationale other') }
    'uqc outcome saved';
  ok ($new_row->in_storage, 'new object has been saved');

  my $hist_rs = $rs_hist->search({'id_seq_composition' => $id_seq_comp_9444_1_2});
  is ($hist_rs->count, 1, 'one historic was created');
  my $hist_new_row = $hist_rs->next();
  ok ($new_row->is_rejected, 'is rejected');
  ok (!$new_row->is_final_accepted, 'not final accepted');

  for my $row (($new_row, $hist_new_row)) {
    is ($row->uqc_outcome->short_desc(), 'Rejected', 'correct outcome');
    is ($row->username, 'cat2', 'username');
    is ($row->modified_by, 'cat1', 'modified_by');
    ok ($row->last_modified, 'timestamp is set');
    is ($row->rationale, 'rationale other', 'rationale');
  }
};

subtest q[update an existing result via update_outcome] => sub {
  plan tests => 21;
  
  my $row = $rs_ent->search({'id_seq_composition' => $id_seq_comp_9444_1_2})->next();
  ok ($row, 'prerequisite: row exists in ent table');
  
  my $hrs = $rs_hist->search({'id_seq_composition' => $id_seq_comp_9444_1_2});
  is ($hrs->count(), 1, 'prerequisite: one row exists in hist table');
  my $row_hist1 = $hrs->next();
  my $row_hist1_id = $row_hist1->id_uqc_outcome_hist;

  lives_ok { $row->update_outcome('Undecided', 'tiger1','tiger2', 'rationale new') }
    'uqc outcome updated';

  my @hist_all = $hrs->search({'id_seq_composition' => $id_seq_comp_9444_1_2})->all();
  is (scalar @hist_all, 2, 'found two historic records');
  my @hist_one = grep {$_->id_uqc_outcome_hist != $row_hist1_id} @hist_all;
  is (scalar @hist_one, 1, 'found one new historic record');
  
  my $row_hist2 = $hist_one[0];
  for my $row ( ($row, $row_hist2) ) {
    is ($row->uqc_outcome->short_desc(), 'Undecided', 'correct outcome');
    is ($row->username, 'tiger2', 'username');
    is ($row->modified_by, 'tiger1', 'modified_by');
    ok ($row->last_modified, 'timestamp is set');
    is ($row->rationale, 'rationale new', 'rationale');
  }
  is (DateTime->compare($row->last_modified, $row_hist2->last_modified), 0,
    'last_modified of the ent and corresponding hist record is the same');

  @hist_one = grep {$_->id_uqc_outcome_hist == $row_hist1_id} @hist_all;
  my $row_hist1_after = $hist_one[0];
  foreach my $col_name ( qw/username modified_by rationale id_uqc_outcome/ ) {
    is ($row_hist1_after->$col_name, $row_hist1->$col_name,
      "$col_name value has not changed in previous historic record");
  }
  is (DateTime->compare($row_hist1_after->last_modified, $row_hist1->last_modified), 0,
    'last_modified of the existing record remained the same');
};

1;

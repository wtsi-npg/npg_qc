use strict;
use warnings;
use Test::More tests => 10;
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
  plan tests => 28;

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
  ok ($object->description(), 'outcome description is "Accepted"');
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

  is (npg_qc::Schema::Result::UqcOutcomeEnt->dict_rel_name(),
    'uqc_outcome', 'as class method');
  my $row = $rs_ent->search({})->next();
  is ($row->dict_rel_name(), 'uqc_outcome', 'as instance method');
};

subtest 'validity for update' => sub {
  plan tests => 15;

  my @id_seq_comp = ();
  for my $p ((1 .. 3)) {
    push @id_seq_comp, t::autoqc_util::find_or_save_composition($schema,
        {id_run => 9015, position => $p});
  }

  my @dict_entries = $rs_dict->search({iscurrent => 1})->all();
  is (scalar @id_seq_comp, scalar @dict_entries,
    'test prerequisite: correct number of composition entries created');
  
  my @descriptions = map {$_->short_desc} @dict_entries;
  my @rows = ();
  my $i = 0;
  while ($i < scalar @dict_entries) {
    my $values = {
      'id_uqc_outcome'     => $dict_entries[$i]->id_uqc_outcome,
      'id_seq_composition' => $id_seq_comp[$i],
      'username'           => 'user1',
      'modified_by'        => 'user2',
      'rationale'          => 'rationale'
    };
    my $row = $rs_ent->create($values);
    push @rows, $row;
    my $this_description = $descriptions[$i];
    ok (!$row->valid4update({'uqc_outcome' => $this_description}),
      'update to the same outcome is invalid');
    my @other_descriptions = grep { $_ ne $this_description } @descriptions;
    foreach my $d (@other_descriptions) {
      ok ($row->valid4update({'uqc_outcome' => $d}),
        'update to a different outcome is valid');
    }
    $i++;  
  }

  my $outcome = $rows[0];
  throws_ok {$outcome->valid4update()}
    qr/Outcome hash is required/, 'outcome arg is required';
  throws_ok {$outcome->valid4update('Rejected preliminary')}
    qr/Outcome hash is required/, 'outcome arg should be a hash';
  throws_ok {$outcome->valid4update({'uqc_outcome' => undef})}
    qr/Outcome description is missing/, 'outcome should be defined';
  throws_ok {$outcome->valid4update({'uqc_outcome' => q[]})}
    qr/Outcome description is missing/, 'outcome cannot be an empty string';
  throws_ok {$outcome->valid4update({'some_outcome' => 'Rejected preliminary'})}
    qr/Outcome description is missing/, 'matching outcome type should be used';
};

subtest 'update outcome errors' => sub {
  plan tests => 10;

  my $id_seq_comp = t::autoqc_util::find_or_save_composition($schema,
        {id_run => 9011, position => 2});

  my $values = {
    'id_uqc_outcome'     => 1,
    'id_seq_composition' => $id_seq_comp,
    'username'           => 'user1',
    'modified_by'        => 'user2',
    'rationale'          => 'rationale1'
  };

  my $row = $rs_ent->create($values);
  throws_ok {$row->update_outcome() } qr/Outcome hash is required/,
    'a hash with outcome field is required';
  throws_ok {$row->update_outcome('outcome', 'cat') } qr/Outcome hash is required/,
    'outcome value is required in the input hash';
  throws_ok {$row->update_outcome({}) } qr/User name required/,
    'user name required';

  throws_ok {$row->update_outcome({}, 'cat') } qr/Rationale required/,
    'rationale required';
  throws_ok {$row->update_outcome({'rationale' => 'some'}, q[cat]) }
    qr/Outcome required/,
    'outcome missing - error';
  throws_ok {$row->update_outcome(
    {'uqc_outcome'=>'Accepted', 'rationale'=>undef}, q[cat]) }
    qr/Rationale required/,
    'undefined rationale description - error';
  throws_ok {$row->update_outcome(
    {'uqc_outcome'=>'Accepted', 'rationale'=>q[]}, q[cat]) }
    qr/Rationale required/,
    'empty rationale description - error'; 
  throws_ok {$row->update_outcome(
    {'mqc_outcome' => 'Accepted', 'rationale' => 'some'}, q[cat]) }
    qr/Outcome required/,
    'uqc outcome missing - error';
  throws_ok {$row->update_outcome(
    {'uqc_outcome'=>undef, 'rationale'=>'something'}, q[cat]) }
    qr/Outcome required/,
    'undefined uqc outcome description - error';
  throws_ok {$row->update_outcome(
    {'uqc_outcome'=>q[], 'rationale'=>'something'}, q[cat]) }
    qr/Outcome required/,
    'empty uqc outcome description - error';
};

subtest 'update outcome' => sub {
  plan tests => 17;

  my $id_seq_comp = t::autoqc_util::find_or_save_composition($schema,
                    {id_run => 9010, position => 2, tag_index => 1});

  my $hist_count = $rs_hist->search({'id_seq_composition' => $id_seq_comp})
                   ->count();
  my $values = {
    'id_uqc_outcome'     => 1,
    'id_seq_composition' => $id_seq_comp,
    'username'           => 'user1',
    'modified_by'        => 'user2',
    'rationale'          => 'rationale1'
  };

  my $row = $rs_ent->create($values);

  is ($row->description, 'Accepted', 'outcome before update');
  
  lives_ok {$row->update_outcome(
    {'uqc_outcome' => 'Rejected', 'rationale' => 'some'}, 'cat')}
    'no error updating record';
  is ($row->description, 'Rejected', 'correct outcome saved');
  is ($row->rationale, 'some', 'correct rationale saved');
  is ($row->username, 'cat', 'user set correctly');
  is ($row->modified_by, 'cat', 'modify_by set correctly');

  my @historic = $rs_hist->search({'id_seq_composition' => $id_seq_comp},
                        {'order_by' => { -asc => 'last_modified'}})->all();
  is (scalar @historic, $hist_count+2, 'two more historic entries');
  my $latest_hist = pop @historic;
  is (DateTime->compare($latest_hist->last_modified, $row->last_modified), 0,
    'modification date copied to historic record');

  $id_seq_comp = t::autoqc_util::find_or_save_composition($schema,
                 {id_run => 9010, position => 3});
  $hist_count = $rs_hist->search({'id_seq_composition' => $id_seq_comp},
                        {'order_by' => { -asc => 'last_modified'}})->count();
  $row = $rs_ent->new({id_seq_composition => $id_seq_comp});
  ok (!$row->in_storage, 'row is not yet saved to the db');
  lives_ok {$row->update_outcome(
    {'uqc_outcome' => 'Undecided', 'rationale' => 'other'},
    'tiger', 'dog')}
    'no error saving in-memory object';
  ok ($row->in_storage, 'row saved to the db');
  is ($row->description, 'Undecided', 'correct outcome saved');
  is ($row->rationale, 'other', 'correct rationale saved');
  is ($row->username, 'dog', 'user set correctly');
  is ($row->modified_by, 'tiger', 'modify_by set correctly');

  @historic = $rs_hist->search({'id_seq_composition' => $id_seq_comp},
                        {'order_by' => { -asc => 'last_modified'}})->all();
  is (scalar @historic, $hist_count+1, 'one more historic entries');
  $latest_hist = pop @historic;
  is (DateTime->compare($latest_hist->last_modified, $row->last_modified), 0,
    'modification date for the ent and its hist record is the same');
};

subtest 'sanitize' => sub {
  plan tests => 14;

  my $p = 'npg_qc::Schema::Result::UqcOutcomeEnt';
  throws_ok { $p->sanitize_value() } qr/Input undefined/,
    'requires input';
  throws_ok { $p->sanitize_value(q[]) }
    qr/Only white space characters in input/,
    'requires non-empty input';
  throws_ok { $p->sanitize_value(qq[ \n\t]) }
    qr/Only white space characters in input/,
    'all white space input is not accepted';

  is ($p->sanitize_value(q[d3om4]), q[d3om4], 'alhanumeric string accepted');
  is ($p->sanitize_value(q[RT#345]), q[RT#345], 'hash accepted');
  is ($p->sanitize_value(q[RT_345]), q[RT_345], 'underscore accepted');
  is ($p->sanitize_value(q[RT-345]), q[RT-345], 'dash accepted');
  is ($p->sanitize_value(qq[\ndom\t ]), q[dom], 'trimmed value returned');
  is ($p->sanitize_value(qq[\ndo m\t ]), q[do m], 'space in the middle is accepted, not trimmed');

  throws_ok { $p->sanitize_value('email "someone"') }
    qr/Illegal characters/, 'double quotes are not accepted';
  throws_ok { $p->sanitize_value(q{email someone's friend}) }
    qr/Illegal characters/, 'single quotes are not accepted';

  throws_ok { $p->sanitize_value('email some@other.com') }
    qr/Illegal characters/, 'email address is not allowed';
  throws_ok { $p->sanitize_value('form <th>some</th>') }
    qr/Illegal characters/, 'HTML is not allowed';
  throws_ok { $p->sanitize_value('<script>console.log();</script>') }
    qr/Illegal characters/, 'JavaScript is not allowed';
};

1;

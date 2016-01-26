use strict;
use warnings;
use Test::More tests => 6;
use Test::Exception;
use Moose::Meta::Class;
use npg_testing::db;

my $table = 'MqcOutcomeEnt';

use_ok('npg_qc::Schema::ResultSet::' . $table);
use_ok('npg_qc::Schema::Result::' . $table);

my $schema = Moose::Meta::Class->create_anon_class(
           roles => [qw/npg_testing::db/])
           ->new_object({})->create_test_db(q[npg_qc::Schema], 't/data/fixtures');

my $resultset = $schema->resultset($table);
while (my $row = $resultset->next) {
  $row->delete;
}

subtest q[outcomes ready for reporting] => sub {
  plan tests => 15;

  my @dict_ids = map {$_->id_mqc_outcome}
    $schema->resultset('npg_qc::Schema::Result::MqcOutcomeDict')
           ->search({}, {'order_by' => 'id_mqc_outcome',})->all();

  my $values = {'username' => 'cat', 'modified_by' => 'cat'};
  foreach my $id_run ( (22, 23, 24) ) {
    foreach my $id (@dict_ids) {
      $values->{'id_run'}        = $id_run;
      $values->{'position'}      = $id;
      $values->{'id_mqc_outcome'} = $id;
      $resultset->create($values);
    }
  }

  is($resultset->search({})->count(), 15, '15 rows created');

  my $rs = $resultset->get_ready_to_report();
  isa_ok($rs, 'npg_qc::Schema::ResultSet::' . $table);
  my @rows = $rs->all();
  is(scalar @rows, 6, '6 rows returned');
  use Data::Dumper; 
  my @attrs = map { $_->id_run} @rows;
  is_deeply(\@attrs,[22, 22, 23, 23, 24, 24], 'correct run ids');
  @attrs = map { $_->position} @rows;
  is_deeply(\@attrs,[3,4,3,4,3,4], 'correct positions');

  $rs = $resultset->search({id_run => 23, position => [3,4]});
  while (my $row = $rs->next) {
    $row->update({'reported' => $row->get_time_now()});
  }

  $rs = $resultset->get_ready_to_report();
  foreach my $id_run ( (22, 24) ) {
    foreach my $position ( (3,4) ) {
      my $row = $rs->next;
      is ($row->id_run, $id_run, 'run id correct');
      is ($row->position, $position, 'position correct');
    }
  }

  $rs = $resultset->search({id_run => [22, 24], position => [3,4]});
  while (my $row = $rs->next) {
    $row->update({'reported' => $row->get_time_now()});
  }
  $rs = $resultset->get_ready_to_report();
  isa_ok($rs, 'npg_qc::Schema::ResultSet::' . $table);
  is($rs->count(), 0, 'result set is empty');
};

subtest q[get outcomes as hash] => sub {
  plan tests => 4;

  my $id_run   = 2;
  my $values = {
    'id_run'         => $id_run, 
    'position'       => 1,
    'id_mqc_outcome' => 2, #Rejected preliminary
    'username'       => 'user', 
    'modified_by'    => 'tiger'
  };

  $resultset->create($values);
  $values->{'position'} = 2;
  $resultset->create($values);
  is ($resultset->search({'id_run' => $id_run})->count(),
    2, q[two rows available in the table for run 2]);
  
  is_deeply ({'1' => 'Rejected preliminary', '2' => 'Rejected preliminary',},
    $resultset->get_outcomes_as_hash($id_run),
    q[correct output]);

  is ($resultset->search({'id_run' => 40000})->count(),
    0, q[no rows for run 40000]);
  is_deeply ({}, $resultset->get_outcomes_as_hash(40000),
    q[correct empty output]);
};

subtest q[find or new outcome entity] => sub {
  plan tests => 14;

  my $class = 'npg_qc::Schema::Result::' . $table;
  my $row = $resultset->search_outcome_ent(2, 1, 'cat');
  isa_ok($row, $class);
  ok($row->in_storage, 'row is stored in the database');
  is($row->id_run, 2, 'correct run id');
  is($row->position, 1, 'correct position');
  is($row->username, 'user', 'correct username');
  is($row->modified_by, 'tiger', 'correct modified_by value');
  is($row->mqc_outcome->short_desc, 'Rejected preliminary',
    'can retrieve short description via the outcome_ent relationship');

  $row = $resultset->search_outcome_ent(40000, 8, 'cat');
  isa_ok($row, $class);
  ok(!$row->in_storage, 'row is not stored in the database');
  is($row->id_run, 40000, 'correct run id');
  is($row->position, 8, 'correct position');
  is($row->username, 'cat', 'correct username');
  is($row->modified_by, 'cat', 'correct modified_by value');
  is($row->mqc_outcome, undef, 'outcome entity relationship is undefined');
};

subtest q[packed data] => sub {
  plan tests => 2;

  my $expected = {'id_run' => 2, 'position' => 2, 'mqc_outcome' => 'Rejected preliminary'};
  is_deeply($resultset->find({id_run => 2, position => 2})->pack(),
    $expected, 'correct lane 2 data returned');

  $resultset->search({id_run => 2, position => 1})->update({'id_mqc_outcome' => 1});
  $expected->{'position'}    = 1;
  $expected->{'mqc_outcome'} = 'Accepted preliminary';
  is_deeply($resultset->find({id_run => 2, position => 1})->pack(),
    $expected, 'correct lane 1 data returned');
};

1;

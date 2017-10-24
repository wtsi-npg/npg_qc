use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;
use Moose::Meta::Class;

use npg_testing::db;
use t::autoqc_util;

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
 
lives_and {is $resultset->search_autoqc({})->count(), 0}
  'having invoked search_autoqc() method can run count() method';

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
      $values->{'id_seq_composition'} =
        t::autoqc_util::find_or_save_composition(
          $schema, {'id_run' => $id_run, 'position'  => $id});
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

1;

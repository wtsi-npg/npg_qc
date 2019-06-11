use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;
use Moose::Meta::Class;
use Digest::MD5 qw/md5_hex/;
use DateTime;
use JSON::XS;

use npg_testing::db;
use t::autoqc_util;

my $table     = 'Review';
my $c_table   = 'ReviewCriteria';
my $mqc_table = 'MqcLibraryOutcomeEnt';

use_ok('npg_qc::Schema::Result::' . $table);

my $schema = Moose::Meta::Class->create_anon_class(
     roles => [qw/npg_testing::db/])
     ->new_object({})->create_test_db(q[npg_qc::Schema], 't/data/fixtures');

subtest 'reject incomplete results on insert' => sub {
  plan tests => 4;

  my $values = {
    evaluation_results => {"e1"=>1,"e2"=>0},
    criteria           => {"and"=>["e1","e2"]},
    pass               => 0,
    path               => 't/data'
  };
  throws_ok {$schema->resultset($table)->create($values)}
    qr/Evaluation results present, but library_type absent/,
    'library type is not defined - error on insert';

  $values = {
    library_type       => 'common_type',
    criteria           => {},
    evaluation_results => {"e1"=>1,"e2"=>0},
    pass               => 0,
  };
  throws_ok {$schema->resultset($table)->create($values)}
    qr/Evaluation results present, but criteria absent/,
    'criteria are not defined - error on insert';

  $values = {
    evaluation_results => {"e1"=>1,"e2"=>0},
    criteria           => {},
    qc_outcome =>
    {"mqc_outcome"=>"Rejected final","timestamp"=>"2018-06-03T12:53:46+0000","username"=>"robo_qc"},
    pass => 0,
    path => 't/data'
  };
  throws_ok {$schema->resultset($table)->create($values)}
    qr/Evaluation results present, but library_type absent/,
    'criteria and library type are not defined - error on insert';

  $values = {
    library_type       => 'common_type',
    evaluation_results => {"e1"=>1,"e2"=>0},
    criteria           => {"and"=>["e1","e2"]},
    qc_outcome =>
    {"mqc_outcome"=>"Rejected final","timestamp"=>"2018-06-03T12:53:46+0000","username"=>"robo_qc"},
    pass => 0,
    path => 't/data'
  };
  throws_ok {$schema->resultset($table)->create($values)}
    qr/NOT NULL constraint failed/,
    'composition foreign key is needed - error on insert';
};

subtest 'insert a basic record, do not allow incomplete data in update' => sub {
  plan tests => 11;

  my $id_seq_composition = t::autoqc_util::find_or_save_composition(
                $schema, {'id_run'    => 1111,
                          'position'  => 1,
                          'tag_index' => 8});
  my $values = {
    evaluation_results => {},
    criteria           => {},
    qc_outcome         => {},
    id_seq_composition => $id_seq_composition,
    comments           => 'Cannot run, returning early'
  };

  my $new;
  lives_ok { $new = $schema->resultset($table)->create($values) }
    'can create a simple record';
  ok ($new->in_storage, 'row has been saved');
  is ($new->comments, 'Cannot run, returning early', 'comments saved');
  is ($new->id_review_criteria, undef, 'criteria foreign key is not set');

  $values = {
    evaluation_results => {},
    criteria           => {},
    qc_outcome         => {},
    id_seq_composition => $id_seq_composition,
    comments           => 'Cannot run again, returning early'
  };
  lives_ok { $new = $new->update($values) }
    'can update a simple record';
  is ($new->comments, 'Cannot run again, returning early', 'comments saved');
  is ($new->id_review_criteria, undef, 'criteria foreign key is not set');
  is ($new->library_type, undef, 'library type undefined');
  is ($new->criteria, undef, 'criteria undefined');

  $values = {
    id_seq_composition => $id_seq_composition,
    evaluation_results => {"e1"=>1,"e2"=>0},
    criteria           => {"and"=>["e1","e2"]},
    pass               => 0,
    path               => 't/data'
  };
  throws_ok {$new->update($values)}
    qr/Evaluation results present, but library_type absent/,
    'library type is not defined - error on update';

  $values = {
    id_seq_composition => $id_seq_composition,
    library_type       => 'common_type',
    criteria           => {},
    evaluation_results => {"e1"=>1,"e2"=>0},
    pass               => 0,
  };
  throws_ok {$new->update($values)}
    qr/Evaluation results present, but criteria absent/,
    'criteria are not defined - error on update';

  $new->delete();
};

subtest 'a full insert/update record' => sub {
  plan tests => 78;

  my $id_seq_composition = t::autoqc_util::find_or_save_composition(
                $schema, {'id_run'    => 1111,
                          'position'  => 1,
                          'tag_index' => 1});

  my $mqc_rs = $schema->resultset($mqc_table)->search({id_seq_composition => $id_seq_composition});
  is ($mqc_rs->count, 0, 'no mqc records for this entity');
  my $rs = $schema->resultset($table)->search({id_seq_composition => $id_seq_composition});
  is ($rs->count, 0, 'no review records for this entity');
  is ($schema->resultset($c_table)->search({})->count, 0,
    'no records in the criteria table');


  my $qc_outcome = {"mqc_outcome" => "Rejected preliminary",
                    "timestamp"   => "2018-06-03T12:53:46+0000",
                    "username"    => "robo_qc"};
  my $values = {
    id_seq_composition => $id_seq_composition,
    library_type       => 'common_type',
    evaluation_results => {"e1"=>1,"e2"=>0},
    criteria           => {"and"=>["e1","e2"]},
    qc_outcome         => $qc_outcome,
    pass => 0,
    path => 't/data'
  };

  isa_ok($schema->resultset($table)->create($values),
    'npg_qc::Schema::Result::' . $table);

  my $cmd5 = md5_hex(JSON::XS->new()->canonical(1)->encode($values->{criteria}));
  my $c_rs = $schema->resultset($c_table)->search({});
  is ($c_rs->count, 1, 'one criteria record is created');
  my $c_row = $c_rs->next;
  is ($c_row->library_type, 'common_type', 'correct library_type');
  is_deeply ($c_row->criteria, {"and"=>["e1","e2"]}, 'correct criteria');
  is ($c_row->checksum, $cmd5, 'correct checksum');
  my $c_dt = $c_row->created_on;
  isa_ok ($c_dt, 'DateTime', 'timestamp is set');

  $rs = $schema->resultset($table)->search({id_seq_composition => $id_seq_composition});
  is ($rs->count, 1, 'one row created in the review table');
  my $row = $rs->next;
  is_deeply ($row->qc_outcome, $qc_outcome, 'qc outcome saved');
  is_deeply ($row->evaluation_results, {"e1"=>1,"e2"=>0}, 'evaluation results saved');
  is ($row->id_review_criteria, $c_row->id_review_criteria, 'foreign key is set correctly');

  $mqc_rs = $schema->resultset($mqc_table)->search({id_seq_composition => $id_seq_composition});
  is ($mqc_rs->count, 1, 'one row created in the mqc table');
  my $outcome = $mqc_rs->next;
  is ($outcome->description, 'Rejected preliminary', 'correct mqc outcome');
  is ($outcome->modified_by, $ENV{USER}, 'correct user');
  is ($outcome->username, 'robo_qc', 'correct user');
  my $dt = $outcome->last_modified();
  is ($dt->year, 2018, 'correct year');
  is ($dt->month, '6', 'correct month');
  is ($dt->minute, '53', 'correct minute');
  is ($dt->second, '46', 'correct second');
 
  
  $qc_outcome = {"mqc_outcome" => "Rejected preliminary",
                 "timestamp"   => "2018-05-04T12:53:46+0000",
                 "username"    => "robo_qc"};
  $values = {
    id_seq_composition => $id_seq_composition,
    library_type       => 'common_type',
    evaluation_results => {"e1"=>0,"e2"=>0},
    criteria           => {"and"=>["e1","e2"]},
    qc_outcome         => $qc_outcome,
  };
  $row->update($values);

  $c_rs = $schema->resultset($c_table)->search({});
  is ($c_rs->count, 1, 'one criteria record is available');
  $c_row = $c_rs->next;
  is ($c_row->library_type, 'common_type', 'correct library_type');
  is_deeply ($c_row->criteria, {"and"=>["e1","e2"]}, 'correct criteria');
  is ($c_row->checksum, $cmd5, 'correct checksum');
  is (DateTime->compare($c_dt, $c_row->created_on), 0, 'timestamp has not changed');

  is_deeply ($row->evaluation_results, {"e1"=>0,"e2"=>0}, 'evaluation results updated');
  is_deeply ($row->qc_outcome, $qc_outcome, 'qc outcome updated');
  $outcome = $schema->resultset($mqc_table)->search({id_seq_composition => $id_seq_composition})
                    ->next;
  is ($outcome->description, 'Rejected preliminary', 'mqc outcome description has not changed');
  is ($outcome->last_modified()->month, 6, 'month not updated');
  is ($outcome->last_modified()->year, 2018, 'correct year');
  is ($row->id_review_criteria, $c_row->id_review_criteria,
    'foreign key value has not changed');


  $qc_outcome = {"mqc_outcome" => "Accepted preliminary",
                 "timestamp"   => "2018-08-05T12:53:46+0000",
                 "username"    => "robo_qc"};
  $values = {
    id_seq_composition => $id_seq_composition,
    library_type       => 'common_type',
    evaluation_results => {"e1"=>1,"e2"=>1},
    criteria           => {"and"=>["e1","e2"]},
    qc_outcome         => $qc_outcome,
  };
  $row->update($values);
  is_deeply ($row->evaluation_results, {"e1"=>1,"e2"=>1}, 'evaluation results updated');
  is_deeply ($row->qc_outcome, $qc_outcome, 'qc outcome updated');
  $outcome = $schema->resultset($mqc_table)->search({id_seq_composition => $id_seq_composition})
                    ->next;
  is ($outcome->description, 'Accepted preliminary', 'mqc outcome updated');
  is ($outcome->last_modified()->month, 8, 'month updated');
  is ($outcome->last_modified()->year, 2018, 'correct year');


  $qc_outcome = {"mqc_outcome" => "Accepted final",
                 "timestamp"   => "2018-03-07T12:53:46+0000",
                 "username"    => "robo_qc"};
  $values = {
    id_seq_composition => $id_seq_composition,
    library_type       => 'common_type',
    evaluation_results => {"e1"=>1,"e2"=>1},
    criteria           => {"or"=>["e1","e2"]},
    qc_outcome         => $qc_outcome,
  };
  $cmd5 = md5_hex(JSON::XS->new()->canonical(1)->encode($values->{criteria}));
  $row->update($values);

  my @rows = $schema->resultset($c_table)->search({})->all;
  is (scalar @rows, 2, 'one more criteria record is created');
  @rows = grep { $_->id_review_criteria == 2 } @rows;
  $c_row = $rows[0];
  is ($c_row->library_type, 'common_type', 'correct library_type');
  is_deeply ($c_row->criteria, {"or"=>["e1","e2"]}, 'correct criteria');
  is ($c_row->checksum, $cmd5, 'correct checksum');

  is_deeply ($row->evaluation_results, {"e1"=>1,"e2"=>1}, 'evaluation results has not changed');
  is_deeply ($row->qc_outcome, $qc_outcome, 'qc outcome updated');
  is ($row->id_review_criteria, $c_row->id_review_criteria, 'criteria foreign key is updated');

  $outcome = $schema->resultset($mqc_table)
    ->search({id_seq_composition => $id_seq_composition})->next;
  is ($outcome->description, 'Accepted final', 'mqc outcome updated');
  is ($outcome->last_modified()->month, 3, 'month updated');
  is ($outcome->last_modified()->year, 2018, 'correct year');


  $qc_outcome = {"mqc_outcome" => "Rejected preliminary",
                 "timestamp"   => "2018-10-04T12:53:46+0000",
                 "username"    => "robo_qc"};
  $values = {
    id_seq_composition => $id_seq_composition,
    library_type       => 'common_type',
    evaluation_results => {"e1"=>0,"e2"=>1},
    criteria           => {"and"=>["e1","e2"]},
    qc_outcome         => $qc_outcome,
  };
  $row->update($values);

  $c_rs = $schema->resultset($c_table)->search({});
  is ($c_rs->count, 2, 'a new criteria record is not created');

  is_deeply ($row->evaluation_results, {"e1"=>0,"e2"=>1}, 'evaluation results has updated');
  is_deeply ($row->qc_outcome, $qc_outcome, 'qc outcome updated');
  $outcome = $schema->resultset($mqc_table)
    ->search({id_seq_composition => $id_seq_composition})->next;
  is ($outcome->description, 'Accepted final', 'mqc outcome not updated');
  is ($outcome->last_modified()->month, 3, 'month not updated');
  is ($outcome->last_modified()->year, 2018, 'correct year');


  $id_seq_composition = t::autoqc_util::find_or_save_composition(
                $schema, {'id_run'    => 1111,
                          'position'  => 1,
                          'tag_index' => 2});
  $mqc_rs = $schema->resultset($mqc_table)->search({id_seq_composition => $id_seq_composition});
  is ($mqc_rs->count, 0, 'no mqc records for this entity');
  my $new_mqc = $schema->resultset($mqc_table)
                ->new_result({id_seq_composition => $id_seq_composition});
  $new_mqc->update_outcome({mqc_outcome => 'Accepted preliminary'}, 'user1', 'test');
  $mqc_rs = $schema->resultset($mqc_table)->search({id_seq_composition => $id_seq_composition});
  is ($mqc_rs->count, 1, 'record created');

  $values = {
    id_seq_composition => $id_seq_composition,
    library_type       => 'common_type',
    evaluation_results => {"e1"=>1,"e2"=>1},
    criteria           => {"or"=>["e1","e2"]},
    qc_outcome => {"mqc_outcome"=>"Accepted final",
                   "timestamp"=>"2018-09-03T12:58:43+0000",
                   "username"=>"robo_qc"},
    pass => 1,
    path => 't/data'
  };
  my $created=$schema->resultset($table)->create($values);

  $c_rs = $schema->resultset($c_table)->search({});
  is ($c_rs->count, 2, 'a new criteria record is not created');

  $rs = $schema->resultset($table)->search({});
  is ($rs->count, 2, q[two rows in the table]);
  is ($created->id_review_criteria, $c_row->id_review_criteria,
    'criteria foreign key is set correctly');
  is ($created->library_type, 'common_type',
    'library type method returns correct value');
  is_deeply ($created->criteria, {"or"=>["e1","e2"]},
    'criteria method returns correct value');
  
  $mqc_rs = $schema->resultset($mqc_table)->search({id_seq_composition => $id_seq_composition});
  is ($mqc_rs->count, 1, 'one mqc record for the entity');
  $outcome = $mqc_rs->next;
  is ($outcome->description, 'Accepted final', 'correct outcome');
  is ($outcome->modified_by, $ENV{USER}, 'correct user');
  is ($outcome->username, 'robo_qc', 'correct user');
  $dt = $outcome->last_modified();
  is ($dt->year, 2018, 'correct year');
  is ($dt->month, '9', 'correct month');
  is ($dt->minute, '58', 'correct minute');
  is ($dt->second, '43', 'correct second');


  $values = {
    id_seq_composition => $id_seq_composition,
    library_type       => 'other_common_type',
    evaluation_results => {"e1"=>1,"e2"=>1},
    criteria           => {"or"=>["e1","e2"]},
    qc_outcome => {"mqc_outcome"=>"Rejected final",
                   "timestamp"=>"2018-10-03T12:58:43+0000",
                   "username"=>"robo_qc"},
    pass => 1,
    path => 't/data'
  }; 

  throws_ok { $schema->resultset($table)->update_or_create($values) }
    qr/Not saving review result. Final outcome cannot be updated/,
    'error since both the existing and the new mqc outcome are final';
  $rs = $schema->resultset($table)
    ->search({id_seq_composition => $id_seq_composition});
  is ($rs->count, 1, 'one result for this entity');
  $rs = $schema->resultset($mqc_table)
    ->search({id_seq_composition => $id_seq_composition});
  is ($rs->count, 1, 'one result for this entity');
  is ($rs->next->description, 'Accepted final', 'outcome has not changed');


  $values = {
    id_seq_composition => $id_seq_composition,
    library_type       => 'other_common_type',
    evaluation_results => {"e1"=>1,"e2"=>1},
    criteria           => {"or"=>["e1","e2"]},
    qc_outcome => {"mqc_outcome"=>"Rejected preliminary",
                   "timestamp"=>"2018-10-03T12:58:43+0000",
                   "username"=>"robo_qc"},
    pass => 1,
    path => 't/data'
  };

  my $updated = $schema->resultset($table)->update_or_create($values);

  $c_rs = $schema->resultset($c_table)->search({});
  is ($c_rs->count, 3, 'a new criteria record is created');
  $c_rs = $c_rs->search({checksum => $cmd5});
  is ($c_rs->count, 2, 'two records for "or" criteria');
  $c_rs = $c_rs->search({library_type => 'other_common_type'});
  is ($c_rs->count, 1, 'one record for other_common_type lib type');
  is ($updated->id_review_criteria, $c_rs->next->id_review_criteria,
    'criteria foreign key is set correctly');
  is ($updated->library_type, 'other_common_type',
    'library type method returns correct value');
  is_deeply ($updated->criteria, {"or"=>["e1","e2"]},
    'criteria method returns correct value');
};

1;

#########
# Author:        gq1
# Maintainer:    $Author$
# Created:       2008-12-05
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

use strict;
use warnings;
use Test::More tests => 22;
use Test::Exception;

use_ok('npg_qc::illumina::loader::Run_Timeline');

#sqlite db is used for testing
my $npg_schema = Moose::Meta::Class->create_anon_class(roles => [qw/npg_testing::db/])->new_object()->create_test_db(q[npg_tracking::Schema], q[t/data/api_dbic_fixtures/npg]);
my $npg_qc_schema = Moose::Meta::Class->create_anon_class(roles => [qw/npg_testing::db/])->new_object()->create_test_db(q[npg_qc::Schema], q[t/data/api_dbic_fixtures/npg_qc]);

sub run_saved_correctly {
  my $id_run = shift;
  if (!$id_run) { die 'Run id is needed';}
  my $row = $npg_qc_schema->resultset('RunTimeline')->find({id_run => $id_run});
  ok($row, "row for run $id_run is present in npg_qc database");
  is($row->get_column('start_time'), q{2009-07-12 12:33:11}, 'correct start time'); #id_run_status_dict="1" 'run pending'
  is($row->get_column('complete_time'), q{2009-07-16 05:04:24}, 'correct complete time'); #id_run_status_dict="4" 'run complete'
  is($row->get_column('end_time'), q{2009-07-16 05:16:28}, 'correct end time'); #id_run_status_dict="11" 'run mirrored'
  $row->delete();
  return; 
}

{
  my $run_timeline_obj = npg_qc::illumina::loader::Run_Timeline->new(
      _min_id_run => 6500,
      schema_npg_tracking => $npg_schema,
      schema => $npg_qc_schema);
  isa_ok($run_timeline_obj, 'npg_qc::illumina::loader::Run_Timeline');
  throws_ok { $run_timeline_obj->_save_run_timeline() } qr/Run\ id\ should\ be\ defined/,
    'croak since to db schema object is passed';
  lives_ok {$run_timeline_obj->_save_run_timeline(3323);}
    'no croak for getting run time line data from npg and save to database';
  run_saved_correctly(3323);
}

{
  my $run_timeline_obj = npg_qc::illumina::loader::Run_Timeline->new(
      _min_id_run => 6500,
      schema_npg_tracking => $npg_schema, 
      schema => $npg_qc_schema);

  is(join(q[ ], @{$run_timeline_obj->_runs_with_timeline}), 6600, 'run 6600 is already available');
  is(join(q[ ], @{$run_timeline_obj->_runs2load}), 6965, 'run 6965 to load');

  lives_ok {$run_timeline_obj->save_dates()} 'no croak saving dates for three runs';
  my @rows = $npg_qc_schema->resultset('RunTimeline')->search({})->all();
  is (scalar @rows, 2, 'one run saved as one is too old and one is already saved');

  is($rows[0]->id_run, 6600, 'first record is for run 6600');
  is($rows[1]->id_run, 6965, 'second record is for run 6956');
  is($rows[1]->get_column('start_time'), undef, 'start time undefined');
  is($rows[1]->get_column('complete_time'), q{2009-11-02 09:35:50}, 'correct complete time');
  is($rows[1]->get_column('end_time'), undef, 'end time undefined');
  $rows[1]->delete;
}

{
  my $id_run = 3323;
  my $run_timeline_obj = npg_qc::illumina::loader::Run_Timeline->new(
                    _min_id_run => 6500,
                    schema_npg_tracking => $npg_schema,
                    schema => $npg_qc_schema,
                    id_run => [$id_run]);
  lives_ok {$run_timeline_obj->save_dates()} 'no croak saving dates for a nominated run';
  run_saved_correctly($id_run);
}

1;

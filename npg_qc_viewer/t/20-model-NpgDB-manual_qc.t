use strict;
use warnings;
use Test::More tests => 38;
use Test::Exception;
use File::Temp qw(tempdir);
use t::util;
use DateTime;

BEGIN { use_ok 'npg_qc_viewer::Model::NpgDB' }

my $util = t::util->new();
my $schema_package = q[npg_tracking::Schema];
my $fixtures_path = q[t/data/fixtures/npg];
my $tmpdbfilename = tempdir(
    DIR => q{/tmp},
    CLEANUP => 1,
) . q{/npg_tracking_dbic};

my $schema;

lives_ok{ $schema = $util->create_test_db($schema_package, $fixtures_path, $tmpdbfilename) } 'test db created and populated';

my $m;
lives_ok {
  $m = npg_qc_viewer::Model::NpgDB->new( connect_info => {
                               dsn      => ('dbi:SQLite:'.$tmpdbfilename),
                               user     => q(),
                               password => q()
                                                               })
} 'create new model object';

isa_ok($m, 'npg_qc_viewer::Model::NpgDB');


{
  throws_ok {$m->log_manual_qc_action} qr/values hash should be defined/, 'error in manual qc logging';
  throws_ok {$m->log_manual_qc_action({})} qr/user should be set/, 'error in manual qc logging';
  throws_ok {$m->log_manual_qc_action({user => q[pipeline],})} 
             qr/no lims object id/, 'error in manual qc logging';
  throws_ok {$m->log_manual_qc_action({user => q[pipeline],lims_object_id => 2,})}
             qr/no lims object type/, 'error in manual qc logging';
  throws_ok {$m->log_manual_qc_action({user => q[pipeline],lims_object_id => 2, lims_object_type => q[lib], })}
             qr/no qc status/, 'error in manual qc logging';
  throws_ok {$m->log_manual_qc_action({user => q[pipeline],lims_object_id => 2, lims_object_type => q[lib], status => 22, })}
             qr/invalid status value 22/, 'error in manual qc logging';
}

{
    my $table = q(ManualQcStatus);
    my $rs=$m->resultset($table);
    ok (defined $rs, "ManualQcStatus resultset");
    ok (!$rs->count, "ManualQcStatus resultset does not have data");

    my $referer = q[http://sfweb.my_checks:1959/checks];
    my $values = {  user => q[mg8],
                    status => 1,
                    lims_object_id => 12, 
                    lims_object_type => q[lib], 
                    referer => $referer,
                    batch_id => 4965,
                    position => 8,
                 };
    my $first_row_id;
    lives_ok {$first_row_id = $m->log_manual_qc_action($values)} 'creating an mqc status row is ok';
    $rs = $m->resultset($table);
    is ($first_row_id, 1, 'first row id is 1');
    is($rs->count, 1, 'one row has been created');
    my $row = $rs->next;
    is($row->iscurrent, 1, 'is current flag is set');
    ok($row->date, 'time has been set');
    is($row->referer, $referer, 'referer is logged');

    my $second_row_id;
    lives_ok {$second_row_id = $m->log_manual_qc_action($values)} 'creating a second mqc status row is ok';
    is ($second_row_id, 2, 'second row id is 2');
    is($row->iscurrent, 1, 'is current flag is set for the new row');
    $rs = $m->resultset($table);
    is($rs->count, 2, 'two rows now');
    
    is($rs->find({id_manual_qc_status => $first_row_id})->iscurrent, 0, 'previous row is not current any more');

    my $d1 = DateTime->now();
    sleep 1;

    $values->{lims_object_type} = q[lane];
    my $third_row_id;
    lives_ok {$third_row_id = $m->log_manual_qc_action($values)} 'creating an mqc status row is ok';
    is($rs->count, 3, '3 rows now');
    is($rs->find({id_manual_qc_status => $first_row_id})->iscurrent, 0, 'first row is not current');
    is($rs->find({id_manual_qc_status => $second_row_id})->iscurrent, 1, 'second row is current');
    
    my $third_row = $rs->find({id_manual_qc_status => $third_row_id});
    is($third_row->iscurrent, 1, 'third row is current');
    is($third_row->position, 8, 'third row position');
    is($third_row->batch_id, 4965, 'third row batch id');
    is($third_row->lims_object_id, 12, 'third row object id');
    is($third_row->referer, $referer, 'third row referer');
    is($third_row->lims_object_type, q[lane], 'third row object type');
    my $date = $third_row->date;
    sleep 1;
    my $d2 = DateTime->now();
    ok ($date->subtract_datetime($d1)->seconds >=1 && $d2->subtract_datetime($date)->seconds,
        'logged time is in the right time interval');
}

{
  my $run = $m->resultset( q{Run} )->find(4025);
  foreach my $rs ( $run->run_statuses() ) {
    $rs->iscurrent( 0 );
    $rs->update();
  }
  $run->related_resultset( q{run_statuses} )->create({
    id_user => 1,
    date => DateTime->now(),
    id_run_status_dict => 19,
    iscurrent => 1,
  });
  lives_ok{
    $m->update_lane_manual_qc_complete(4025, 1, 1, q{pipeline});
  } q{updated lane status for position 1 ok};

  is( $run->current_run_status_description(), q{qc review pending},
    q{not yet updated to archival pending, as not all lanes yet manual qc complete} );

  lives_ok{
    foreach my $position ( 2..8 ) {
      $m->update_lane_manual_qc_complete(4025, $position, 1, q{pipeline});
    }
  } q{updated lane status for remaining positions ok};
  is( $run->current_run_status_description(), q{archival pending},
    q{updated to archival pending, as all lanes are manual qc complete} );
}

1;




use strict;
use warnings;
use Test::More tests => 15;
use Test::Exception;
use File::Temp qw(tempfile);
use DateTime;
use t::util;

BEGIN { use_ok 'npg_qc_viewer::Model::NpgDB' }

my $util = t::util->new();
my $schema_package = q[npg_tracking::Schema];
my $fixtures_path = q[t/data/fixtures/npg];
my ($fh,$tmpdbfilename) = tempfile(UNLINK => 1);
my $schema;

lives_ok{ $schema = $util->create_test_db(
  $schema_package, $fixtures_path, $tmpdbfilename) }
  'test db created and populated';

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
  is($m->run_annotations(4025)->count, 3, '3 run annotations for run 4025');
  is($m->run_annotations(6400)->count, 9, '9 run annotations for run 6400');
}

{
  is($m->runlane_annotations(4025)->count, 0, 'no runlane annotations for run 4025');
  my $a = $m->runlane_annotations(6400);
  is($a->count, 7, '7 runlane annotations for run 6400');
  is($a->next->run_lane->position, 2, 'first annotation for lane 2');
  is($a->next->run_lane->position, 6, 'second annotation for lane 6');
  is($a->next->run_lane->position, 6, 'third annotation for lane 6');
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
    $m->update_lane_manual_qc_complete(4025, 1, q{pipeline});
  } q{updated lane status for position 1 ok};

  is( $run->current_run_status_description(), q{qc review pending},
    q{not yet updated to archival pending, as not all lanes yet manual qc complete} );

  lives_ok{
    foreach my $position ( 2..8 ) {
      $m->update_lane_manual_qc_complete(4025, $position, q{pipeline});
    }
  } q{updated lane status for remaining positions ok};
  is( $run->current_run_status_description(), q{archival pending},
    q{updated to archival pending, as all lanes are manual qc complete} );
}

1;



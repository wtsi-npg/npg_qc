use strict;
use warnings;
use Test::More tests => 49;
use Test::Exception;
use Test::Warn;
use File::Temp qw/tempdir/;

local $ENV{'HOME'};
use npg_testing::db;
use npg_qc::autoqc::qc_store::options qw/$ALL $LANES $PLEXES/;
use npg_qc::autoqc::qc_store::query;

BEGIN { 
  $ENV{'HOME'} = q[t/data];
  use_ok 'npg_qc::autoqc::qc_store'
};

my $schema = Moose::Meta::Class->create_anon_class(
           roles => [qw/npg_testing::db/])
           ->new_object({})->create_test_db(
             q[npg_qc::Schema], 't/data/fixtures');

{
  local $ENV{dev} = q[non-existing];

  my $s;
  lives_ok {$s = npg_qc::autoqc::qc_store->new(use_db => 0);}
    'database access not needed - no error without schema';
  isa_ok($s, 'npg_qc::autoqc::qc_store');
  ok(!$s->qc_schema, 'schema object not built');
  my $result;
  warning_like {$result = $s->run_from_db(npg_qc::autoqc::qc_store::query->new(id_run=>45))}
    qr/npg_qc::autoqc::qc_store object is configured not to use the database/,
    'warning that the database is not used'; 
  ok ($result->is_empty, 'empty collection returned');

  throws_ok {$s->run_from_db()} qr/Query argument should be defined/,
    'query should be defined in run_from_db';

  lives_ok {$s = npg_qc::autoqc::qc_store->new(use_db => 1)} 'object created';
  dies_ok {$s->schema} '... but failes to build the db connection';
  lives_ok {npg_qc::autoqc::qc_store->new(use_db => 1, qc_schema => $schema)}
    'no error when use_db is true and db connection supplied';
}

{
  my $model =  npg_qc::autoqc::qc_store->new(use_db => 0);
  throws_ok {$model->load_run()} qr/Attribute \(id_run\) does not pass the type constraint/,
    'error loading run when id_run is not set';

  local $ENV{dev} = q[non-existing];
  local $ENV{TEST_DIR} = q[t/data];
  my $collection;
  warning_like {$collection = $model->load_run(1234)}
    qr/Unable to connect to NPG tracking DB for faster globs/,
    q[warning about tracking db being not accessible with $ENV{dev} set to 'non-existing'];
  is($collection->size(), 16, 'number of qc results from staging when the db is not used');
}

{
  local $ENV{dev} = q[non-existing];
  local $ENV{TEST_DIR} = q[t];
  my $model =  npg_qc::autoqc::qc_store->new(use_db  => 0,);
  my $collection;
  warnings_like {$collection = $model->load_run(3500); }
    [qr/Unable to connect to NPG tracking DB for faster globs/,
     qr/Error when loading autoqc results from staging: No paths to run folder found/
    ],
    q[$ENV{dev} set to 'non-existing' - warns about problems finding the path];
  is( $collection->size(), 0,
    'no qc_data from database for run 3500 with use_db unset' );  
}

{
  my $temp = tempdir( CLEANUP => 1);
  my $other =  join(q[/], $temp, q[nfs]);
  mkdir $other;
  $other = join(q[/], $other, q[sf44]);
  mkdir $other;

  `cp -R t/data/nfs/sf44/IL2  $other`;
  my $archive = join q[/], $other, 
                q[IL2/analysis/123456_IL2_1234/Data/Intensities/Bustard_RTA/PB_cal/archive];
  mkdir join q[/], $archive, 'lane1';
  mkdir join q[/], $archive, 'lane2';
  mkdir join q[/], $archive, 'lane2', 'qc';
  mkdir join q[/], $archive, 'lane3';
  my $lqc = join q[/], $archive, 'lane3', 'qc';
  mkdir $lqc;
  my $file = join q[/], $archive, 'qc', '1234_3.insert_size.json';
  `cp $file $lqc`;
  mkdir join q[/], $archive, 'lane4';
  $lqc = join q[/], $archive, 'lane4', 'qc';
  mkdir $lqc;
  $file = join q[/], $archive, 'qc', '1234_4.insert_size.json';
  `cp $file $lqc`;

  local $ENV{TEST_DIR} = $temp;
  local $ENV{dev} = q[non-existing];
  my $message = q[warning about tracking db being not accessible with $ENV{dev} set to 'non-existing'];
  my $w = q[Unable to connect to NPG tracking DB for faster globs];

  my $id_run = 1234;

  my $s = npg_qc::autoqc::qc_store->new(use_db => 0);
  my $c;
  warning_like {$c = $s->load_run($id_run);}  qr/$w/, $message;
  is ($c->size, 16, 'loading main qc results only');
  
  warning_like {$c = $s->load_run($id_run, 0, undef, $PLEXES);}  qr/$w/, $message;
  is ($c->size, 2, 'loading autoqc for plexes only');

  warning_like {$c = $s->load_run($id_run, 0, [1,4,6], $PLEXES);}  qr/$w/, $message;
  is ($c->size, 1, 'loading autoqc for plexes only for 3 lanes');

  warning_like {$c = $s->load_run($id_run, 0, [1,6], $PLEXES);}  qr/$w/, $message;
  is ($c->size, 0, 'loading autoqc for plexes only for 2 lanes, one empty, one no-existing');

  warning_like {$c = $s->load_run($id_run, 0, [1,6], $ALL);}  qr/$w/, $message;
  is ($c->size, 4, 'loading all autoqc including plexes  for 2 lanes, for plexes one empty, one no-existing');

  warning_like {$c = $s->load_run($id_run, 0,  [4], $ALL);}  qr/$w/, $message;
  is ($c->size, 3, 'loading all autoqc including plexes  for 1 lane');

  warning_like {$c = $s->load_run($id_run, 0, [], $ALL);}  qr/$w/, $message;
  is ($c->size, 18, 'loading all autoqc');
}

{ 
  my $model = npg_qc::autoqc::qc_store->new(use_db => 1, qc_schema => $schema);
  local $ENV{TEST_DIR} = q[t/data];
  my $collection = $model->load(
    npg_qc::autoqc::qc_store::query->new(id_run => 1234,
      npg_tracking_schema => undef, propagate_npg_tracking_schema => 1));
  is($collection->size(), 16, 'number of qc results from staging when the db is used');
}

{
  local $ENV{TEST_DIR} = q[t];

  my $model =  npg_qc::autoqc::qc_store->new(use_db => 1, qc_schema => $schema);
  my $w = q[Error when loading autoqc results from staging: No paths to run folder found];
  my $q =  npg_qc::autoqc::qc_store::query->new(
      id_run => 3500, db_qcresults_lookup => 0, npg_tracking_schema => undef, propagate_npg_tracking_schema => 1);

  my $collection;
  warning_like {$collection = $model->load($q)} qr/$w/,
    'warning of the error during loading qc results from staging';
  is( $collection->size(), 0,
    'no qc_data from database for run 3500 with db flag set but overridden in the method' );
}

{
  $schema->resultset('QXYield')->create({id_run=>3510,position=>4,tag_index=>-1,threshold_quality=>40,});
  $schema->resultset('QXYield')->create({id_run=>3510,position=>5,tag_index=>-1,threshold_quality=>40,});
  $schema->resultset('InsertSize')->create({id_run=>3510,position=>1,tag_index=>-1});

  local $ENV{TEST_DIR} = q[t/data];
  my $model = npg_qc::autoqc::qc_store->new(use_db => 1, qc_schema => $schema);
  my $db_lookup = 1;
  
  my $run_lanes = {3500 => [1],};
  is($model->load_lanes($run_lanes, $db_lookup)->size(), 8,
    'db retrieval for run 3500 lane 1');
  
  $run_lanes = {3500 => [2,4],};
  my $c;
  warning_like {$c=$model->load_lanes($run_lanes, $db_lookup)}
    qr/Error when loading autoqc results from staging: No paths to run folder found/,
    'absence of db results triggers a search on staging - warns about failure on staging';
  is($c->size(), 0,
    'db retrieval for run 3500 lane 2,4 (none exists)');

  $run_lanes = {3500 => [1,2],};
  is($model->load_lanes($run_lanes, $db_lookup)->size(), 8,
    'db retrieval for run 3500 lane 1,2 (only 1 exists)');

  $run_lanes = {3510 => [1,5,4],};
  is($model->load_lanes($run_lanes, $db_lookup)->size(), 3,
    'db retrieval for run 3510 lane 1,4,5 (all exist)');

  $run_lanes = {3500 => [1,2], 3510 => [1,5,4,8] };
  is($model->load_lanes($run_lanes, $db_lookup)->size(), 11,
    'db retrieval for 2 runs, some positions do not exist');

  $run_lanes = {3500 => [1,2], 3510 => [1,5,4,8], 1234 => [8] };
  is($model->load_lanes($run_lanes, $db_lookup)->size(), 13,
    'db+staging retrieval for 3 runs, some positions do not exist');
}

{
  my $model =  npg_qc::autoqc::qc_store->new(use_db => 0);
  my $collection = $model->load_from_path('t/data/autoqc/rendered/json_paired_run');
  is( $collection->size(), 16, 'loading 16 results from path' );
  $collection = $model->load_from_path('t/data/autoqc/rendered/json_paired_run', 't/data/autoqc/rendered/json_paired_run');
  is( $collection->size(), 32, 'loading 16 results from path' );
  $collection = $model->load_from_path(('t/data/autoqc/rendered/json_paired_run', 't/data/autoqc/rendered/json_paired_run'));
  is( $collection->size(), 32, 'loading 16 results from path' ); 
}

{
  my $model =  npg_qc::autoqc::qc_store->new(use_db => 1, qc_schema => $schema);

  my $collection = $model->load_run(3600);
  is( $collection->size(), 4, '4 lane results from the db' ); 
  $collection = $model->load_run(3600, 1, []);
  is( $collection->size(), 4, '4 lane results from the db' );
  $collection = $model->load_run(3600, 1, [], $LANES);
  is( $collection->size(), 4, '4 lane results from the db' );
  $collection = $model->load_run(3600, 1, [], $ALL);
  is( $collection->size(), 10, '10 lane results from the db' );
  $collection = $model->load_run(3600, 1, [], $PLEXES);
  is( $collection->size(), 6, '6 plex results from the db' );
  $collection = $model->load_run(3600, 1, [4], $PLEXES);
  is( $collection->size(), 3, '3 plex lane 4 results from the db' );
  $collection = $model->load_run(3600, 1, [4], $ALL);
  is( $collection->size(), 4, '4 results from the db' );
}

1;

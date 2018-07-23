use strict;
use warnings;
use Test::More tests => 5;
use Test::Exception;
use Test::Warn;
use File::Temp qw/tempdir/;
use Archive::Extract;
use Moose::Meta::Class;
use File::Copy qw/cp/;

use npg_testing::db;
use npg_qc::autoqc::qc_store::options qw/$ALL $LANES $PLEXES/;
use npg_qc::autoqc::qc_store::query;
use npg_qc::autoqc::db_loader;
use npg_tracking::glossary::composition::factory;
use npg_tracking::glossary::composition::component::illumina;

use t::autoqc_util;

use_ok 'npg_qc::autoqc::qc_store';

my $schema = Moose::Meta::Class->create_anon_class(
           roles => [qw/npg_testing::db/])
           ->new_object({})->create_test_db(q[npg_qc::Schema]);
my $tracking_schema = Moose::Meta::Class->create_anon_class(
           roles => [qw/npg_testing::db/])
           ->new_object({})->create_test_db(
           q[npg_tracking::Schema], q[t/data/fixtures/npg_tracking]);

my $temp = tempdir( CLEANUP => 1);

sub _upload_data2db {
  my $ae = Archive::Extract->new(
      archive => 't/data/fixtures/autoqc_json.tar.gz');
  $ae->extract(to => $temp) or die $ae->error;
  note ("Data to be uploaded to the database:\n" . `find $temp`);

  npg_qc::autoqc::db_loader->new(
    schema => $schema,
    path      => ["${temp}/autoqc_json"],
    verbose   => 0
  )->load();
}

sub _build_query_obj {
  my ($init) = @_;
  $init->{'npg_tracking_schema'} = $tracking_schema;
  return npg_qc::autoqc::qc_store::query->new($init);
}

subtest 'object creation' => sub {
  plan tests => 10;

  my $s = npg_qc::autoqc::qc_store->new(use_db => 0);
  isa_ok($s, 'npg_qc::autoqc::qc_store');
  is($s->qc_schema, undef, 'schema object undefined');
  lives_ok { $s = npg_qc::autoqc::qc_store->new(use_db => 1) }
    'use_db true and not supplying db handler is OK';
  ok(!$s->has_qc_schema, 'qc_schema is not set by the constructor');
  throws_ok { npg_qc::autoqc::qc_store->new(use_db => 1, qc_schema => undef) }
    qr/Incompatible attribute values/,
    'use_db true and supplying undefined db handler is not OK';
  lives_ok {npg_qc::autoqc::qc_store->new(use_db => 1, qc_schema => $schema)}
    'no error when use_db is true and db connection supplied';
  lives_ok {npg_qc::autoqc::qc_store->new(use_db => 0, qc_schema => undef)}
    'no error when use_db is false and db connection explicitly undefined';
  lives_ok {$s = npg_qc::autoqc::qc_store->new(qc_schema => $schema)}
    'ok to just define qc_schema';
  ok ($s->use_db, 'use_db is true by default');
  throws_ok { npg_qc::autoqc::qc_store->new(qc_schema => undef) }
    qr/Incompatible attribute values/,
    'not OK to explicitly undefine schema without unsetting use_db';
};


subtest 'loading data from directories' => sub {
  plan tests => 8;
 
  my $s =  npg_qc::autoqc::qc_store->new(use_db => 0);
  throws_ok { $s->load_from_path() }
    qr/A list of at least one path is required/, 'path should be given';
  throws_ok { $s->load_from_path(qw//) }
    qr/A list of at least one path is required/, 'path should be given';
  my $collection = $s->load_from_path('t/data/autoqc/rendered/json_paired_run');
  is( $collection->size(), 16, 'loading 16 results from path' );
  $collection = $s->load_from_path('t/data/autoqc/rendered/json_paired_run',
                                   't/data/autoqc/rendered/json_paired_run');
  is( $collection->size(), 16, 'loading 16 results from a path given twice');

  my $query = _build_query_obj({id_run => 22});
  throws_ok { $s->load_from_path($query) }
    qr/A list of at least one path is required/, 'path should be given';
  $collection = $s->load_from_path(qw(t/data/autoqc/rendered/json_paired_run), $query);
  is( $collection->size(), 0, 'no results from path - nothing for run 22' );
  $query = _build_query_obj({id_run => 3565});
  $collection = $s->load_from_path(qw(t/data/autoqc/rendered/json_paired_run), $query);
  is( $collection->size(), 16, '16 results for run 3565 from path' ); 
  
  open my $fh, '>', "$temp/bad.json" or die 'cannot open file for writing';
  close $fh;
  throws_ok { $s->load_from_path($temp) } qr//,
    'error reading malformed json';
};

subtest 'loading data from staging' => sub {
  plan tests => 22;
  
  my $id_run = 26294;
  my $rf_name = '180711_HX4_B_HLWFJCCXY';
  my $rfh = t::autoqc_util::create_runfolder($temp, {runfolder_name => $rf_name});
  my $run_row = $tracking_schema->resultset('Run')->find($id_run);
  $run_row or die "Run $id_run is not in test tracking db";
  $run_row->update({folder_name => $rf_name, folder_path_glob => $temp});
  $tracking_schema->resultset('TagRun')->create(
    {id_run  => $id_run,id_tag  => 14,id_user => 1}); # set staging tag

  my $model =  npg_qc::autoqc::qc_store->new(use_db => 0, qc_schema => undef);

  my $query = _build_query_obj({id_run => $id_run});
  my $collection = $model->load($query);
  is( $collection->size(), 0, 'no data in run folder');
  
  my $ar_path = $rfh->{'archive_path'};
  my $qc_dir = join q[/], $ar_path, 'qc';
  mkdir $qc_dir;
  map { cp $_ , $qc_dir } glob 't/data/qc_store/26294/*.json';
  $collection = $model->load($query);
  is($collection->size(), 16, 'number of qc results from staging when db is not used');

  $run_row->update({folder_name => 'other'});
  warnings_exist { $collection = $model->load($query) }
    [qr/No paths to run folder found/], 'warning when run folder is not found';
  is($collection->size(), 0, 'no results - run folder not found');
  $run_row->update({folder_name => $rf_name});

  $model =  npg_qc::autoqc::qc_store->new(qc_schema => $schema, use_db => 1);
  $collection = $model->load($query);
  is($collection->size(), 16, 'number of qc results from staging when db is used');

  $query = _build_query_obj({id_run => $id_run,positions => [2,3]});
  $collection = $model->load($query);
  is($collection->size(), 4, 'selected results for two lanes');

  $query = _build_query_obj({id_run => $id_run,positions => [2,5]});
  $collection = $model->load($query);
  is($collection->size(), 4, 'selected results for two lanes');

  map { unlink $_ } glob "$qc_dir/*5.*.json";
  $query = _build_query_obj({id_run => $id_run});
  $collection = $model->load($query);
  is($collection->size(), 14, 'results for seven lanes');

  $query = _build_query_obj({id_run => $id_run,positions => [2,5]});
  $collection = $model->load($query);
  is($collection->size(), 2, 'results for one lanes');
  $query = _build_query_obj({id_run => $id_run,positions => [5]});
  $collection = $model->load($query);
  is($collection->size(), 0, 'no results');

  $query = _build_query_obj({id_run => $id_run, option => $LANES});
  $collection = $model->load($query);
  is($collection->size(), 14, 'results for seven lanes');

  $query = _build_query_obj({id_run => $id_run, option => $ALL});
  $collection = $model->load($query);
  is($collection->size(), 14, 'results for seven lanes');

  $query = _build_query_obj({id_run => $id_run, positions => [2,3], option => $ALL});
  $collection = $model->load($query);
  is($collection->size(), 4, 'results for two lanes');

  $query = _build_query_obj({id_run => $id_run, positions => [2,3], option => $PLEXES});
  $collection = $model->load($query);
  is($collection->size(), 0, 'no results for plexes');

  mkdir "$ar_path/lane1";
  mkdir "$ar_path/lane2";
  mkdir "$ar_path/lane1/qc";
  mkdir "$ar_path/lane2/qc";
  map { cp $_ , "$ar_path/lane1/qc" } glob 't/data/qc_store/26294/*1.*.json';
  map { cp $_ , "$ar_path/lane2/qc" } glob 't/data/qc_store/26294/*2.*.json';

  $query = _build_query_obj({id_run => $id_run, option => $LANES});
  $collection = $model->load($query);
  is($collection->size(), 14, 'results for seven lanes');

  $query = _build_query_obj({id_run => $id_run, option => $ALL});
  $collection = $model->load($query);
  is($collection->size(), 18, 'results for seven lanes, including two with plexes');

  $query = _build_query_obj({id_run => $id_run, option => $PLEXES});
  $collection = $model->load($query);
  is($collection->size(), 4, 'results for two lanes with plexes');

  $query = _build_query_obj({id_run => $id_run, positions => [1, 2], option => $PLEXES});
  $collection = $model->load($query);
  is($collection->size(), 4, 'results for two lanes with plexes');

  $query = _build_query_obj({id_run => $id_run, positions => [1, 2, 7], option => $PLEXES});
  $collection = $model->load($query);
  is($collection->size(), 4, 'results for two lanes with plexes');

  $query = _build_query_obj({id_run => $id_run, positions => [1, 2, 7], option => $ALL});
  $collection = $model->load($query);
  is($collection->size(), 10, 'results for three lanes, including two with plexes');

  $query = _build_query_obj({id_run => $id_run, positions => [1, 7], option => $ALL});
  $collection = $model->load($query);
  is($collection->size(), 6, 'results for two lanes, including one with plexes');

  $query = _build_query_obj({id_run => $id_run, positions => [3, 7], option => $ALL});
  $collection = $model->load($query);
  is($collection->size(), 4, 'results for two lanes, none with plexes');
};

subtest 'loading data from the database' => sub {
  plan tests => 17;

  my $model =  npg_qc::autoqc::qc_store->new(use_db => 0, qc_schema => undef);
  my $collection;
  warning_like {
    $collection = $model->load_from_db(_build_query_obj({id_run => 45}))
  } qr/npg_qc::autoqc::qc_store object is configured not to use the database/,
    'warning that the database is not used'; 
  ok ($collection->is_empty, 'empty collection returned');

  _upload_data2db();

  $model = npg_qc::autoqc::qc_store->new(use_db => 1, qc_schema => $schema);

  $collection = $model->load(_build_query_obj({id_run => 3600}));
  is( $collection->size(), 4, '4 lane results from the db' );

  warnings_exist {$collection = $model->load(_build_query_obj({id_run => 3600, db_qcresults_lookup => 0})) }
    [qr/Failed to load data from staging/],
    'query db option set to false, doing fs lookup';
  is( $collection->size(), 0, 'no results from the db' );
  $collection = $model->load(_build_query_obj({id_run => 3600, option =>$LANES}));
  is( $collection->size(), 4, '4 lane results from the db' );
  $collection = $model->load(_build_query_obj({id_run => 3600, option =>$ALL}));
  is( $collection->size(), 10, '10 lane results from the db' );
  $collection = $model->load(_build_query_obj({id_run => 3600, option =>$PLEXES}));
  is( $collection->size(), 6, '6 plex results from the db' );
  $collection = $model->load(_build_query_obj({id_run => 3600, positions => [4], option =>$PLEXES}));
  is( $collection->size(), 3, '3 plex lane 4 results from the db' );
  $collection = $model->load(_build_query_obj({id_run => 3600, positions => [4], option =>$ALL}));
  is( $collection->size(), 4, '4 results from the db' );

  my $qrs = $schema->resultset('QXYield');
  my $f = npg_tracking::glossary::composition::factory->new();
  $f->add_component(npg_tracking::glossary::composition::component::illumina->new(
    id_run=>3510, position=>4));
  my $fk_id = $qrs->find_or_create_seq_composition($f->create_composition())
                 ->id_seq_composition();
  $qrs->create({id_run=>3510,position=>4,tag_index=>-1,threshold_quality=>40,id_seq_composition=>$fk_id});
  $f = npg_tracking::glossary::composition::factory->new();
  $f->add_component(npg_tracking::glossary::composition::component::illumina->new(
    id_run=>3510, position=>5));
  $fk_id = $qrs->find_or_create_seq_composition($f->create_composition())
                 ->id_seq_composition();
  $qrs->create({id_run=>3510,position=>5,tag_index=>-1,threshold_quality=>40,id_seq_composition=>$fk_id});
  $f = npg_tracking::glossary::composition::factory->new();
  $f->add_component(npg_tracking::glossary::composition::component::illumina->new(
    id_run=>3510, position=>1));
  $fk_id = $qrs->find_or_create_seq_composition($f->create_composition())
                 ->id_seq_composition();
  $schema->resultset('InsertSize')->create({id_run=>3510,position=>1,tag_index=>-1,id_seq_composition=>$fk_id});

  $model = npg_qc::autoqc::qc_store->new(use_db => 1, qc_schema => $schema);
  my $db_lookup = 1;
  
  my $run_lanes = {3500 => [1]};
  is($model->load_lanes($run_lanes, $db_lookup, undef, $tracking_schema)->size(), 8,
    'db retrieval for run 3500 lane 1');
  
  $run_lanes = {3500 => [2,4]};
  my $c;
  warning_like {$c=$model->load_lanes($run_lanes, $db_lookup, undef, $tracking_schema)}
    qr/Failed to load data from staging/,
    'absence of db results triggers a search on staging - warns about failure on staging';
  is($c->size(), 0,
    'db retrieval for run 3500 lane 2,4 (none exists)');

  $run_lanes = {3500 => [1,2]};
  is($model->load_lanes($run_lanes, $db_lookup, undef, $tracking_schema)->size(), 8,
    'db retrieval for run 3500 lane 1,2 (only 1 exists)');

  $run_lanes = {3510 => [1,5,4]};
  is($model->load_lanes($run_lanes, $db_lookup, undef, $tracking_schema)->size(), 3,
    'db retrieval for run 3510 lane 1,4,5 (all exist)');

  $run_lanes = {3500 => [1,2], 3510 => [1,5,4,8] };
  is($model->load_lanes($run_lanes, $db_lookup, undef, $tracking_schema)->size(), 11,
    'db retrieval for 2 runs, some positions do not exist');

  $run_lanes = {3500 => [1,2], 3510 => [1,5,4,8], 26294 => [8] };
  is($model->load_lanes($run_lanes, $db_lookup, undef, $tracking_schema)->size(), 13,
    'db+staging retrieval for 3 runs, some positions do not exist');
};

1;

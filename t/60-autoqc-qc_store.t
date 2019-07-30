use strict;
use warnings;
use Test::More tests => 9;
use Test::Exception;
use Test::Warn;
use File::Temp qw/tempdir/;
use Archive::Extract;
use Moose::Meta::Class;
use File::Copy qw/cp mv/;
use File::Path qw/make_path remove_tree/;
use List::MoreUtils qw/all none uniq/;

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
  # note ("Data to be uploaded to the database:\n" . `find $temp`);

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

subtest 'deserializing objects from a file' => sub {
  plan tests => 12;

  my $s =  npg_qc::autoqc::qc_store->new(use_db => 0);

  my $file_path = "$temp/my.json";
  throws_ok { $s->json_file2result_object($file_path) }
    qr/Failed converting $file_path/,
    'file does not exist - error';

  my $fh;
  open $fh, '>', $file_path or die "Cannot open $file_path for writing";
  print $fh 'some data' or die "Cannot write to $file_path";
  close $fh;
  throws_ok { $s->json_file2result_object($file_path) }
    qr/Failed converting $file_path/,
    'file exists, but JSON parser fails - error';

  open $fh, '>', $file_path or die "Cannot open $file_path for writing";
  print $fh '{"key":"value"}' or die "Cannot write to $file_path";
  close $fh;
  my $r;
  lives_ok { $r = $s->json_file2result_object($file_path) }
    'JSON with no __CLASS__ key - no failure';
  is ($r, undef, 'return value is undefined');

  open $fh, '>', $file_path or die "Cannot open $file_path for writing";
  print $fh '{"__CLASS__":"some","key":"value"}'
    or die "Cannot write to $file_path";
  close $fh;
  lives_ok { $r = $s->json_file2result_object($file_path) }
    'JSON with random __CLASS__ key - no failure';
  is ($r, undef, 'return value is undefined');

  my $dir = 't/data/autoqc/rendered/json_paired_run';
  $file_path = "$dir/3565_1.insert_size.json";

  $r = $s->json_file2result_object($file_path);
  isa_ok ($r, 'npg_qc::autoqc::results::insert_size');
  is ($r->result_file_path(), $file_path, 'file path attribute is assigned');
  
  $file_path = "$dir/3565_2.qX_yield.json";
  $r = $s->json_file2result_object($file_path);
  isa_ok ($r, 'npg_qc::autoqc::results::qX_yield');
  is ($r->result_file_path(), $file_path, 'file path attribute is assigned');

  $s =  npg_qc::autoqc::qc_store->new(
          use_db => 0,
          checks_list => [qw/insert_size sequence_error/]);
  $r = $s->json_file2result_object($file_path);
  ok (!$r,
    'qX_yield result is not returned since the class name is not in the list');

  $file_path = "$dir/3565_1.insert_size.json";
  $r = $s->json_file2result_object($file_path);
  ok ($r, 'insert_size result is returned since the class name is in the list');
};

subtest 'loading data from directories' => sub {
  plan tests => 9;
 
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

  $collection = $s->load_from_path(qw(t/data/qc_store));
  is($collection->size, 1, 'sequence_summary result is loaded'); 
  
  open my $fh, '>', "$temp/bad.json" or die 'cannot open file for writing';
  close $fh;
  throws_ok { $s->load_from_path($temp) } qr//,
    'error reading malformed json';
};

subtest 'loading data from staging - new style directory structure' => sub {
  plan tests => 18;
  
  my $id_run = 26294;
  my $rf_name = '180711_HX4_B_HLWFJCCXY_NEW';
  my $rfh = t::autoqc_util::create_runfolder($temp, {runfolder_name => $rf_name});
  my $run_row = $tracking_schema->resultset('Run')->find($id_run);
  $run_row or die "Run $id_run is not in test tracking db";
  $run_row->update({folder_name => $rf_name, folder_path_glob => $temp});
  $tracking_schema->resultset('TagRun')->update_or_create(
    {id_run  => $id_run,id_tag  => 14,id_user => 1}); # set staging tag
  
  my $ar_path = $rfh->{'archive_path'};
  my %lane_dirs = map {$_ => join(q[/], $ar_path, 'lane' . $_, 'qc')} (1 .. 8);
  map {make_path $_} values %lane_dirs;
  foreach my $p ((1 .. 8)) {
    map { cp $_ , $lane_dirs{$p} } glob "t/data/qc_store/26294/*${p}.*.json";
  }

  my $model =  npg_qc::autoqc::qc_store->new(qc_schema => $schema, use_db => 0);
  my $query = _build_query_obj({id_run => $id_run});
  my $collection = $model->load($query);
  is($collection->size(), 16, 'number of qc results from staging');

  $query = _build_query_obj({id_run => $id_run,positions => [2,3]});
  $collection = $model->load($query);
  is($collection->size(), 4, 'selected results for two lanes');

  $query = _build_query_obj({id_run => $id_run,positions => [2,5]});
  $collection = $model->load($query);
  is($collection->size(), 4, 'selected results for two lanes');

  remove_tree $lane_dirs{5};

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

  my $plex3_qc = '/../plex3/qc';
  make_path $lane_dirs{1} . $plex3_qc;
  make_path $lane_dirs{2} . $plex3_qc;
  map { cp $_ , $lane_dirs{1} . $plex3_qc } glob 't/data/qc_store/26294/*1.*.json';
  map { cp $_ , $lane_dirs{2} . $plex3_qc } glob 't/data/qc_store/26294/*2.*.json';

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

subtest 'loading data from staging - new style directory structure, merges' => sub {
  plan tests => 9;
  
  my $id_run = 26291;
  my $rf_name = '180711_HX4_B_HLWFJCCXY_NEWM';
  my $rfh = t::autoqc_util::create_runfolder($temp, {runfolder_name => $rf_name});
  my $run_row = $tracking_schema->resultset('Run')->find($id_run);
  $run_row or die "Run $id_run is not in test tracking db";
  $run_row->update({folder_name => $rf_name, folder_path_glob => $temp});
  $tracking_schema->resultset('TagRun')->update_or_create(
    {id_run  => $id_run,id_tag  => 14,id_user => 1}); # set staging tag
  
  my $ar_path = $rfh->{'archive_path'};
  map { `cp -R $_ $ar_path`} map {'t/data/qc_store/26291/' . $_}
    qw/lane1  lane2  plex0  plex11  plex3/;

  my $model =  npg_qc::autoqc::qc_store->new(qc_schema => $schema, use_db => 0);
  my $query = _build_query_obj({id_run => $id_run, option => $LANES});
  my $collection = $model->load($query);
  is($collection->size(), 2, 'a total of two results for two lanes');

  $query = _build_query_obj({id_run => $id_run, option => $PLEXES});
  $collection = $model->load($query);
  is($collection->size(), 9, 'nine results for three plexes');

  $query = _build_query_obj({id_run => $id_run, option => $ALL});
  $collection = $model->load($query);
  is($collection->size(), 9, 'nine results for three plexes, no lane results');
 
  $query = _build_query_obj({id_run => $id_run, option => $ALL, positions => [1]});
  $collection = $model->load($query);
  is($collection->size(), 9, 'no lane filtering');

  $query = _build_query_obj({id_run => $id_run, option => $PLEXES, positions => [1]});
  $collection = $model->load($query);
  is($collection->size(), 9, 'no lane filtering');
  
  my $dir12 = $ar_path . '/lane1-2';
  make_path $dir12;
  foreach my $d (qw/plex0  plex11  plex3/) {
    my $dsource = join q[/], $ar_path, $d;
    `mv $dsource $dir12`;
  }

  $query = _build_query_obj({id_run => $id_run, option => $PLEXES});
  $collection = $model->load($query);
  is($collection->size(), 9, 'nine results for three plexes');

  $query = _build_query_obj({id_run => $id_run, option => $ALL});
  $collection = $model->load($query);
  is($collection->size(), 9, 'nine results for three plexes, no lane results');

  $query = _build_query_obj({id_run => $id_run, positions => [4, 1], option => $ALL});
  $collection = $model->load($query);
  is($collection->size(), 9, 'nine results for lanes 4 and 1');

  $query = _build_query_obj({id_run => $id_run, positions => [4, 5], option => $ALL});
  $collection = $model->load($query);
  is($collection->size(), 0, 'no results for lanes 4 and 5');
};

subtest 'retrieving data from the database - one-component entities' => sub {
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

subtest 'retrieving data from the database - multi-component entities' => sub {
  plan tests => 24;

  my $tm_rs = $schema->resultset('TagMetrics');
  my $is_rs = $schema->resultset('InsertSize');
  my $qx_rs = $schema->resultset('QXYield');

  my $r  = 50000;
  my $r1 = 50001;

  #####
  # Create records for lane-level results, insert_size,
  # qX_yield and tag_metrics record for each lane,
  # 3 records per lane, 12 altogether.
  foreach my $p ((1 .. 4)) {
    my $component_h = {id_run => $r, position => $p};
    my $component =
      npg_tracking::glossary::composition::component::illumina->new($component_h);
    my $f = npg_tracking::glossary::composition::factory->new();
    $f->add_component($component);
    my $composition = $f->create_composition();
    my $crow = $tm_rs->find_or_create_seq_composition($composition);
    $component_h->{id_seq_composition} = $crow->id_seq_composition;
    map { $_->create($component_h) } ($tm_rs, $is_rs);
    $component_h->{threshold_quality} = 20;
    $qx_rs->create($component_h);
  }

  #####
  # Create records for seven plex-level results for merged entities
  # (merge across four lanes) in both insert_size and qX_yield tables,
  # 14 records altogether.
  foreach my $i ((0 .. 6)) {
    my $f = npg_tracking::glossary::composition::factory->new();
    my @component_rows = ();
    foreach my $p ((1 .. 4)) {
      my $component_h = {'id_run' => $r, 'position' => $p, 'tag_index' => $i};
      my $component =
        npg_tracking::glossary::composition::component::illumina->new($component_h);
      $f->add_component($component);
    }
    my $composition = $f->create_composition();
    my $crow = $is_rs->find_or_create_seq_composition($composition);
    my $h = {id_seq_composition => $crow->id_seq_composition};
    $is_rs->create($h);
    $h->{threshold_quality} = 20;
    $qx_rs->create($h);
  }

  #####
  # Create records for seven plex-level results for merged entities
  # (merge across runs) in both insert_size and qX_yield tables,
  # 14 records altogether. These records should not be retrieved.
  foreach my $i ((0 .. 6)) {
    my $f = npg_tracking::glossary::composition::factory->new();
    my @component_rows = ();
    foreach my $p ((1 .. 4)) {
      my $component_h = {'id_run' => $r, 'position' => $p, 'tag_index' => $i};
      my $component =
        npg_tracking::glossary::composition::component::illumina->new($component_h);
      $f->add_component($component);
    }
    my $component_h = {'id_run' => $r1, 'position' => 1, 'tag_index' => $i};
    my $component =
      npg_tracking::glossary::composition::component::illumina->new($component_h);
    $f->add_component($component);
    my $composition = $f->create_composition();

    my $crow = $is_rs->find_or_create_seq_composition($composition);
    my $h = {id_seq_composition => $crow->id_seq_composition};
    $is_rs->create($h);
    $h->{threshold_quality} = 20;
    $qx_rs->create($h);
  }

  my $s = npg_qc::autoqc::qc_store->new(use_db => 1, qc_schema => $schema);
  my $collection = $s->load(_build_query_obj({id_run => $r, option =>$LANES}));
  is ($collection->size, 12, '12 results for lane request');
  my @results = $collection->all;
  ok ((none { $_->composition->num_components > 1 } @results),
    'all results are for one-component compositions');
  ok ((none { defined $_->composition->get_component(0)->tag_index } @results),
    'all results are lane-level');

  $s = npg_qc::autoqc::qc_store->new(use_db => 1, qc_schema => $schema,
       checks_list => [qw/insert_size qX_yield/]);
  $collection = $s->load(_build_query_obj({id_run => $r, option =>$LANES}));
  is ($collection->size, 8, '8 results for lane request');

  $s = npg_qc::autoqc::qc_store->new(use_db => 1, qc_schema => $schema,
       checks_list => [qw/tag_metrics/]);
  $collection = $s->load(_build_query_obj({id_run => $r, option =>$LANES}));
  is ($collection->size, 4, '4 results for lane request');

  $s = npg_qc::autoqc::qc_store->new(use_db => 1, qc_schema => $schema,
       checks_list => [qw/genotype insert_size/]);
  $collection = $s->load(_build_query_obj({id_run => $r, option =>$LANES}));
  is ($collection->size, 4, '4 results for lane request');  

  $s = npg_qc::autoqc::qc_store->new(use_db => 1, qc_schema => $schema);
  $collection = $s->load(
    _build_query_obj({id_run => $r, option => $LANES, positions => [1,2]}));
  is ($collection->size, 6, '6 results for lane request');
  @results = $collection->all;
  ok ((none { $_->composition->num_components > 1 } @results),
    'all results are for one-component compositions');
  ok ((none { defined $_->composition->get_component(0)->tag_index } @results),
    'all results are lane-level');
  my @positions = uniq
                  map { $_->composition->get_component(0)->position }
                  @results;
  is (join(q[,], @positions),'1,2', 'results are for lanes 1 and 2');

  $collection = $s->load_from_db(
    _build_query_obj({id_run => $r, option => $LANES, positions => [5]}));
  is ($collection->size, 0, 'no results for lane that is not in the db');

  $collection = $s->load(
    _build_query_obj({id_run => $r, option => $PLEXES, positions => [1]}));
  my $collection1 = $s->load(
    _build_query_obj({id_run => $r, option => $ALL, positions => [1]}));
  my $collection2 = $s->load(
    _build_query_obj({id_run => $r, option => $ALL, positions => [1,2]}));
  my $collection3 = $s->load(
    _build_query_obj({id_run => $r, option => $ALL}));
  foreach my $c (($collection, $collection1, $collection2, $collection3)) {
    is ($c->size, 14, '14 results for plane request');
    my @results = $collection->all;
    ok ((none { $_->composition->num_components == 1 } @results),
      'all results are for multi-component compositions');
    ok ((none { !defined $_->composition->get_component(0)->tag_index } @results),
      'all results are plex-level');
  }

  $collection = $s->load_from_db(
    _build_query_obj({id_run => $r1, option => $PLEXES}));
  ok ($collection->is_empty, 'no results');
};

subtest 'retrieving data from the database by composition' => sub {
  plan tests => 9;

  my $r  = 50000;
  my $r1 = 50001;
  my @compositions = ();
  foreach my $i ((1 .. 6)) {
    my $f = npg_tracking::glossary::composition::factory->new();
    foreach my $p ((1 .. 4)) {
      my $component_h = {'id_run' => $r, 'position' => $p, 'tag_index' => $i};
      my $component =
        npg_tracking::glossary::composition::component::illumina->new($component_h);
      $f->add_component($component);
    }
    push @compositions, $f->create_composition();
  }

  my $s = npg_qc::autoqc::qc_store->new(use_db => 1, qc_schema => $schema);

  throws_ok {$s->load_from_db_via_composition()}
    qr/Array of composition objects should be given/,
    'error if no argument is given';
  my $collection = $s->load_from_db_via_composition([]);
  ok ($collection->is_empty(), 'empty arg array - empty collection');

  $collection = $s->load_from_db_via_composition(\@compositions);
  is ($collection->size, 12, '12 results');
  ok ((all {$_ == 4} map { $_->composition->num_components } $collection->all),
    'all results are for compositions with 4 components');

  my $fc = npg_tracking::glossary::composition::factory->new();
  my $ch = {'id_run' => $r, 'position' => 1, 'tag_index' => 1};
  my $c =
    npg_tracking::glossary::composition::component::illumina->new($ch);
  $fc->add_component($c);
  $collection = $s->load_from_db_via_composition([$fc->create_composition()]);
  ok ($collection->is_empty(), 'no result - empty collection');

  $s = npg_qc::autoqc::qc_store->new(use_db => 1, qc_schema => $schema,
       checks_list => [qw/genotype insert_size/]);
  $collection = $s->load_from_db_via_composition(\@compositions);
  is ($collection->size, 6, '6 results');

  $s = npg_qc::autoqc::qc_store->new(use_db => 1, qc_schema => $schema,
       checks_list => [qw/genotype/]);
  $collection = $s->load_from_db_via_composition(\@compositions);
  ok ($collection->is_empty(), 'no genotype results - empty collection');

  @compositions = ();
  foreach my $i ((1 .. 6)) {
    my $f = npg_tracking::glossary::composition::factory->new();
    foreach my $p ((1 .. 4)) {
      my $component_h = {'id_run' => $r, 'position' => $p, 'tag_index' => $i};
      my $component =
        npg_tracking::glossary::composition::component::illumina->new($component_h);
      $f->add_component($component);
    }
    my $component_h = {'id_run' => $r1, 'position' => 1, 'tag_index' => $i};
    my $component =
      npg_tracking::glossary::composition::component::illumina->new($component_h);
    $f->add_component($component);
    push @compositions, $f->create_composition();
  }

  $s = npg_qc::autoqc::qc_store->new(use_db => 1, qc_schema => $schema);
  $collection = $s->load_from_db_via_composition(\@compositions);
  is ($collection->size, 12, '12 results');
  ok ((all {$_ == 5} map { $_->composition->num_components } $collection->all),
    'all results are for compositions with 5 components');
};

1;

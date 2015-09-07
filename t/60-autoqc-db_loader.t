use strict;
use warnings;
use Test::More tests => 75;
use Test::Exception;
use Test::Warn;
use Moose::Meta::Class;
use Perl6::Slurp;
use JSON;
use npg_testing::db;

use_ok('npg_qc::autoqc::db_loader');

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema]);

{
  my $db_loader = npg_qc::autoqc::db_loader->new();
  isa_ok($db_loader, 'npg_qc::autoqc::db_loader');

  $db_loader = npg_qc::autoqc::db_loader->new(
      path    =>['t/data/autoqc/tag_decode_stats'],
      schema  => $schema,
      verbose => 0,
  );
  is(scalar @{$db_loader->json_file}, 1, 'one json file found');
  my $json_file = 't/data/autoqc/tag_decode_stats/6624_3_tag_decode_stats.json';
  is($db_loader->json_file->[0], $json_file, 'correct json file found');
  my $values = decode_json(slurp($json_file));
  ok($db_loader->_pass_filter($values, 'tag_decode_stats'), 'filter test positive');
  $db_loader = npg_qc::autoqc::db_loader->new(id_run=>[3, 2, 6624]);
  ok($db_loader->_pass_filter($values, 'tag_decode_stats'), 'filter test positive');
  $db_loader = npg_qc::autoqc::db_loader->new(id_run=>[3, 2]);
  ok(!$db_loader->_pass_filter($values, 'tag_decode_stats'), 'filter test negative');
  $db_loader = npg_qc::autoqc::db_loader->new(lane=>[4,3]);
  ok($db_loader->_pass_filter($values, 'tag_decode_stats'), 'filter test positive');
  $db_loader = npg_qc::autoqc::db_loader->new(lane=>[4,5]);
  ok(!$db_loader->_pass_filter($values, 'tag_decode_stats'), 'filter test negative');
  $db_loader = npg_qc::autoqc::db_loader->new(check=>[]);
  ok($db_loader->_pass_filter($values, 'tag_decode_stats'), 'filter test positive');
  $db_loader = npg_qc::autoqc::db_loader->new(check=>['tag_decode_stats','other']);
  ok($db_loader->_pass_filter($values, 'tag_decode_stats'), 'filter test positive');
  $db_loader = npg_qc::autoqc::db_loader->new(check=>['insert_size','other']);
  ok(!$db_loader->_pass_filter($values, 'tag_decode_stats'), 'filter test negative');
}

{ 
  my $db_loader = npg_qc::autoqc::db_loader->new(
      path    =>['t/data/autoqc/tag_decode_stats'],
      schema  => $schema,
      verbose => 1,
  );
  my $values = {'pear' => 1, 'apple' => 2, 'orange' => 3,};
  $db_loader->_exclude_nondb_attrs($values, qw/pear apple orange/);
  is_deeply($values, {'pear' => 1, 'apple' => 2, 'orange' => 3,},
    'hash did not change');
  $values->{'__CLASS__'} = 'fruits';
  warning_like {$db_loader->_exclude_nondb_attrs($values, qw/pear apple/)}
    qr/Not loading field \'orange\'/,
    'warning about filtering out orange, but not __CLASS__';
  is_deeply($values, {'pear' => 1, 'apple' => 2,},
    'non-db orange and __CLASS__ filtered out');
  $db_loader->_exclude_nondb_attrs($values, qw/pear apple orange/);
  is_deeply($values, {'pear' => 1, 'apple' => 2,},
    'hash did not change');
}

{
  my $is_rs = $schema->resultset('InsertSize');
  my $current_count = $is_rs->search({})->count;

  my $db_loader = npg_qc::autoqc::db_loader->new(
       schema => $schema,
       path   => ['t/data/autoqc/insert_size/6062_8#1.insert_size.json'],
  );

  my $count_loaded;
  warnings_exist {$count_loaded = $db_loader->load()}
   [qr/not a directory, skipping/, qr/0 json files have been loaded/],
   'non-directory path entry skipped';
  is($count_loaded, 0, 'nothing loaded');

  $db_loader = npg_qc::autoqc::db_loader->new(
       schema => $schema,
       path   => ['t/data/autoqc/dbix_loader/is'],
       verbose => 0,
  );
  lives_ok {$count_loaded = $db_loader->load()} 'file loaded';
  is($count_loaded, 1, 'reported one file loaded');
  $current_count++;
  is ($is_rs->search({})->count, $current_count, 'one record added to the table');
  lives_ok {$db_loader->load()} 'reload insert size result';
  my $rs = $is_rs->search({});
  is($rs->count, $current_count, 'no new records added');
  my $row = $rs->next;
  is(join(q[ ],@{$row->expected_size}), '50 200', 'insert size');
  is($row->num_well_aligned_reads, 50, 'number well-aligned reads');
  is($row->norm_fit_nmode, 22, 'norm_fit_nmode');
  is($row->norm_fit_confidence, .55, 'norm_fit_confidence');
  is($row->norm_fit_pass, 1, 'norm_fit_pass');
  is(scalar(@{$row->norm_fit_modes}), 15, 'norm_fit_modes');
  is($row->norm_fit_modes->[0], 1, 'norm_fit_modes[0]');
  is($row->norm_fit_modes->[14], 15, 'norm_fit_modes[14]');

  $db_loader = npg_qc::autoqc::db_loader->new(
       schema => $schema,
       path   => ['t/data/autoqc/dbix_loader/is/update'],
       verbose => 0,
  );
  lives_ok {$db_loader->load()} 'reload updated insert size result';
  $rs = $is_rs->search({});
  is($rs->count, $current_count, 'no new records added');
  $row = $rs->next;
  is(join(q[ ],@{$row->expected_size}), '100 300', 'updated insert size');
  is($row->num_well_aligned_reads, 60, 'updated number well-aligned reads');

  $db_loader = npg_qc::autoqc::db_loader->new(
       schema => $schema,
       path   => ['t/data/autoqc/dbix_loader/is'],
       update => 0,
  );
  warnings_exist {$db_loader->load()}
    [qr(Skipped t/data/autoqc/dbix_loader/is/12187_2\.insert_size\.json),
     qr(0 json files have been loaded)],
    'file skipped warning';
  $rs = $is_rs->search({});
  is($rs->count, $current_count, 'no new records added');
  $row = $rs->next;
  is(join(q[ ],@{$row->expected_size}), '100 300', 'insert size not updated');
  is($row->num_well_aligned_reads, 60, 'number well-aligned reads not updated');

  $db_loader = npg_qc::autoqc::db_loader->new(
       schema => $schema,
       path   => ['t/data/autoqc/dbix_loader/is/more'],
       update => 0,
       verbose => 0,
  );
  lives_ok {$db_loader->load()} 'load new insert size result';
  is($is_rs->search({})->count, $current_count+1, 'a new records added');
}

{
  my $is_rs = $schema->resultset('VerifyBamId');
  my $current_count = $is_rs->search({})->count;
  my $count_loaded;

  my $db_loader = npg_qc::autoqc::db_loader->new(
       schema => $schema,
       json_file   => ['t/data/autoqc/7321_7#8.verify_bam_id.json'],
       verbose => 0,
  );
  lives_ok {$count_loaded = $db_loader->load()} 'file loaded';
  is($count_loaded, 1, 'reported one file loaded');
  $current_count++;
  is ($is_rs->search({})->count, $current_count, 'one record added to the table');
  lives_ok {$db_loader->load()} 'reload VerifyBamId result';
  my $rs = $is_rs->search({});
  is($rs->count, $current_count, 'no new records added');
  my $row = $rs->next;
  is($row->freemix, 0.00025, 'freemix');
  is($row->freeLK0, 823213.22, 'freeLK0');
  is($row->freeLK1, 823213.92, 'freeLK1');
}

{
  my $is_rs = $schema->resultset('InsertSize');
  $is_rs->delete_all();
  my $db_loader = npg_qc::autoqc::db_loader->new(
       schema => $schema,
       path   => ['t/data/autoqc/dbix_loader/is/more',
                  't/data/autoqc/dbix_loader/is/update',
                  't/data/autoqc/dbix_loader/is'
                 ],
       verbose => 0,
  );
  my $count;
  lives_ok {$count = $db_loader->load()} 'loading from multiple paths';
  is($count, 3, '3 loaded records reported');
  is($is_rs->search({})->count, 2, 'two records created');
}

{
  my $is_rs = $schema->resultset('InsertSize');
  $is_rs->delete_all();
  my $file_good = 't/data/autoqc/dbix_loader/is/12187_2.insert_size.json';

  my $db_loader = npg_qc::autoqc::db_loader->new(
       schema => $schema,
       json_file => [$file_good,
                     't/data/autoqc/insert_size/6062_8#2.insert_size.json'],
       verbose => 0,
  );
  throws_ok {$db_loader->load()} qr/Loading aborted, transaction has rolled back/,
    'error loading a set of files with the last file corrupt';
  is ($is_rs->search({})->count, 0, 'table is empty, ie transaction has been rolled back');

  my $file = 't/data/autoqc/insert_size/6062_8#1.insert_size.json';
  $db_loader = npg_qc::autoqc::db_loader->new(
       schema => $schema,
       json_file => [$file_good,$file],
  );
  warnings_like {$db_loader->load()}  [
    qr/Loaded $file_good/,
    qr/Not loading field 'obins'/,
    qr/Loaded $file/,
    qr/2 json files have been loaded/ ],
    'loaded a file with incorrect attribute, gave warning';
  is ($is_rs->search({})->count, 2, 'two records created');
  $is_rs->delete_all();
}

$schema->resultset('InsertSize')->delete_all();
my $path = 't/data/autoqc/dbix_loader/run';
my $num_lane_jsons = 11;
my $num_plex_jsons = 44;
{
  my $db_loader = npg_qc::autoqc::db_loader->new(
       schema => $schema,
       verbose => 0,
       path => [$path],
       id_run => [233],
  );
  is($db_loader->load(), 0, 'no files loaded - filtering by id');

  $db_loader = npg_qc::autoqc::db_loader->new(
       schema => $schema,
       verbose => 0,
       path => [$path],
       id_run => [12233],
       lane => [3,5],
  );
  is($db_loader->load(), 0, 'no files loaded - filtering by lane');

  $db_loader = npg_qc::autoqc::db_loader->new(
       schema  => $schema,
       verbose => 0,
       path    => [$path],
       id_run  => [12233],
       lane    => [1,2],
       check   => [qw(pulldown_metrics some_other)],
  );
  is($db_loader->load(), 0, 'no files loaded - filtering by check name');

  $db_loader = npg_qc::autoqc::db_loader->new(
       schema => $schema,
       verbose => 0,
       path => [$path]
  );
  is ($db_loader->load(), $num_lane_jsons, 'all json files loaded to the db');
  my $count = 0;
  foreach my $table (qw(Adapter InsertSize SpatialFilter
                        GcFraction RefMatch QXYield UpstreamTags
                        SequenceError TagMetrics TagsReporters)) {
    $count +=$schema->resultset($table)->search({})->count;
  }
  is($count, $num_lane_jsons, 'number of new records in the db is correct');

  is ($db_loader->load(), $num_lane_jsons, 'loading the same files again updates all files');

  $db_loader = npg_qc::autoqc::db_loader->new(
       schema       => $schema,
       verbose      => 0,
       path         => [$path],
       update       => 0,
  );
  is ($db_loader->load(), 0, 'loading the same files again with update option false'); 
}

{
  my $db_loader = npg_qc::autoqc::db_loader->new(
       schema       => $schema,
       verbose      => 0,
       path         => [$path, "$path/lane"],
       update       => 0,
       load_related => 0,
  );
  is ($db_loader->load(), $num_plex_jsons, 'loading from two paths without update');
  my $total_count = 0;
  my $plex_count = 0;
  my $tag_zero_count = 0;
  my @tables = qw(Adapter InsertSize GcFraction RefMatch QXYield Genotype
                  SequenceError BamFlagstats PulldownMetrics GcBias
                  AlignmentFilterMetrics);
  foreach my $table (@tables) {
    $total_count +=$schema->resultset($table)->search({})->count;
    $plex_count +=$schema->resultset($table)->search({tag_index => {'>', -1},})->count;
    $tag_zero_count +=$schema->resultset($table)->search({tag_index => 0,})->count;
  }

  foreach my $table (qw(TagMetrics UpstreamTags TagsReporters SpatialFilter)) {
    $total_count +=$schema->resultset($table)->search({})->count;
  }
  is ($plex_count, $num_plex_jsons, 'number of plexes loaded');
  is ($total_count, $num_plex_jsons+$num_lane_jsons, 'number of records loaded');
  is ($tag_zero_count, 8, 'number of tag zero records loaded');
}

{
  my $rs = $schema->resultset('BamFlagstats');
  is ($rs->search({human_split => 'all'})->count, 6, '6 bam flagstats records for target files');
  is ($rs->search({human_split => 'human'})->count, 2, '2 bam flagstats records for human files');
  is ($rs->search({human_split => 'phix'})->count, 1, '1 bam flagstats records for phix files');
  is ($rs->search({subset => 'target'})->count, 6, '6 bam flagstats records for target files');
  is ($rs->search({subset => 'human'})->count, 2, '2 bam flagstats records for human files');
  is ($rs->search({subset => 'phix'})->count, 1, '1 bam flagstats records for phix files');
}

{
  my $db_loader = npg_qc::autoqc::db_loader->new(
       schema       => $schema,
       verbose      => 1,
       path         => ['t/data/autoqc/bam_flagstats/qc'],
       load_related => 0,
  );
  my $file = 't/data/autoqc/bam_flagstats/qc/16960_1#0.bam_flagstats.json';
  my $w = 'Not loading field';
  warnings_like { $db_loader->load() }
    [ qr/$w \'sequence_file\'/,
      qr/$w \'flagstats_metrics_file\'/,
      qr/$w \'samtools_stats_file\'/,
      qr/$w \'markdups_metrics_file\'/,
      qr/Loaded $file/,
      qr/1 json files have been loaded/ ],
    'warnings when loading extended bam_flagstats json';

  $db_loader = npg_qc::autoqc::db_loader->new(
       schema       => $schema,
       verbose      => 0,
       path         => ['t/data/autoqc/bam_flagstats'],
       load_related => 0,
  );
  throws_ok { $db_loader->load() } qr/Loading aborted, transaction has rolled back/,
    'error loading json result without id_run';
}

1;

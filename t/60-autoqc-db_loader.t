use strict;
use warnings;
use Test::More tests => 17;
use Test::Exception;
use Test::Warn;
use Moose::Meta::Class;
use Perl6::Slurp;
use JSON;
use Archive::Extract;
use File::Temp qw/ tempdir /;
use File::Copy qw/ cp /;
use List::MoreUtils qw/ any uniq /;

use npg_testing::db;

use_ok ('npg_qc::autoqc::results::alignment_filter_metrics');
use_ok ('npg_qc::autoqc::results::verify_bam_id');
use_ok ('npg_qc::autoqc::db_loader');

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema]);

subtest 'constructing an object' => sub {
  plan tests => 1;

  my $db_loader = npg_qc::autoqc::db_loader->new(
      path    =>['t/data/autoqc'],
      schema  => $schema,
  );
  isa_ok($db_loader, 'npg_qc::autoqc::db_loader');
};

subtest 'filtering' => sub {
  plan tests => 14;

  my $json_file = 't/data/autoqc/7321_7#8.verify_bam_id.json';
  my $vobj = npg_qc::autoqc::results::verify_bam_id->load($json_file);
  is ($vobj->composition->num_components, 1, 'one component');
  $json_file = 't/data/qc_store/26291/plex11/qc/26291#11.alignment_filter_metrics.json';
  my $afobj = npg_qc::autoqc::results::alignment_filter_metrics->load($json_file);
  is ($afobj->composition->num_components, 2, 'two components');

  my $db_loader = npg_qc::autoqc::db_loader->new(schema=>$schema,path=>['t']);
  ok($db_loader->_pass_filter($vobj), 'passed');
  ok($db_loader->_pass_filter($afobj), 'passed');

  $db_loader = npg_qc::autoqc::db_loader->new(
    schema=>$schema,path=>['t'],id_run=>7321);
  ok($db_loader->_pass_filter($vobj), 'passed');
  ok($db_loader->_pass_filter($afobj), 'passed');

  $db_loader = npg_qc::autoqc::db_loader->new(
    schema=>$schema,path=>['t'],id_run=>3);
  ok(!$db_loader->_pass_filter($vobj), 'failed');

  $db_loader = npg_qc::autoqc::db_loader->new(
    schema=>$schema,path=>['t'],id_run=>7321,lane=>[7,3]);
  ok($db_loader->_pass_filter($vobj), 'passed');
  ok($db_loader->_pass_filter($afobj), 'passed');

  $db_loader = npg_qc::autoqc::db_loader->new(
    schema=>$schema,path=>['t'],id_run=>7321,lane=>[4,5]);
  ok(!$db_loader->_pass_filter($vobj), 'failed');

  $db_loader = npg_qc::autoqc::db_loader->new(
    schema=>$schema,path=>['t'],check=>[qw/verify_bam_id insert_size/]);
  ok($db_loader->_pass_filter($vobj), 'passed');
  ok(!$db_loader->_pass_filter($afobj), 'failed');
 
  $db_loader = npg_qc::autoqc::db_loader->new(
    schema=>$schema,path=>['t'],check=>[qw/insert_size alignment_filter_metrics/]);
  ok(!$db_loader->_pass_filter($vobj), 'failed');
  ok($db_loader->_pass_filter($afobj), 'passed');
};

subtest 'excluding non-db attributes' => sub {
  plan tests => 4;

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
};

subtest 'loading insert_size results' => sub {
  plan tests => 17;

  my $is_rs = $schema->resultset('InsertSize');
  my $current_count = $is_rs->search({})->count;
  my $count_loaded;
  my $db_loader = npg_qc::autoqc::db_loader->new(
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
};

subtest 'loading veryfy_bam_id results' => sub {
  plan tests => 8;

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
};

subtest 'loading from multiple paths' => sub {
  plan tests => 3;

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
};

subtest 'errors and warnings' => sub {
  plan tests => 4;

  my $is_rs = $schema->resultset('InsertSize');
  $is_rs->delete_all();
  my $file_good = 't/data/autoqc/dbix_loader/is/12187_2.insert_size.json';
  my $file_bad  = 't/data/autoqc/insert_size/6062_8#2.insert_size.json';
  my $db_loader = npg_qc::autoqc::db_loader->new(
       schema    => $schema,
       json_file => [$file_good, $file_bad],
       verbose   => 0
  );
  throws_ok {$db_loader->load()}
    qr/Loading aborted, transaction has rolled back/,
    'error loading a set of files with the last file corrupt';
  is ($is_rs->search({})->count, 0,
    'table is empty, ie transaction has been rolled back');

  $db_loader = npg_qc::autoqc::db_loader->new(
       schema    => $schema,
       json_file => [$file_good],
       verbose   => 1
  );
  warnings_exist {$db_loader->load()}
    [ qr/1 json files have been loaded/ ],
    'warning - reporting number of loaded files';
  is ($is_rs->search({})->count, 1, 'one record created');
  $is_rs->delete_all();
};

$schema->resultset('InsertSize')->delete_all();
my $path = 't/data/autoqc/dbix_loader/run';
my $num_lane_jsons = 11;
my $num_plex_jsons = 44;

subtest 'loading and reloading' => sub {
  plan tests => 6;

  my $db_loader = npg_qc::autoqc::db_loader->new(
       schema  => $schema,
       verbose => 0,
       path    => [$path],
       id_run  => 233,
  );
  is($db_loader->load(), 0, 'no files loaded - filtering by id');

  $db_loader = npg_qc::autoqc::db_loader->new(
       schema  => $schema,
       verbose => 0,
       path    => [$path],
       id_run  => 12233,
       lane    => [3,5],
  );
  is($db_loader->load(), 0, 'no files loaded - filtering by lane');

  $db_loader = npg_qc::autoqc::db_loader->new(
       schema  => $schema,
       verbose => 0,
       path    => [$path],
       id_run  => 12233,
       lane    => [1,2],
       check   => [qw(pulldown_metrics genotype)],
  );
  is($db_loader->load(), 0, 'no files loaded - filtering by check name');

  $db_loader = npg_qc::autoqc::db_loader->new(
       schema  => $schema,
       verbose => 0,
       path    => [$path]
  );
  is ($db_loader->load(), $num_lane_jsons, 'all json files loaded to the db');
  my $count = 0;
  foreach my $table (qw(Adapter InsertSize SpatialFilter
                        GcFraction RefMatch QXYield UpstreamTags
                        SequenceError TagMetrics TagsReporters)) {
    $count +=$schema->resultset($table)->search({})->count;
  }
  is($count, $num_lane_jsons, 'number of new records in the db is correct');

  $db_loader = npg_qc::autoqc::db_loader->new(
       schema  => $schema,
       verbose => 0,
       path    => [$path]
  );
  is ($db_loader->load(), $num_lane_jsons, 'loading the same files again updates all files');
};

subtest 'loading a range of results' => sub {
  plan tests => 4;

  my $db_loader = npg_qc::autoqc::db_loader->new(
       schema       => $schema,
       verbose      => 0,
       path         => [$path, "$path/lane"]
  );
  is ($db_loader->load(), 55, 'loading from two paths');
  my $total_count = 0;
  my $plex_count = 0;
  my $tag_zero_count = 0;
  my @tables = qw(Adapter InsertSize GcFraction RefMatch QXYield Genotype
                  SequenceError BamFlagstats PulldownMetrics GcBias
                  AlignmentFilterMetrics);
  foreach my $table (@tables) {
    $total_count +=$schema->resultset($table)->search({})->count;
    $plex_count +=$schema->resultset($table)->search(
     {tag_index => [ -and => {'!=', undef}, {'>', -1}]})->count;
    $tag_zero_count +=$schema->resultset($table)->search({tag_index => 0,})->count;
  }

  foreach my $table (qw(TagMetrics UpstreamTags TagsReporters SpatialFilter)) {
    $total_count +=$schema->resultset($table)->search({})->count;
  }
  is ($plex_count, $num_plex_jsons, 'number of plexes loaded');
  is ($total_count, $num_plex_jsons+$num_lane_jsons, 'number of records loaded');
  is ($tag_zero_count, 8, 'number of tag zero records loaded');
};

subtest 'checking bam_flagstats records' => sub {
  plan tests => 3;
  my $rs = $schema->resultset('BamFlagstats');
  is ($rs->search({subset =>  undef})->count, 6, '6 bam flagstats records for target files');
  is ($rs->search({subset => 'human'})->count, 2, '2 bam flagstats records for human files');
  is ($rs->search({subset => 'phix'})->count, 1, '1 bam flagstats records for phix files');
};

subtest 'loading bam_flagststs' => sub {
  plan tests => 2;

  my @files = glob('t/data/autoqc/bam_flagstats/*bam_flagstats.json');
  is (scalar @files, 4, 'four JSON files are available');

  my $db_loader = npg_qc::autoqc::db_loader->new(
       schema       => $schema,
       verbose      => 0,
       path         => ['t/data/autoqc/bam_flagstats'],
  );
  is ($db_loader->load(), 2, 'two files loaded (two have no __CLASS__ key)');
};

my $archive = '17448_1_9';
my $tempdir = tempdir( CLEANUP => 1);
my $ae = Archive::Extract->new(archive => "t/data/autoqc/bam_flagstats/${archive}.tar.gz");
$ae->extract(to => $tempdir) or die $ae->error;
$archive = join q[/], $tempdir, $archive;
my $json_dir1 = join q[/], $archive, 'qc';
my $json_dir2 = join q[/], $json_dir1, 'all_json';
#note `find $archive`;

subtest 'roll-back for composition-based results' => sub {
  plan tests => 3;

  my $comp_dir = join q[/], $tempdir, 'compositions';
  mkdir $comp_dir;
  cp "$json_dir2/17448_1#9_phix_F0x900.samtools_stats.json", $comp_dir;
  cp "$json_dir2/17448_1#9_phix_F0xB00.samtools_stats.json", $comp_dir;
  my $file_good = "$comp_dir/17448_1#9_phix_F0x900.samtools_stats.json";
  my $file = "$comp_dir/17448_1#9_phix_F0xB00.samtools_stats.json";
  my $content = slurp $file;
  # Create a json file with run id that will fail validation
  $content =~ s/17448/-17448/;
  open my $fh, '>', $file or die "Failed to open $file for writing";
  print $fh $content or die "Failed to write to $file";
  close $fh or die "Failed to close filehandle for $file";

  my $crs = $schema->resultset('SeqComponent');
  is($crs->search({id_run => 17448})->count(), 0,
    'prerequisite - no components with run id 17448');

  my $db_loader = npg_qc::autoqc::db_loader->new(
       schema => $schema,
       json_file => [$file_good, $file],
       verbose => 0,
  );
  throws_ok {$db_loader->load()}
    qr/Validation failed for 'NpgTrackingRunId' with value -17448/,
    'error loading corrupt file - roll back';
  is($crs->search({id_run => 17448})->count(), 0, 'no components with run id 17448');
};

subtest 'loading bam_flagstats and its related objects from files' => sub {
  plan tests => 41;

  my $db_loader = npg_qc::autoqc::db_loader->new(
       schema       => $schema,
       verbose      => 0,
       path         => [$json_dir2],
  );

  ok ((any {$_ eq 'samtools_stats'} @{$db_loader->_checks_list}) &&
      (any {$_ eq 'sequence_summary'} @{$db_loader->_checks_list}),
   'samtools_stats and sequence_summary are valid results for loading');

  $db_loader->load();
  
  my @objects = $schema->resultset('BamFlagstats')->search(
    {'id_run' => 17448}, {order_by => {'-asc' => 'subset'}})->all();
  is (scalar @objects, 2, 'two objects');
  is ($objects[0]->subset, undef, 'object for target subset');
  is ($objects[1]->subset, 'phix',  'object for phix subset');

  @objects = $schema->resultset('SamtoolsStats')->search({})->all();
  is (scalar @objects, 4, 'four objects');
  my @filters = sort { $a cmp $b } uniq map { $_->filter} @objects;
  is (join(q[ ],@filters), 'F0x900 F0xB00', 'two distinct filters');

  my @da_component = qw(
    31d7631510fd4090dddc218ebc46d4d3cab3447964e620f25713293a21c7d6a6
    9c2dfacdbfa50be10bfbab6df20a8ebdcd8e67bf0e659b1fe6be667c6258d33c
  ); # two distinct components
  my @da_composition = qw(
    bfc10d33f4518996db01d1b70ebc17d986684d2e04e20ab072b8b9e51ae73dfa
    ca4c3f9e6f8247fed589e629098d4243244ecd71f588a5e230c3353f5477c5cb
  ); # two distinct compositions

  is (join(q[ ], sort {$a cmp $b} 
                 (uniq map { $_->composition->digest}
                 @objects)),
   join(q[ ], @da_composition), 'two distinct composition keys');
  is (join(q[ ], sort {$a cmp $b}
                 (uniq map { $_->composition->get_component(0)->digest}
                 @objects)),
   join(q[ ], @da_component), 'two distinct component keys');

  foreach my $o (@objects) {
    my $composition = $o->seq_composition;
    isa_ok ($composition, 'npg_qc::Schema::Result::SeqComposition');
    is ($composition->size, 1, 'composition of one');
    my $cc_link_rs = $composition->seq_component_compositions;
    is ($cc_link_rs->count, 1, 'one link to component');
    my $component = $cc_link_rs->next->seq_component;
    isa_ok ($component, 'npg_qc::Schema::Result::SeqComponent');
  }

  my $i = 0;
  @objects = $schema->resultset('SequenceSummary')->search({})->all();
  is (scalar @objects, 2, 'two objects');
  my ($phix_obj) = grep { defined $_->composition->get_component(0)->subset} @objects;
  my ($default_obj) = grep { !defined $_->composition->get_component(0)->subset} @objects;
  foreach my $o (($default_obj, $phix_obj)) {
    my $composition = $o->seq_composition;
    isa_ok ($composition, 'npg_qc::Schema::Result::SeqComposition');
    is ($composition->size, 1, 'composition of one');
    my $cc_link_rs = $composition->seq_component_compositions;
    is ($cc_link_rs->count, 1, 'one link to component');
    my $component = $cc_link_rs->next->seq_component;
    isa_ok ($component, 'npg_qc::Schema::Result::SeqComponent');
    is ($component->id_run, 17448, 'run id');
    is ($component->position, 1, 'position');
    is ($component->tag_index, 9, 'tag_index');
    is ($component->subset, $i ? 'phix' : undef, 'subset value');
    $i++;
  }
};

subtest 'no error if no DBIx binding for result' => sub {
  plan tests => 2;

  package npg_qc::autoqc::results::some;
  use Moose;
  extends qw(npg_qc::autoqc::results::base);
  no Moose;
  1;

  package main;

  my $j = '{"__CLASS__":"npg_qc::autoqc::results::some","composition":{"__CLASS__":"npg_tracking::glossary::composition-85.4","components":[{"__CLASS__":"npg_tracking::glossary::composition::component::illumina","id_run":21255,"position":1,"tag_index":1}]}}';
  
  my $dir = tempdir( CLEANUP => 1);
  my $path = join q[/], $dir, '21255_1#1.some.json';
  open my $fh, '>', $path or die "Cannot open $path for writing";
  print $fh $j or die "Cannot write to $path";
  close $fh or warn "Failed to close file handle for $path";
  
  my $db_loader = npg_qc::autoqc::db_loader->new(
    json_file => [$path],
    schema    => $schema,
  );
  my $num_loaded;
  lives_ok { $num_loaded = $db_loader->load() }
    'no error loading a result that does not have a corresponding DBIx source';
  is ( $num_loaded, 0, 'count of loaded files is zero');
};

1;

use strict;
use warnings;
use Test::More tests => 9;
use Test::Exception;
use File::Temp qw/tempdir/;
use List::MoreUtils qw/uniq/;

use_ok('npg_qc::autoqc::parse::samtools_stats');
use_ok('npg_qc::autoqc::db_loader');

my $temp = tempdir( CLEANUP => 1);
my $schema = Moose::Meta::Class
             ->create_anon_class(roles => [qw/npg_testing::db/])
             ->new_object()
             ->create_test_db(q[npg_qc::Schema]);

subtest 'reading data' => sub {
  plan tests => 17;

  my $s = npg_qc::autoqc::parse::samtools_stats->new();
  isa_ok ($s, 'npg_qc::autoqc::parse::samtools_stats');
  throws_ok { $s->file_content }
    qr/File path not given, cannot build samtools stats file content/,
    'no file path - error';
  
  throws_ok {  npg_qc::autoqc::parse::samtools_stats->new(
                 file_path => join(q[/], $temp, $temp)) }
    qr/Attribute \(file_path\) does not pass the type constraint/,
    'error if file does not exist';

  $s = npg_qc::autoqc::parse::samtools_stats->new(
        file_path => 't/data/samtools_stats/26607_1#20_F0xB00.stats');
  lives_ok { $s->file_content } 'reads file OK';
  is (scalar @{$s->file_content}, 7812, 'lines in memory');

  throws_ok{npg_qc::autoqc::parse::samtools_stats->new(file_content => q[])}
    qr/Content string cannot be empty/,
    'error setting an empty content string';

  my @content = qw/content of the file/;
  my $string_content = join qq[\n], @content;

  lives_ok { $s = npg_qc::autoqc::parse::samtools_stats->new(
                  file_content => \@content) }
   'can create an object with non-empty array of strings as content';

  lives_ok { $s = npg_qc::autoqc::parse::samtools_stats->new(
                  file_content => $string_content) }
   'can create an object supplying non-empty content string';
  is_deeply ($s->file_content, \@content,
    'string coerced to an array of strings');

  my $empty = join q[/], $temp, 'empty';
  open my $fh, '>', $empty or die 'Failed to create a file';
  print $fh q[];
  close $fh;
  $s = npg_qc::autoqc::parse::samtools_stats->new(file_path => $empty);
  throws_ok { $s->file_content }
    qr/No content in $empty/,
    'error if file is empty';

  my $empty_json = join q[.], $empty, q[json];
  rename $empty, $empty_json;
  $s = npg_qc::autoqc::parse::samtools_stats->new(file_path => $empty_json);
  throws_ok { $s->file_content }
    qr/malformed JSON string/,
    'error if json file is empty';

  my $expected_lines_num = 7812;

  my $ss_json = 't/data/samtools_stats/26607_1#20_F0xB00.samtools_stats.json';
  $s = npg_qc::autoqc::parse::samtools_stats->new(file_path => $ss_json);
  lives_ok { $s->file_content }
    'can read content from samtools stats autoqc JSON file';
  is (scalar @{$s->file_content}, $expected_lines_num, 'correct number of lines read');

  my $loader = npg_qc::autoqc::db_loader->new(json_file => [$ss_json],
                                              schema    => $schema,
                                              verbose   => 0);
  $loader->load();
  my $ss_row = $schema->resultset('SamtoolsStats')->search->next();
  my $stats_string = $ss_row->stats;
  $s = npg_qc::autoqc::parse::samtools_stats->new(file_content => $stats_string);
  is (scalar @{$s->file_content}, $expected_lines_num,
    'content retrieved from the database - correct number of lines read');

  throws_ok { npg_qc::autoqc::parse::samtools_stats->new(file_content => $loader) }
    qr/Not autoqc samtools stats object/,
    'error for wrong type of object';
  
  lives_ok {$s = npg_qc::autoqc::parse::samtools_stats->new(file_content => $ss_row)}
    'content as npg_qc::Schema::Result::SamtoolsStats object instance';
  is (scalar @{$s->file_content}, $expected_lines_num,
    'content as autoqc object from the database - correct number of lines read');  
};

subtest 'number of reads and existence of reverse read' => sub {
  plan tests => 18;

  my $s = npg_qc::autoqc::parse::samtools_stats->new(file_content => []);
  throws_ok { $s->num_reads }
    qr/Content is empty - zero lines/,
    'zero content lines - error';

  $s = npg_qc::autoqc::parse::samtools_stats->new(
     file_content => [qw/content of the file/]);
  throws_ok { $s->num_reads }
    qr/SN section is missing/,
    'expected section not present - error';

  $s = npg_qc::autoqc::parse::samtools_stats->new(
     file_content => ['SN  some content']);
  throws_ok { $s->num_reads }
    qr/Failed to get number of reads/,
    'data missing - error';

  $s = npg_qc::autoqc::parse::samtools_stats->new(
     file_content => ['SN  some fragments','SN  1st fragments: 66','SN  some fragments']);
  throws_ok { $s->num_reads }
    qr/Failed to get number of reads/,
    'data missing - error';

  $s = npg_qc::autoqc::parse::samtools_stats->new(
     file_content => ['SN  last fragments: 66']);
  throws_ok { $s->num_reads }
    qr/Failed to get number of reads/,
    'data missing - error';

  $s = npg_qc::autoqc::parse::samtools_stats->new(
     file_content => ['SN  some fragments','SN  1st fragments: 66',
                      'SN  last fragments: 66','SN  some fragments']);
  throws_ok { $s->num_reads }
    qr/Failed to get number of reads/,
    'data missing - error';

  # paired run
  $s = npg_qc::autoqc::parse::samtools_stats->new( file_path =>
       't/data/samtools_stats/26607_1#20_F0xB00.stats');
  lives_ok { $s->num_reads() } 'SN section read for number of reads';
  my $expected = {forward => 18867148, reverse => 18867148, index => 18867148, total => 37734296};
  is_deeply ($s->num_reads(), $expected, 'paired reads - number of reads info is correct');
  ok ($s->has_reverse_read, 'has reverse read');
  ok (!$s->has_no_reads, 'has reads');

  # single run
  $s = npg_qc::autoqc::parse::samtools_stats->new( file_path =>
          't/data/samtools_stats/27053_1#1.single.stats');
  $expected = {forward => 5887348, reverse => 0, index => 5887348, total => 5887348};
  lives_ok { $s->num_reads() } 'SN section read for number of reads';
  is_deeply ($s->num_reads(), $expected, 'single read - number of reads info is correct');
  ok (!$s->has_reverse_read, 'does not have reverse read');
  ok (!$s->has_no_reads, 'has reads');   

  # zero reads
  $s = npg_qc::autoqc::parse::samtools_stats->new( file_path =>
          't/data/samtools_stats/27258_1#1.empty.stats');
  $expected = {forward => 0, reverse => 0, index => 0, total => 0};
  lives_ok { $s->num_reads() } 'SN section read for number of reads';
  is_deeply ($s->num_reads(), $expected, 'zero reads - number of reads info is correct');
  ok (!$s->has_reverse_read, 'does not have reverse read');
  ok ($s->has_no_reads, 'has no reads');  
};

subtest 'reads length' => sub {
  plan tests => 7;

  my $s = npg_qc::autoqc::parse::samtools_stats->new(
     file_content => [qw/content of the file/]);
  throws_ok { $s->reads_length }
    qr/SN section is missing/,
    'expected section not present - error';

  $s = npg_qc::autoqc::parse::samtools_stats->new(
     file_content => ['SN  some content']);
  throws_ok { $s->reads_length }
    qr/Failed to get reads length/,
    'data missing - error';

  $s = npg_qc::autoqc::parse::samtools_stats->new(
     file_content => ['SN  some fragments','SN  maximum first fragment length: 66',
                      'SN  some fragments',]);
  throws_ok { $s->reads_length }
    qr/Failed to get reads length/,
    'data missing - error';

  $s = npg_qc::autoqc::parse::samtools_stats->new(
     file_content => ['SN  some fragments','SN  maximum last fragment length: 66',
                      'SN  some fragments']);
  throws_ok { $s->reads_length }
    qr/Failed to get reads length/,
    'data missing - error';

  # paired run
  $s = npg_qc::autoqc::parse::samtools_stats->new( file_path =>
       't/data/samtools_stats/26607_1#20_F0xB00.stats');
  my $expected = {forward => 151, reverse => 151};
  is_deeply ($s->reads_length(), $expected, 'paired reads - number of reads info is correct');

  # single run
  $s = npg_qc::autoqc::parse::samtools_stats->new( file_path =>
          't/data/samtools_stats/27053_1#1.single.stats');
  $expected = {forward => 19, reverse => 0};
  is_deeply ($s->reads_length(), $expected, 'single read - number of reads info is correct'); 

  # zero reads
  $s = npg_qc::autoqc::parse::samtools_stats->new( file_path =>
          't/data/samtools_stats/27258_1#1.empty.stats');
  $expected = {forward => 0, reverse => 0};
  is_deeply ($s->reads_length(), $expected, 'zero reads - number of reads info is correct');  
};

subtest 'yield per cycle' => sub {
  plan tests => 18;

  my $s = npg_qc::autoqc::parse::samtools_stats->new(
     file_content => ['SN  some fragments',
                      'SN  1st fragments: 66',
                      'SN  last fragments: 66',
                      'SN  sequences: 132',
                      'SN  some fragments']);
  throws_ok { $s->yield_per_cycle('some') }
    qr/Invalid read name 'some', valid names: forward, reverse, index/,
    'invalid read name - error';
  throws_ok { $s->yield_per_cycle() }
    qr/FFQ section is missing/,
    'expected section not present - error';
  throws_ok { $s->yield_per_cycle('forward') }
    qr/FFQ section is missing/,
    'expected section not present - error';
  throws_ok { $s->yield_per_cycle('reverse') }
    qr/LFQ section is missing/,
    'expected section not present - error';

  # single run
  $s = npg_qc::autoqc::parse::samtools_stats->new( file_path =>
          't/data/samtools_stats/27053_1#1.single.stats');
  is ($s->yield_per_cycle('reverse'), undef,
    'yield for reverse read of a single run is undefined');
  my $m = $s->yield_per_cycle('forward');
  is (scalar @{$m}, 19, '19 cycles (matrix rows)');
  my @max_qs = uniq map {scalar @{$_}} @{$m};
  is (scalar @max_qs, 1, 'the same number of qs in every row');
  is ($max_qs[0], 39, 'max quality is 39');
  my $yield_index = $s->yield_per_cycle('index');
  ok ($yield_index, 'yield for index read of a single run is defined');
  is (scalar @{$yield_index}, 8, 'qualities for 8 cycles');

  # zero reads
  $s = npg_qc::autoqc::parse::samtools_stats->new( file_path =>
          't/data/samtools_stats/27258_1#1.empty.stats');
  is ($s->yield_per_cycle('reverse'), undef,
    'yield for reverse read of a no-reads run is undefined');
  is ($s->yield_per_cycle('forward'), undef,
    'yield for forward read of a no-reads run is undefined');
  is ($s->yield_per_cycle('index'), undef,
    'yield for index read of a no-reads run is undefined');

  # paired run
  $s = npg_qc::autoqc::parse::samtools_stats->new( file_path =>
          't/data/samtools_stats/26607_1#20_F0xB00.stats');
  $m = $s->yield_per_cycle('forward');
  is (scalar @{$m}, 151, '151 cycles (matrix rows)');
  @max_qs = uniq map {scalar @{$_}} @{$m};
  is (scalar @max_qs, 1, 'the same number of qs in every row');
  is ($max_qs[0], 43, 'max quality is 43');
  $yield_index = $s->yield_per_cycle('index');
  ok ($yield_index, 'yield for index read of a single run is defined');
  is (scalar @{$yield_index}, 16, 'qualities for 16 cycles');
};

subtest 'total yield' => sub {
  plan tests => 6;

  # single run
  my $s = npg_qc::autoqc::parse::samtools_stats->new( file_path =>
          't/data/samtools_stats/27053_1#1.single.stats');
  is ($s->yield('reverse'), undef,
    'yield for reverse read of a single run is undefined');

  # zero reads
  $s = npg_qc::autoqc::parse::samtools_stats->new( file_path =>
          't/data/samtools_stats/27258_1#1.empty.stats');
  is ($s->yield('reverse'), undef,
    'yield for reverse read of a no-reads run is undefined');
  is ($s->yield('forward'), undef,
    'yield for forward read of a no-reads run is undefined');

  # paired run
  $s = npg_qc::autoqc::parse::samtools_stats->new( file_path =>
          't/data/samtools_stats/26607_1#20_F0xB00.stats');
  my @qualities = qw/
  2848939348 2848665240 2848665240 2848665240 2848665240 2848665240
  2848665240 2848665240 2848665240 2845382644 2845382644 2845382644 
  2845382644 2663908405 2663908405 2663908405 2663908405 2663908405
  2663908405 2663908405 2663908405 2663908405 2663908405 2580989387
  2580989387 2580989387 2580989387 2580989387 2478258773 2478258773
  2478258773 2478258773 2478258773 2275245977 2275245977 2275245977
  2275245977 2275245977 1878230582 1878230582 1878230582 1878230582 0
                    /;
  my $i = 0;
  my %expected = map {$i++ => $_} @qualities;
  is_deeply ($s->yield('forward'), \%expected, 'yields for the forward read');

  @qualities = qw/
  2848939348 2848015822 2848015822 2848015822 2848015822 2848015822
  2848015822 2848015822 2848015822 2837420085 2837420085 2837420085
  2837420085 2416589137 2416589137 2416589137 2416589137 2416589137
  2416589137 2416589137 2416589137 2416589137 2416589137 2247692318
  2247692318 2247692318 2247692318 2247692318 2070762222 2070762222
  2070762222 2070762222 2070762222 1798802062 1798802062 1798802062
  1798802062 1798802062 1338093265 1338093265 1338093265 1338093265 0
                 /;
  $i = 0;
  %expected = map {$i++ => $_} @qualities;
  is_deeply ($s->yield('reverse'), \%expected, 'yields for the reverse read');

  # single run
  $s = npg_qc::autoqc::parse::samtools_stats->new( file_path =>
          't/data/samtools_stats/27053_1#1.single.stats');
  @qualities = qw/
  111859612 111858449 111858449 111858449 111858449 111858449 111858449
  111858449 111858449 111858449 111858449 111858449 111858449 111858449
  111858449 110288533 110288533 110288533 110288533 110288533 110288533
  110288533 110288533 110260084 110260084 110260084 110260084 110260084
  108430695 108430695 108430695 108430695 108430695 108430695 77368760
  77368760 77368760 77368760
                0/;
  $i = 0;
  %expected = map {$i++ => $_} @qualities;
  is_deeply ($s->yield('forward'), \%expected, 'yields for the forward read');  
};

subtest 'base composition' => sub {
  plan tests => 10;

  my $s = npg_qc::autoqc::parse::samtools_stats->new(
     file_content => ['SN  some fragments',
                      'SN  1st fragments: 66',
                      'SN  last fragments: 66',
                      'SN  sequences: 132',
                      'SN  some fragments']);
  throws_ok { $s-> base_composition('some') }
    qr/Invalid read name 'some', valid names: forward, reverse, index/,
    'invalid read name - error';
  throws_ok { $s->base_composition() }
    qr/FBC section is missing/,
    'expected section not present - error';
  throws_ok { $s-> base_composition('forward') }
    qr/FBC section is missing/,
    'expected section not present - error';
  throws_ok { $s-> base_composition('reverse') }
    qr/LBC section is missing/,
    'expected section not present - error';

  # single run
  $s = npg_qc::autoqc::parse::samtools_stats->new( file_path =>
          't/data/samtools_stats/27053_1#1.single.stats');
  is ($s-> base_composition('reverse'), undef,
    'base composition for reverse read of a single run is undefined');
  my $expected = { 'G' => 26.47, 'A' => 21.12,
                   'C' => 30.83, 'T' => 21.58 };
  is_deeply ($s->base_composition('forward'),
    $expected, 'gc fraction for the forward read');

  # zero reads
  $s = npg_qc::autoqc::parse::samtools_stats->new( file_path =>
          't/data/samtools_stats/27258_1#1.empty.stats');
  is ($s->base_composition('reverse'), undef,
    'base composition for reverse read of a no-reads run is undefined');
  is ($s->base_composition('forward'), undef,
    'base composition for forward read of a no-reads run is undefined');

  # paired run
  $s = npg_qc::autoqc::parse::samtools_stats->new( file_path =>
          't/data/samtools_stats/26607_1#20_F0xB00.stats');
  $expected = { 'G' => 9.46, 'A' => 40.53,
                'C' => 9.42, 'T' => 40.58 };
  is_deeply ($s->base_composition('forward'),
    $expected, 'gc fraction for the forward read');

  $expected = { 'C' => '9.62', 'A' => '40.35',
                'G' => '9.66', 'T' => '40.38' }; 
  is_deeply ($s->base_composition('reverse'),
    $expected, 'gc fraction for the reverse read');
};

subtest 'corrupt samtools stats file' => sub {
  plan tests => 1;

  my $s = npg_qc::autoqc::parse::samtools_stats->new( file_path =>
          't/data/samtools_stats/27138_1#2_F0xB00.stats');
  throws_ok { $s->yield('forward') } qr/FFQ section is missing/,
    'missing forward read quality section - error'; 
};

1;




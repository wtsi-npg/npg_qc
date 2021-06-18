use strict;
use warnings;
use File::Temp qw(tempdir);
use Test::More tests => 6;
use Test::Exception;
use Test::Warn;
use File::Path qw(make_path remove_tree);
use File::Copy::Recursive qw(dircopy);

use st::api::lims;

use_ok ('npg_qc::autoqc::checks::generic::artic');

my $tdir = tempdir( CLEANUP => 1 );
local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
  't/data/autoqc/generic/artic/samplesheet_35177.csv';
my $tm_file = 't/data/autoqc/generic/artic/35177_2.tag_metrics.json';

subtest 'object creation and input validaion' => sub {
  plan tests => 6;

  throws_ok {
    npg_qc::autoqc::checks::generic::artic->new(
            rpt_list     => '35177:2',
            pp_name      => 'artic',
            pp_version   => '0.10.0')
  } qr/tm_json_file.* is required/,
    'error if the tm_json_file attribute is not defined';

  my $g = npg_qc::autoqc::checks::generic::artic->new(
            rpt_list     => '35177:2',
            pp_name      => 'artic',
            pp_version   => '0.10.0',
            tm_json_file => $tm_file);
  isa_ok ($g, 'npg_qc::autoqc::checks::generic::artic');
  throws_ok { $g->execute }
    qr/input_files_glob should be defined/,
    'error when neither input_files nor input_files_glob is set';
  
  $g = npg_qc::autoqc::checks::generic::artic->new(
            rpt_list         => '35177:2',
            input_files_glob => q[],
            pp_name          => 'artic',
            pp_version       => '0.10.0',
            tm_json_file     => $tm_file);
  throws_ok { $g->execute }
    qr/input_files_glob value cannot be an empty string/,
    'error when input_files_glob is set to an empty string';

  throws_ok {npg_qc::autoqc::checks::generic::artic->new(
               rpt_list     => '35177:2',
               input_files  => [qw(t/data)],
               pp_name      => 'artic',
               pp_version   => '0.10.0',
               tm_json_file => $tm_file)
  } qr/does not pass the type constraint/,
    'error when inpt_file array member is not an existing file';
  
  $g = npg_qc::autoqc::checks::generic::artic->new(
            rpt_list     => '35177:2',
            input_files  =>
              [qw(t/data/autoqc/generic/artic/lane2/plex1/35177.qc.csv)],
            pp_name      => 'artic',
            pp_version   => '0.10.0',
            tm_json_file => $tm_file);
  lives_ok { $g->input_files } 'no error if input exists';
};

subtest 'read counts from the tag metrics' => sub {
  plan tests => 2;
 
  my $g = npg_qc::autoqc::checks::generic::artic->new(
            rpt_list     => '35178:2',
            input_files  =>
              [qw(t/data/autoqc/generic/artic/lane2/plex1/35177.qc.csv)],
            pp_name      => 'artic',
            pp_version   => '0.10.0',
            tm_json_file => $tm_file);
 
  throws_ok { $g->_reads_count } qr/does not correspond to 35178:2/,
    'tag metrics result and the check should be for the same entity';
  
  $g = npg_qc::autoqc::checks::generic::artic->new(
            rpt_list     => '35177:2',
            input_files  =>
              [qw(t/data/autoqc/generic/artic/lane2/plex1/35177.qc.csv)],
            pp_name      => 'artic',
            pp_version   => '0.10.0',
            tm_json_file => $tm_file);
  my $expected = {
    '157' => '78',
    '140' => '76',
    '160' => '154',
    '137' => '144',
    '207' => '163054',
    '159' => '1102571',
    '1' => '2250760',
    '4' => '1379258',
    '3' => '1965683',
    '205' => '123802',
    '206' => '434631',
    '97' => '68154',
    '2' => '1868353'
  };
  is_deeply ($g->_reads_count, $expected, 'correct read counts');
};

my @tag_indexes = (1..4,97,137,140,157,159,160,205..207);

subtest 'different types of input' => sub {
  plan tests => 16;

  my $g = npg_qc::autoqc::checks::generic::artic->new(
            rpt_list     => '35177:2',
            input_files  =>
              [qw(t/data/autoqc/generic/artic/lane2/plex1/35177.qc.csv
                  t/data/autoqc/generic/artic/lane2/plex4/35177.qc.csv)],
            pp_name      => 'artic',
            pp_version   => '0.10.0',
            tm_json_file => $tm_file);
  is (@{$g->input_files}, 2, '2 input files as set'); 
  is (@{$g->result}, 13, '13 result objects are created');
  my $test = {};
  my @components = map {$_->composition->get_component(0)} @{$g->result};
  map { $test->{$_->id_run} = 1 } @components;
  ok ($test->{35177} && (keys %{$test} == 1), 'all results belong to run 35177');
  $test = {};
  map { $test->{$_->position} = 1 } @components;
  ok ($test->{2} && (keys %{$test} == 1), 'all results belong to lane 2');
  is_deeply ([map {$_->tag_index} @components], \@tag_indexes,
    'tag indexes of results are correct and the array of results is sorted');
 
  # glob is not resolvable
  $g = npg_qc::autoqc::checks::generic::artic->new(
            rpt_list         => '35177:2',
            input_files_glob =>
              't/data/autoqc/generic/artic/lane12/plex*/*.qc.csv',
            pp_name          => 'artic',
            pp_version       => '0.10.0',
            tm_json_file     => $tm_file);
  warning_like { $g->input_files }
    qr/No files were found using glob/,
    'warning about the number of files found';
  is (@{$g->input_files}, 0, 'no input files'); 
  is (@{$g->result}, 13, '13 result objects are created');
  @components = map {$_->composition->get_component(0)} @{$g->result};
  is_deeply ([map {$_->tag_index} @components], \@tag_indexes,
    'tag indexes of results are correct');

  # glob is resolvable to a single file
  $g = npg_qc::autoqc::checks::generic::artic->new(
            rpt_list         => '35177:2',
            input_files_glob =>
              't/data/autoqc/generic/artic/lane2/plex4/*.qc.csv',
            pp_name          => 'artic',
            pp_version       => '0.10.0',
            tm_json_file     => $tm_file);
  warning_like { $g->input_files }
    qr/1 file was found using glob/,
    'warning about the number of files found';
  is (@{$g->input_files}, 1, '1 input file');
  is (@{$g->result}, 13, '13 result objects are created');
  
  # glob is resolvable, files should be retrieved
  $g = npg_qc::autoqc::checks::generic::artic->new(
            rpt_list         => '35177:2',
            input_files_glob =>
              't/data/autoqc/generic/artic/lane2/plex*/*.qc.csv',
            pp_name          => 'artic',
            pp_version       => '0.10.0',
            tm_json_file     => $tm_file);
  warning_like { $g->input_files }
    qr/11 files were found using glob/,
    'warning about the number of files found';
  is (@{$g->input_files}, 11, '11 input files');
  is (@{$g->result}, 13, '13 result objects are created');
  @components = map {$_->composition->get_component(0)} @{$g->result};
  is_deeply ([map {$_->tag_index} @components], \@tag_indexes,
    'tag indexes of results are correct');
};

subtest 'result objects - data capture' => sub {
  plan tests => 62;

  my $url = 'https://github.com/google/it-cert-automation-practice';
  my $g = npg_qc::autoqc::checks::generic::artic->new(
            rpt_list         => '35177:2',
            input_files_glob =>
              't/data/autoqc/generic/artic/lane2/plex*/*.qc.csv',
            pp_name          => 'artic',
            pp_version       => '0.10.0',
            pp_repo_url      => $url,
            tm_json_file     => $tm_file);
  # Artic QC summary is not available for plexes 3 and 206.
  # Tag metrics file contains data about 13 samples.
  warning_like { $g->execute }
    qr/11 files were found using glob/,
    'warning about the number of files found';
  my %results = map {
    $_->composition->get_component(0)->tag_index => $_
                    } @{$g->result};
  my @all_tags = sort {$a <=> $b} keys %results;
 
  is_deeply ([(sort {$a <=> $b} keys %{$g->_reads_count})], \@all_tags,
    'tag indexes of result objects match those from the tag metrix file');

  for my $ti (@all_tags) {
    if ($ti == 3 or $ti == 206) {
      ok (!exists $results{$ti}->doc()->{q[QC summary]},
        "tag $ti: artic qc summary is not set");
    } else {
      my $summary = $results{$ti}->doc()->{q[QC summary]};
      ok (($summary and (ref $summary eq q[HASH])),
        "tag $ti: artic qc summary is set and is a hash ref"); 
    }
  }

  my $expected_info = {
    Check => 'npg_qc::autoqc::checks::generic::artic',
    Check_version => $npg_qc::autoqc::checks::generic::artic::VERSION,
    Pipeline_name => 'artic',
    Pipeline_version => '0.10.0',
    Pipeline_repo_url => $url
  };

  my $lims = st::api::lims->new(id_run => 35177, position => 2)
                          ->children_ia;
  for my $ti (@all_tags) {
    my $r  = $results{$ti};
    my $li = $lims->{$ti};
    my $expected_meta = {
      num_input_reads      => $g->_reads_count->{$ti},
      supplier_sample_name => $li->sample_supplier_name,
      sample_type          => $li->sample_control_type ?
        $li->sample_control_type . q[_control] : 'real_sample',      
      min_artic_passed_filtered_read_count => 2159185,
      max_negative_control_filtered_read_count => 33,    
    };
    is_deeply ($r->doc->{meta}, $expected_meta,
      "tag $ti: meta info is set correctly"); 
    is_deeply ($r->info, $expected_info, "tag $ti: info is set correctly");
    is ($r->pp_name, 'artic', "tag $ti: pp_name attribute is set correctly");
  }

  # Test a few summaries
  my $expected_summary = {
    sample_name => '35177_2#2',
    pct_N_bases => '0.40',
    pct_covered_bases => '99.60',
    longest_no_N_run => 29783,
    num_aligned_reads => 3611874,
    fasta => '35177_2#2.primertrimmed.consensus.fa',
    bam => '35177_2#2.mapped.primertrimmed.sorted.bam',
    qc_pass => 'TRUE'
  };
  is_deeply ($results{2}->doc->{q[QC summary]}, $expected_summary,
    'QC summary for tag 2 is captured correctly');
  
  $expected_summary = {
    sample_name => '35177_2#97',
    pct_N_bases => '100.00',
    pct_covered_bases => '0.00',
    longest_no_N_run => 1,
    num_aligned_reads => 52,
    fasta => '35177_2#97.primertrimmed.consensus.fa',
    bam => '35177_2#97.mapped.primertrimmed.sorted.bam',
    qc_pass => 'FALSE'
  };
  is_deeply ($results{97}->doc->{q[QC summary]}, $expected_summary,
    'QC summary for tag 97 is captured correctly');

  dircopy('t/data/autoqc/generic/artic/lane2', "$tdir/lane2") or die
    'Failed to copy';
  my $empty = "$tdir/lane2/plex1/35177.qc.csv";
  unlink $empty or die "Failed to remove $empty";
  ok (!-e $empty, 'removed file');
  `touch $empty`;
  ok (-e $empty, 'empty file exists');
  $g = npg_qc::autoqc::checks::generic::artic->new(
            rpt_list         => '35177:2',
            input_files_glob => "$tdir/lane2/plex*/*.qc.csv",
            pp_name          => 'artic',
            pp_version       => '0.10.0',
            tm_json_file     => $tm_file);
  # Artic QC summary is not available for plexes 3 and 206, empty for plex 1
  # Tag metrics file contains data about 13 samples.
  warning_like { $g->execute }
    qr/11 files were found using glob/,
    'warning about the number of files found';
  %results = map {
    $_->composition->get_component(0)->tag_index => $_
                    } @{$g->result};
  @all_tags = sort {$a <=> $b} keys %results;
 
  is_deeply ([(sort {$a <=> $b} keys %{$g->_reads_count})], \@all_tags,
    'tag indexes of result objects match those from the tag metrix file');

  ok ($results{1}, 'result for tag index 1 is present');
  ok (!exists $results{1}->doc()->{q[QC summary]},
    "tag 1: artic qc summary is not set");
};

subtest 'saving JSON files' => sub {  
  plan tests => 34;

  my $init = {rpt_list => '35177:2',
              pp_name  => 'artic',
              pp_version => '0.10.0',
              tm_json_file => $tm_file,
              input_files_glob =>
               't/data/autoqc/generic/artic/lane2/plex*/*.qc.csv'};

  my $d1 = "$tdir/d1";
  mkdir $d1;
  my $d2 = "$tdir/d2";
  mkdir $d2;
  my $d3 = "$tdir/d3";
  mkdir $d3;

  # Two qc_out directories. Only the first one will be used.
  npg_qc::autoqc::checks::generic::artic->new(
    %{$init}, qc_out => [$d1, $d2]
  )->run();
  my @files = glob "$d2/*.json";
  is (@files, 0, 'no output files in the second directory');
  @files = glob "$d1/*.json";
  is (@files, 13, 'all files are in the first directory');

  # qc_out and sample_qc_out as a directory, the latter is used.
  npg_qc::autoqc::checks::generic::artic->new(
    %{$init}, qc_out => [$d2], sample_qc_out => $d3
  )->run();
  @files = glob "$d2/*.json";
  is (@files, 0, 'no output files in the qc_out directory');
  @files = glob "$d1/*.json";
  is (@files, 13, 'all files are in the sample_qc_out directory');
 
  # sample_qc_out directory glob, which resolves to multiple directories.
  my @ti = qw/0 1 2 3 4 5 97 137 140 157 159 160 205 206 207 208/;
  map { make_path "$tdir/plex$_/qc" } @ti; 

  npg_qc::autoqc::checks::generic::artic->new(
    %{$init}, sample_qc_out => "$tdir/plex*/qc"
  )->run();
  for (@ti) {
    my $dir = "$tdir/plex$_/qc";
    my @fs = glob "$dir/*.json";
    if (($_ eq 0) or ($_ eq 5) or ($_ eq 208)) {
      is (@fs, 0, "no output files in $dir");
    } else {
      is (@fs, 1, "one file in $dir");
      is ($fs[0], "$dir/35177_2#$_.artic.generic.json", 'correct file name'); 
    }
  }
  # sample_qc_out directory glob, match results with directories
  remove_tree "$tdir/plex97/qc";
  remove_tree "$tdir/plex205/qc";
  throws_ok { npg_qc::autoqc::checks::generic::artic->new(
    %{$init}, sample_qc_out => "$tdir/plex*/qc")->run()
  } qr/No directory match for tag 97/,
    'error when the first mismatch is encountered';
};

1;

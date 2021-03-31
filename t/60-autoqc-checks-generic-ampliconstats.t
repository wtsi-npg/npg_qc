use strict;
use warnings;
use File::Temp qw/tempdir/;
use Test::More tests => 6;
use Test::Exception;

use st::api::lims;

use_ok ('npg_qc::autoqc::checks::generic::ampliconstats');

my $tdir = tempdir( CLEANUP => 1 );
local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
  q[t/data/autoqc/generic/ampliconstats/samplesheet_34719.csv];
my $file = q[t/data/autoqc/generic/ampliconstats/34719_1.ampstats];
my $bed_dir = q[/lustre/scratch121/npg_repository/primer_panel/nCoV-2019/V3/SARS-CoV-2/MN908947.3];

subtest 'object with basic constructor arguments' => sub {
  plan tests => 23;

  my $g = npg_qc::autoqc::checks::generic::ampliconstats->new(
            rpt_list    => '34719:1',
            input_files => [$file],
            qc_out      => $tdir,
            pp_name     => 'ampliconstats',
            ampstats_section => [qw/FREADS/]);
  isa_ok ($g, 'npg_qc::autoqc::checks::generic::ampliconstats');
  is_deeply ($g->result, [], 'result attribute is built as an empty array');
  is ($g->pp_name, 'ampliconstats', 'default pp_name');
  
  lives_ok { $g->execute() } 'no error running execute() method';
  is (@{$g->result}, 258, '258 result objects created');

  my $result = $g->result->[0];
  isa_ok ($result, 'npg_qc::autoqc::results::samtools_stats');
  is ($result->composition->freeze2rpt, '34719:1',
    'first result object is for a lane');
  is ($result->filter, 'ampliconstats', 'correct samtools stats filter');
  is_deeply ($result->info, {
    'Check' => 'npg_qc::autoqc::checks::generic::ampliconstats',
    'Check_version' => $npg_qc::autoqc::checks::generic::ampliconstats::VERSION,
    'Samtools_version' => '1.10-88-g2281338',
    'Samtools_command' => 'ampliconstats -@8 -t 50 -d 1,10,20,100 ' . "$bed_dir/nCoV-2019.bed",
                            }, 'correct info');
 
  $result = $g->result->[5];
  isa_ok ($result, 'npg_qc::autoqc::results::generic');
  is ($result->composition->freeze2rpt, '34719:1:5', 
    'generic result object is for a sample');
  is ($result->pp_name, 'ampliconstats', 'default pp name is set');
  is_deeply ($result->doc->{meta},
    {'supplier_sample_name' => 'LOND-D902E', 'sample_type' => 'real_sample'},
    'correct sample meta present');
  is ($result->doc->{amplicon_stats}->{num_amplicons}, 98,
    'correct number of amplicons');
  is (@{$result->doc->{amplicon_stats}->{FREADS}}, 98,
    'array of 98 for FREADS');
  is (keys %{$result->doc->{amplicon_stats}}, 2, 'no extra keys');
  is_deeply ($result->info, {
    'Check' => 'npg_qc::autoqc::checks::generic::ampliconstats',
    'Check_version' => $npg_qc::autoqc::checks::generic::ampliconstats::VERSION,
    'Samtools_version' => '1.10-88-g2281338',
    'Samtools_command' => 'ampliconstats -@8 -t 50 -d 1,10,20,100 ' . "$bed_dir/nCoV-2019.bed",
    'Pipeline_name' => 'ampliconstats',
    'Pipeline_version' => '1.10-88-g2281338'
                            }, 'correct info');

  $g = npg_qc::autoqc::checks::generic::ampliconstats->new(
            rpt_list    => '34719:1',
            input_files => [$file],
            qc_out      => $tdir,
            pp_name     => 'ampliconstats',
            ampstats_section => [qw/FREADS/]);
  lives_ok { $g->run() } 'no error running run() method';
  my @jsons = glob "$tdir/*.json";
  is (scalar @jsons, 258, 'number of JSON output files');
  ok (!-e "$tdir/34719_1.ampliconstats.generic.json",
    'lane-level generic result does not exist');
  ok (-e "$tdir/34719_1_ampliconstats.samtools_stats.json",
    'lane-level samtools_stats result exists');
  ok (-e "$tdir/34719_1#5.ampliconstats.generic.json",
    'plex-level generic result exists');
  ok (!-e "$tdir/34719_1#5_ampliconstats.samtools_stats.json",
    'plex-level samtools stats result does not exist');
};

subtest 'multiple sections' => sub {
  plan tests => 8;

  my @sections = qw/FREADS FPCOV-1 FPCOV-10 FPCOV-20 FPCOV-100/;

  my $g = npg_qc::autoqc::checks::generic::ampliconstats->new(
    rpt_list    => '34719:1',
    input_files => [$file],
    qc_out      => $tdir,
    pp_name     => 'ampliconstats',
    ampstats_section => \@sections);
  $g->execute();
  is (@{$g->result}, 258, '258 result objects created');
  my $result = $g->result->[5];
  is ($result->doc->{amplicon_stats}->{num_amplicons}, 98,
    'correct number of amplicons');
  for my $s (@sections) {
    is (@{$result->doc->{amplicon_stats}->{$s}}, 98,
      "array of 98 for $s");
  }
  is (keys %{$result->doc->{amplicon_stats}}, 6, 'six keys');
};

subtest 'no sections or invalid section name' => sub {
  plan tests => 6;

  my $g = npg_qc::autoqc::checks::generic::ampliconstats->new(
            rpt_list    => '34719:1',
            input_files => [$file],
            pp_name     => 'ampliconstats',
            qc_out      => $tdir);
  $g->execute();
  is (@{$g->result}, 1, 'one result object created');
  isa_ok ($g->result->[0], 'npg_qc::autoqc::results::samtools_stats');
  
  lives_ok { npg_qc::autoqc::checks::generic::ampliconstats->new(
               rpt_list    => '34719:1',
               input_files => [$file],
               pp_name     => 'ampliconstats',               
               qc_out      => $tdir)->run() } 'no error';

  $g = npg_qc::autoqc::checks::generic::ampliconstats->new(
            rpt_list    => '34719:1',
            input_files => [$file],
            qc_out      => $tdir,
            pp_name     => 'ampliconstats',
            ampstats_section => [qw/ABCDF KLMNP/]);
  $g->execute();
  is (@{$g->result}, 1, 'one result object created');
  isa_ok ($g->result->[0], 'npg_qc::autoqc::results::samtools_stats');

  lives_ok { npg_qc::autoqc::checks::generic::ampliconstats->new(
               rpt_list    => '34719:1',
               input_files => [$file],
               qc_out      => $tdir,
               pp_name     => 'ampliconstats',
               ampstats_section => [qw/ABCDF KLMNP/])->run() } 'no error'; 
};

subtest 'object with pp_name and a directory for samples' => sub {
  plan tests => 17;
  
  my $d1 = "$tdir/1";
  mkdir $d1;
  my $d2 = "$tdir/2";
  mkdir $d2;

  my $pp_name = 'ncov2019-artic-nf_ampliconstats';

  my $g = npg_qc::autoqc::checks::generic::ampliconstats->new(
            rpt_list    => '34719:1',
            input_files => [$file],
            qc_out      => $d1,
            sample_qc_out => $d2,
            pp_name => $pp_name,
            ampstats_section => [qw/FREADS/]);
  $g->execute();
  is (@{$g->result}, 258, '258 result objects created');

  my $result = $g->result->[0];
  isa_ok ($result, 'npg_qc::autoqc::results::samtools_stats');
  is ($result->composition->freeze2rpt, '34719:1',
    'first result object is for a lane');

  $result = $g->result->[5];
  isa_ok ($result, 'npg_qc::autoqc::results::generic');
  is ($result->composition->freeze2rpt, '34719:1:5',
    'generic result object is for a sample');
  is ($result->pp_name, $pp_name, 'default pp name is set');
  is_deeply ($result->doc->{meta},
    {'supplier_sample_name' => 'LOND-D902E', 'sample_type' => 'real_sample'},
    'correct sample meta present');
  is ($result->doc->{amplicon_stats}->{num_amplicons}, 98,
    'correct number of amplicons');
  is (@{$result->doc->{amplicon_stats}->{FREADS}}, 98,
    'array of 98 for FREADS');
  is (keys %{$result->doc->{amplicon_stats}}, 2, 'no extra keys');
  is_deeply ($result->info, {
    'Check' => 'npg_qc::autoqc::checks::generic::ampliconstats',
    'Check_version' => $npg_qc::autoqc::checks::generic::ampliconstats::VERSION,
    'Samtools_version' => '1.10-88-g2281338',
    'Samtools_command' => 'ampliconstats -@8 -t 50 -d 1,10,20,100 ' . "$bed_dir/nCoV-2019.bed",
    'Pipeline_name' => $pp_name,
    'Pipeline_version' => '1.10-88-g2281338'
                            }, 'correct info');

  $g = npg_qc::autoqc::checks::generic::ampliconstats->new(
            rpt_list    => '34719:1',
            input_files => [$file],
            qc_out      => $d1,
            sample_qc_out => $d2,
            pp_name => $pp_name,
            ampstats_section => [qw/FREADS/]);
  $g->run();

  my @jsons = glob "$d1/*.json";
  is (scalar @jsons, 1, 'one JSON file in dir_out');
  @jsons = glob "$d2/*.json";
  is (scalar @jsons, 257, 'number of JSON files in sample_dir_out');
  ok (!-e "$d1/34719_1.${pp_name}.generic.json",
    'lane-level generic result does not exist');
  ok (-e "$d1/34719_1_ampliconstats.samtools_stats.json",
    'lane-level samtools_stats result exists');
  ok (-e "$d2/34719_1#5.${pp_name}.generic.json",
    'plex-level generic result exists');
  ok (!-e "$d2/34719_1#5_ampliconstats.samtools_stats.json",
    'plex-level samtools stats result does not exist');
};

subtest 'object with pp version and a sample dir glob' => sub {
  plan tests => 271;

  my $d3 = "$tdir/3";
  mkdir $d3;
  for my $tag ( (1 .. 257) ) {
    my $dir = "$d3/plex${tag}";
    mkdir $dir;
    $dir = "$dir/qc";
    mkdir $dir;
  }
  my $dir_glob = "${d3}/plex*/qc";

  my $pp_name = 'ncov2019-artic-nf_ampliconstats';
  my $pp_version = 'v.0.10.0';

  my $g = npg_qc::autoqc::checks::generic::ampliconstats->new(
            rpt_list    => '34719:1',
            input_files => [$file],
            qc_out      => $d3,
            sample_qc_out => $dir_glob,
            pp_name => $pp_name,
            pp_version => $pp_version,
            ampstats_section => [qw/FREADS/]);
  $g->execute();
  is (@{$g->result}, 258, '258 result objects created');

  my $result = $g->result->[0];
  isa_ok ($result, 'npg_qc::autoqc::results::samtools_stats');
  is ($result->composition->freeze2rpt, '34719:1',
    'first result object is for a lane');

  $result = $g->result->[5];
  isa_ok ($result, 'npg_qc::autoqc::results::generic');
  is ($result->composition->freeze2rpt, '34719:1:5',
    'generic result object is for a sample');
  is ($result->pp_name, $pp_name, 'default pp name is set');
  is_deeply ($result->doc->{meta},
    {'supplier_sample_name' => 'LOND-D902E', 'sample_type' => 'real_sample'},
    'correct sample meta present');
  is ($result->doc->{amplicon_stats}->{num_amplicons}, 98,
    'correct number of amplicons');
  is (@{$result->doc->{amplicon_stats}->{FREADS}}, 98,
    'array of 98 for FREADS');
  is (keys %{$result->doc->{amplicon_stats}}, 2, 'no extra keys');
  is_deeply ($result->info, {
    'Check' => 'npg_qc::autoqc::checks::generic::ampliconstats',
    'Check_version' => $npg_qc::autoqc::checks::generic::ampliconstats::VERSION,
    'Samtools_version' => '1.10-88-g2281338',
    'Samtools_command' => 'ampliconstats -@8 -t 50 -d 1,10,20,100 ' . "$bed_dir/nCoV-2019.bed",
    'Pipeline_name' => $pp_name,
    'Pipeline_version' => "$pp_version 1.10-88-g2281338"
                            }, 'correct info');

  $g = npg_qc::autoqc::checks::generic::ampliconstats->new(
            rpt_list    => '34719:1',
            input_files => [$file],
            qc_out      => $d3,
            sample_qc_out => $dir_glob,
            pp_name => $pp_name,
            pp_version => $pp_version,
            ampstats_section => [qw/FREADS/]);
  $g->run();

  my @jsons = glob "$d3/*.json";
  is (scalar @jsons, 1, 'one JSON file in dir_out');
  ok (-e "$d3/34719_1_ampliconstats.samtools_stats.json",
    'lane-level samtools_stats result exists');
  @jsons = glob "$dir_glob/*.json";
  is (scalar @jsons, 257, 'number of JSON files in sample_dir_out');

  for my $tag ( (1 .. 257) ) {
    my $dir = "$d3/plex${tag}";
    ok (-e "$dir/qc/34719_1#${tag}.${pp_name}.generic.json",
      "generic result for tag $tag exists");
  }
};

1;

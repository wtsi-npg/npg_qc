use strict;
use warnings;
use Test::More tests => 5;
use Test::Exception;
use Cwd;
use File::Spec::Functions qw(catfile);

my $repos = cwd . '/t/data/autoqc';

use_ok ('npg_qc::autoqc::checks::gc_fraction');

subtest 'constructing an object, finding input files' => sub {
  plan tests => 5;

  my $check = npg_qc::autoqc::checks::gc_fraction->new(
    position   => 4,
    qc_in      => 't/data/samtools_stats',
    id_run     => 2549,
    repository => $repos 
  );
  isa_ok($check, 'npg_qc::autoqc::checks::gc_fraction');
  throws_ok { $check->input_files }
    qr{t/data/samtools_stats/2549_4_F0xB00.stats file not found},
    'error when input not found';

  $check = npg_qc::autoqc::checks::gc_fraction->new(
    qc_in      => 't/data/samtools_stats',
    position   => 1,
    id_run     => 26607,
    tag_index  => 20,
    repository => $repos 
  );
  
  my @files;
  lives_ok { @files = @{$check->input_files} }
    'input files found';
  ok (@files && @files == 1, 'input files list has a single entry');
  is ($files[0], 't/data/samtools_stats/26607_1#20_F0xB00.stats',
    'correct file found');
};

subtest 'computing results for a paired run' => sub {
  plan tests => 14;

  my $check = npg_qc::autoqc::checks::gc_fraction->new(
    path                => 't/data/samtools_stats',
    position            => 1,
    id_run              => 26607,
    tag_index           => 20,
    ref_base_count_path => q[],
    repository          => $repos 
  );
  isa_ok ($check, 'npg_qc::autoqc::checks::gc_fraction');
  $check->execute();
 
  is($check->result->pass, undef, 'pass undefined');
  is($check->result->threshold_difference, 20 , 'threshold difference');
  is($check->result->ref_gc_percent, undef, 'reference gc content undefined');

  my $gc_string = sprintf("%.1f", $check->result->forward_read_gc_percent);
  is($gc_string, '18.9', 'forward read gc percent');
  $gc_string = sprintf("%.1f", $check->result->reverse_read_gc_percent);
  is($gc_string, '19.3', 'reverse read gc percent');

  is($check->result->forward_read_filename, q[26607_1#20_F0xB00.stats], 'file name');
  is($check->result->reverse_read_filename, q[26607_1#20_F0xB00.stats], 'file name');

  is($check->ref_base_count_path, q[], 'base count path undefined');

  $check = npg_qc::autoqc::checks::gc_fraction->new(
    path                => 't/data/samtools_stats',
    position            => 1,
    id_run              => 26607,
    tag_index           => 20,
    ref_base_count_path => q[],
    repository          => $repos,
    is_paired_read      => 1
  );
  $check->execute();

  $gc_string = sprintf("%.1f", $check->result->forward_read_gc_percent);
  is($gc_string, '18.9', 'forward read gc percent');
  $gc_string = sprintf("%.1f", $check->result->reverse_read_gc_percent);
  is($gc_string, '19.3', 'reverse read gc percent');

  $check = npg_qc::autoqc::checks::gc_fraction->new(
    path                => 't/data/samtools_stats',
    position            => 1,
    id_run              => 26607,
    tag_index           => 20,
    ref_base_count_path => q[],
    repository          => $repos,
    is_paired_read      => 0
  );
  $check->execute();

  $gc_string = sprintf("%.1f", $check->result->forward_read_gc_percent);
  is($gc_string, '18.9', 'forward read gc percent');
  is($check->result->reverse_read_gc_percent, undef, 'no data for reverse read');
  is($check->result->reverse_read_filename, undef, 'reverse file name undefined');
};

subtest 'computing results for a run with no reads' => sub {
  plan tests => 9;

  my $bc_path = catfile(cwd, q[t/data/autoqc/gc_fraction/Homo_sapiens.NCBI36.48.dna.all.fa]);
 
  my $check = npg_qc::autoqc::checks::gc_fraction->new(
    qc_in               => 't/data/samtools_stats',
    rpt_list            => '26597:1:38',
    ref_base_count_path => $bc_path,
    repository          => $repos,
    is_paired_read      => 1
  );

  $check->execute();
 
  is($check->result->pass, 0, 'check failed - no reads');
  is($check->result->threshold_difference, 20 , 'threshold difference');

  my $gc_string = sprintf("%.2f", $check->result->ref_gc_percent);
  is($gc_string, '40.89', 'reference gc content');
  $gc_string = sprintf("%.1f", $check->result->forward_read_gc_percent);
  is($gc_string, '0.0', 'forward read gc percent zero');
  $gc_string = sprintf("%.1f", $check->result->reverse_read_gc_percent);
  is($gc_string, '0.0', 'reverse read gc percent zero');
  is($check->result->forward_read_filename, q[26597_1#38_F0xB00.stats], 'file name');
  is($check->result->reverse_read_filename, q[26597_1#38_F0xB00.stats], 'file name');
  is($check->ref_base_count_path, $bc_path, 'base count path');
  is($check->result->comments, undef, 'no comments');
};

subtest 'computing results for a single run' => sub {
  plan tests => 7;

  local $ENV{'NPG_CACHED_SAMPLESHEET_FILE'} = q[t/data/autoqc/gc_fraction/samplesheet_27138.csv];
  my $check = npg_qc::autoqc::checks::gc_fraction->new(
    qc_in       => 't/data/autoqc/gc_fraction',
    input_files => ['t/data/samtools_stats/27053_1#1.single.stats'],
    position    => 1,
    id_run      => 27053,
    tag_index   => 1,
    repository  => $repos 
  );
  $check->execute();
 
  is($check->result->threshold_difference, 20 , 'threshold difference');
  is($check->result->ref_gc_percent, undef, 'reference gc content undefined');

  my $gc_string = sprintf("%.1f", $check->result->forward_read_gc_percent);
  is($gc_string, '57.3', 'forward read gc percent');
  is ($check->result->reverse_read_gc_percent, undef, 'value for reverse read is undefined');

  is($check->result->forward_read_filename, q[27053_1#1.single.stats], 'file name');
  is($check->result->reverse_read_filename, undef, 'reverse file name undefined');

  is($check->ref_base_count_path, undef, 'base count path undefined');  
};

1;

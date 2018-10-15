use strict;
use warnings;
use Test::More tests => 5;
use Test::Exception;

use_ok('npg_qc::autoqc::checks::qX_yield');

subtest 'constructing an object, finding input files' => sub {
  plan tests => 5;

  my $check = npg_qc::autoqc::checks::qX_yield->new(
    position => 4,
    qc_in    => 't/data/samtools_stats',
    id_run   => 2549, 
  );
  isa_ok($check, 'npg_qc::autoqc::checks::qX_yield');
  throws_ok { $check->input_files }
    qr{t/data/samtools_stats/2549_4_F0xB00.stats file not found},
    'error when input not found';

  $check = npg_qc::autoqc::checks::qX_yield->new(
    qc_in     => 't/data/samtools_stats',
    position  => 1,
    id_run    => 26607,
    tag_index => 20
  );
  
  my @files;
  lives_ok { @files = @{$check->input_files} }
    'input files found';
  ok (@files && @files == 1, 'input files list has a single entry');
  is ($files[0], 't/data/samtools_stats/26607_1#20_F0xB00.stats',
    'correct file found');
};

subtest 'computing results for a paired run' => sub {
  plan tests => 6;

  my $check = npg_qc::autoqc::checks::qX_yield->new(
    position  => 4,
    qc_in     => 't/data/samtools_stats',
    id_run    => 2549, 
  );
  throws_ok {$check->execute}
    qr{t/data/samtools_stats/2549_4_F0xB00.stats file not found},
    'error when input not found';

  $check = npg_qc::autoqc::checks::qX_yield->new(
    input_files => ['t/data/samtools_stats/26607_1#20_F0xB00.stats'],
    position    => 1,
    id_run      => 26607
  );
  $check->execute();
 
  my $e =  npg_qc::autoqc::checks::qX_yield->new(
    input_files => ['t/data/samtools_stats/26607_1#20_F0xB00.stats'],
    position    => 1,
    id_run      => 26607
  );

  my $set_result_values = sub {
    my $ec = shift;
    $ec->result->threshold_quality(20);
    $ec->result->yield1(2663908);
    $ec->result->yield2(2416589);
    $ec->result->yield1_q30(2478259);
    $ec->result->yield2_q30(2070762);
    $ec->result->yield1_q40(1878231);
    $ec->result->yield2_q40(1338093);
    $ec->result->filename1(q[26607_1#20_F0xB00.stats]);
    $ec->result->filename2(q[26607_1#20_F0xB00.stats]);
    return;
  };
  
  $set_result_values->($e);
  is_deeply ($check->result, $e->result, 'lane-level result object for a paired run');

  $check = npg_qc::autoqc::checks::qX_yield->new(
    input_files    => ['t/data/samtools_stats/26607_1#20_F0xB00.stats'],
    position       => 1,
    id_run         => 26607,
    is_paired_read => 1
  );
  $check->execute();
  is_deeply ($check->result, $e->result, 'setting pairedness explicitly');

  $check = npg_qc::autoqc::checks::qX_yield->new(
    qc_in       => 't/data/samtools_stats',
    position    => 1,
    id_run      => 26607,
    tag_index   => 20
  );
  $check->execute();

  $e =  npg_qc::autoqc::checks::qX_yield->new(
    input_files => ['t/data/samtools_stats/26607_1#20_F0xB00.stats'],
    position    => 1,
    id_run      => 26607,
    tag_index   => 20
  );
  $set_result_values->($e);
  $e->result->path('t/data/samtools_stats');
  is_deeply ($check->result, $e->result, 'plex-level result object for a paired run');

  $check = npg_qc::autoqc::checks::qX_yield->new(
    input_files => ['t/data/samtools_stats/26607_1#20_F0xB00.stats'],
    position    => 1,
    id_run      => 26607,
    platform_is_hiseq => 1
  );

  $check->execute();

  $e =  npg_qc::autoqc::checks::qX_yield->new(
    input_files => ['t/data/samtools_stats/26607_1#20_F0xB00.stats'],
    position    => 1,
    id_run      => 26607
  );
  $set_result_values->($e);
  $e->result->threshold_yield1(10066667);
  $e->result->threshold_yield2(10066667);
  $e->result->pass(0);

  is_deeply($check->result, $e->result,
    'result object for a paired run (marked as HiSeq run)');

  $check = npg_qc::autoqc::checks::qX_yield->new(
    input_files => ['t/data/samtools_stats/26818_4_F0xB00.stats'],
    position    => 4,
    id_run      => 26818,
    platform_is_hiseq => 1
  );

  $check->execute();

  $e =  npg_qc::autoqc::checks::qX_yield->new(
    input_files => ['t/data/samtools_stats/26818_4_F0xB00.stats'],
    position    => 4,
    id_run      => 26818
  );
  $e->result->threshold_quality(20);
  $e->result->yield1(428744056);
  $e->result->yield2(423637981);
  $e->result->yield1_q30(410924852);
  $e->result->yield2_q30(399863066);
  $e->result->yield1_q40(0);
  $e->result->yield2_q40(0);
  $e->result->filename1(q[26818_4_F0xB00.stats]);
  $e->result->filename2(q[26818_4_F0xB00.stats]);
  $e->result->threshold_yield1(10066667);
  $e->result->threshold_yield2(10066667);
  $e->result->pass(1);

  is_deeply($check->result, $e->result,
    'result object for a paired run (marked as HiSeq run)');  
};

subtest 'computing results for a run with no reads' => sub {
  plan tests => 3;

  my $check = npg_qc::autoqc::checks::qX_yield->new(
    qc_in     => 't/data/samtools_stats',
    position  => 1,
    id_run    => 26597
  );
  $check->execute();

  my $e = npg_qc::autoqc::checks::qX_yield->new(
    position    => 1,
    id_run      => 26597,
    input_files => ['t/data/samtools_stats/26597_1_F0xB00.stats']
  );
  $e->id_run;
  $e->result->pass(0);
  $e->result->threshold_quality(20);
  $e->result->yield1(0);
  $e->result->yield1_q30(0);
  $e->result->yield1_q40(0);
  $e->result->filename1(q[26597_1_F0xB00.stats]);
  $e->result->path('t/data/samtools_stats');

  is_deeply ($check->result, $e->result, 'result for no reads');

  $check = npg_qc::autoqc::checks::qX_yield->new(
    qc_in          => 't/data/samtools_stats',
    position       => 1,
    id_run         => 26597,
    is_paired_read => 0
  );
  $check->execute();
  is_deeply ($check->result, $e->result, 'result for no reads, single reads');

  $check = npg_qc::autoqc::checks::qX_yield->new(
    qc_in          => 't/data/samtools_stats',
    position       => 1,
    id_run         => 26597,
    is_paired_read => 1
  );
  $check->execute();

  $e = npg_qc::autoqc::checks::qX_yield->new(
    position    => 1,
    id_run      => 26597,
    input_files => ['t/data/samtools_stats/26597_1_F0xB00.stats']
  );
  $e->id_run;
  $e->result->pass(0);
  $e->result->threshold_quality(20);
  $e->result->yield1(0);
  $e->result->yield1_q30(0);
  $e->result->yield1_q40(0);
  $e->result->yield2(0);
  $e->result->yield2_q30(0);
  $e->result->yield2_q40(0);
  $e->result->filename1(q[26597_1_F0xB00.stats]);
  $e->result->filename2(q[26597_1_F0xB00.stats]);
  $e->result->path('t/data/samtools_stats');

  is_deeply ($check->result, $e->result, 'result for no reads, paired reads');
};

subtest 'computing results for a single read run' => sub {
  plan tests => 1;

  my $check = npg_qc::autoqc::checks::qX_yield->new(
    qc_in             => 't/data/samtools_stats',
    input_files => ['t/data/samtools_stats/27053_1#1.single.stats'],
    position          => 8,
    id_run            => 25980,
    tag_index         => 8,
    platform_is_hiseq => 1
  );
  $check->execute();

  my $e = npg_qc::autoqc::checks::qX_yield->new(
    qc_in       => 't/data/samtools_stats',
    position    => 8,
    id_run      => 25980,
    tag_index   => 8,
    platform_is_hiseq => 1,
    input_files => ['t/data/samtools_stats/27053_1#1.single.stats'],
  );
  $e->result->threshold_quality(20);
  $e->result->yield1(110289);
  $e->result->yield1_q30(108431);
  $e->result->yield1_q40(0);
  $e->result->filename1(q[27053_1#1.single.stats]);

  is_deeply($check->result, $e->result, 'result object for a single end run');
};

1;




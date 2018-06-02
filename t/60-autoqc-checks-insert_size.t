use strict;
use warnings;
use Test::More tests => 61;
use Test::Exception;
use Test::Deep;
use Perl6::Slurp;
use JSON;
use Cwd qw(cwd);
use File::Spec::Functions qw(catfile);
use File::Temp qw/ tempdir /;

use npg_tracking::util::abs_path qw(abs_path);
use t::autoqc_util;

my $current_dir = cwd();

local $ENV{'http_proxy'} = 'wibble.com';
local $ENV{'no_proxy'} = q[];
local $ENV{'NPG_WEBSERVICE_CACHE_DIR'} = q[t/data/autoqc/insert_size];
local $ENV{'PATH'} = join q[:], qq[$current_dir/blib/script] , $ENV{'PATH'};
my $repos = catfile($current_dir, q[t/data/autoqc]);
my $ref = catfile($repos, q[references]);
my $format = q[sam];
my $test_bam = 0;
my $norm_fit = `which norm_fit`;
chomp $norm_fit;
$norm_fit = abs_path($norm_fit);

use_ok('npg_qc::autoqc::results::insert_size');
use_ok('npg_qc::autoqc::checks::insert_size');

sub _additional_modules {
  my $use_fastx = shift;
  my @expected = ();
  require npg_qc::autoqc::parse::alignment;
  push @expected, join(q[ ],
    'npg_qc::autoqc::parse::alignment', $npg_qc::autoqc::parse::alignment::VERSION);
  require npg_common::extractor::fastq;
  push @expected, join(q[ ],
    q[npg_common::extractor::fastq], $npg_common::extractor::fastq::VERSION);
  require npg_common::Alignment;
  push @expected, join(q[ ],
    q[npg_common::Alignment], $npg_common::Alignment::VERSION);
  if ($use_fastx) {
    push @expected, q[FASTX Toolkit fastx_reverse_complement 0.0.12];
  }
  push @expected, join(q[ ], $norm_fit, $npg_qc::autoqc::results::insert_size::VERSION);
  return @expected;
}

{
  my $qc = npg_qc::autoqc::checks::insert_size->new(
    id_run => 2549, position => 2, path => 't/data/autoqc/090721_IL29_2549/data', repository => $repos);
  isa_ok($qc, 'npg_qc::autoqc::checks::insert_size', 'is test');

  throws_ok {$qc->execute()} qr/Reverse run fastq file is missing/, 'error on reverse fastq file missing';
}

{
  my $qc = npg_qc::autoqc::checks::insert_size->new(
                                              position  => 1, 
                                              path      => 't/data/autoqc', 
                                              id_run    => 1937,
                                              repository => $repos, 
                                                   );
  is($qc->can_run, 1, 'check can_run for a paired run');
}

{
  my $qc = npg_qc::autoqc::checks::insert_size->new(
                                              position  => 1, 
                                              path      => 't/data/autoqc', 
                                              id_run    => 3871,
                                              repository => $repos, 
                                                   );
  is($qc->can_run, 0, 'check can_run for a single run');
}

{
  my $dir = tempdir( CLEANUP => 1 );
  t::autoqc_util::write_bwa_script(catfile($dir, 'bwa'));
  local $ENV{PATH} = join ':', $dir,  $ENV{PATH};

  my $qc = npg_qc::autoqc::checks::insert_size->new(
                                           position => 1, 
                                           path => 't/data/autoqc', 
                                           id_run => 1937,
                                           repository => $repos, 
                                           reference => $ref,
                                           use_reverse_complemented => 0,
                                           expected_size => [350,350],
                                                   );
  $qc->execute();
  is ($qc->actual_sample_size, 12500, 'actual sample size in the check object');
  is ($qc->result->sample_size, 12500, 'actual sample size in the result object');
}

{
  my $qc = npg_qc::autoqc::checks::insert_size->new(
                                              position  => 3, 
                                              path      => 't/data/autoqc', 
                                              id_run    => 1937,
                                              repository => $repos,
                                                   );

  is($qc->_enforce_number(q[ 7]), 7, 'parse pure int and space in front');
  is($qc->_enforce_number(q[7.6 ]), 7, 'parse pure float');
  is($qc->_enforce_number(q[7Kb]), 7000, 'parse pure int + Kb');
  is($qc->_enforce_number(q[ 7.5 kb]), 7500, 'parse pure float + kb and space in front');
  is($qc->_enforce_number(q[0.5 kb]), 500, 'parse pure less than 1 float + kb');
  is($qc->_enforce_number(q[.5 kb]), 500, 'parse pure less than 1 float without the int part + kb');
  is($qc->_enforce_number(q[1.57777777 kb]), 1577, 'parse pure float with many decimal numbers + kb');
  is($qc->_enforce_number(q[ 7.0kb]), 7000, 'parse pure float with zero for the decimal part + kb');
  is($qc->_enforce_number(q[7.5k]), 7500, 'parse float + k');
  is($qc->_enforce_number(q[7.5K]), 7500, 'parse float + K');
  
  is($qc->_enforce_number(q[sfsdfsdf]), 0, 'return zero when the string is purely alphanumerical');
  is($qc->_enforce_number(q[K7.5]), 0, 'zero returned when parsing float + K in front');
}

{
  my $qc = npg_qc::autoqc::checks::insert_size->new(
                                              position  => 1, 
                                              path      => 't/data/autoqc', 
                                              id_run    => 3938,
                                              expected_size => [2 , 3],
                                              repository => $repos,
                                                   );
  is(join(q[ ], @{$qc->expected_size}), q[2 3], 'expected size set in the constructor is returned');
}

{
  my $qc = npg_qc::autoqc::checks::insert_size->new(
                                              position  => 1, 
                                              path      => 't/data/autoqc', 
                                              id_run    => 1937,
                                              repository => $repos,
                                                   );
  is(join(q[ ], @{$qc->expected_size}), q[400 500], 'expected size the old way');
}

{
  my $qc = npg_qc::autoqc::checks::insert_size->new(
                                              position  => 1, 
                                              path      => 't/data/autoqc', 
                                              id_run    => 3938,
                                              repository => $repos,
                                                   );
  is(join(q[ ], @{$qc->expected_size}), q[3000 4000], 'expected size range when the values are given in kb');
}

{
  my $qc = npg_qc::autoqc::checks::insert_size->new(
                                              position  => 1, 
                                              path      => 't/data/autoqc', 
                                              id_run    => 4748,
                                              tag_index => 1,
                                              repository => $repos,
                                                   );
  is($qc->expected_size, undef, 'expected size range for a plex when the size is not defined');
}

{
  my $qc = npg_qc::autoqc::checks::insert_size->new(
                                              position  => 1, 
                                              path      => 't/data/autoqc', 
                                              id_run    => 4748,
                                              repository => $repos,
                                                   );
  is($qc->expected_size, undef, 'expected size range for lane with one plex when the size is not defined in the plex');
}

{
  my $qc = npg_qc::autoqc::checks::insert_size->new(
                                              position  => 1, 
                                              path      => 't/data/autoqc', 
                                              id_run    => 4748,
                                              tag_index => 900,
                                              repository => $repos,
                                                   );
  $qc->expected_size;
  like ($qc->result->comments, qr/No tag with index 900 in lane 1 batch 6637/, 
              'comment for an error when tag index does not exist');  
}

{
  my $qc = npg_qc::autoqc::checks::insert_size->new(
                                              position  => 3, 
                                              path      => 't/data/autoqc', 
                                              id_run    => 4799,
                                              repository => $repos,
                                                   );
  is (join(q[ ], @{$qc->expected_size}), q[300 390], 'expected size for a pool lane');
}

{
  my $qc = npg_qc::autoqc::checks::insert_size->new(
                                              position  => 3, 
                                              path      => 't/data/autoqc', 
                                              id_run    => 4799,
                                              tag_index => 0,
                                              repository => $repos,
                                                   );
  is(join(q[ ], @{$qc->expected_size}), q[300 390], 'expected size for a pool lane, tag index 0');
}

{
  my $qc = npg_qc::autoqc::checks::insert_size->new(
                                              position  => 3, 
                                              path      => 't/data/autoqc', 
                                              id_run    => 4799,
                                              tag_index => 2,
                                              repository => $repos,
                                                   );
  is(join(q[ ], @{$qc->expected_size}), q[225 375], 'expected size for a pool lane, tag index 2');
}

{
  my $qc = npg_qc::autoqc::checks::insert_size->new(
                                              position  => 3, 
                                              path      => 't/data/autoqc', 
                                              id_run    => 4799,
                                              tag_index => 3,
                                              repository => $repos,
                                                   );
  is($qc->expected_size, undef, 'expected size for a pool lane, tag index 3');
}

{
  my $qc = npg_qc::autoqc::checks::insert_size->new(
                                              position  => 3, 
                                              path      => 't/data/autoqc', 
                                              id_run    => 4799,
                                              tag_index => 1,
                                              repository => $repos,
                                                   );
  is(join(q[ ], @{$qc->expected_size}), q[300 390], 'expected size for a pool lane, tag index 1');
}

{
  my $dir = tempdir( CLEANUP => 1 );
  my $s1 = catfile($current_dir, q[t/data/autoqc/alignment.sam]);
  t::autoqc_util::write_bwa_script(catfile($dir, 'bwa'), $s1);
  if ($test_bam) {
    my $b1 = catfile($current_dir, q[t/data/autoqc/alignment.bam]);
    t::autoqc_util::write_samtools_script(catfile($dir, 'samtools'), $b1);
  }
  local $ENV{PATH} = join ':', $dir,  $ENV{PATH};

  my $qc = npg_qc::autoqc::checks::insert_size->new(
                                              position  => 1, 
                                              path      => 't/data/autoqc', 
                                              id_run    => 1937,
                                              repository => $repos,
                                              reference => $ref,
                                              use_reverse_complemented => 0,
                                              format => $format,
                                                   );

  ok($qc->execute(), 'execute returns true');

  ##### Construct expected  object: START ####
  my $eqc = npg_qc::autoqc::checks::insert_size->new(
                                              position  => 1, 
                                              path      => 't/data/autoqc', 
                                              id_run    => 1937,
                                              repository => $repos,
                                              reference => $ref,
                                              input_files   => ['t/data/autoqc/1937_1_1.fastq', 't/data/autoqc/1937_1_2.fastq'],
                                                    );

  $eqc->result->pass(0);
  $eqc->result->bin_width(1);
  $eqc->result->min_isize(110);
  $eqc->result->filenames(['1937_1_1.fastq', '1937_1_2.fastq']);
  $eqc->result->expected_size([400,500]);
  $eqc->result->mean(148);
  $eqc->result->std(16);
  $eqc->result->sample_size(12500);
  $eqc->result->quartile1(135);
  $eqc->result->median(151);
  $eqc->result->quartile3(154);
  $eqc->result->bins([ 1,0,1,0,0,2,0,0,0,0,1,0,0,0,0,1,1,0,0,0,0,1,0,0,0,1,0,0,0,0,2,0,1,1,0,0,0,1,0,0,2,1,1,5,2,0,0,1,2,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,2 ]);
  $eqc->result->num_well_aligned_reads(33);
  $eqc->result->reference($ref);
  $eqc->result->num_well_aligned_reads_opp_dir(undef);
  $eqc->result->set_info('Aligner', catfile ($dir, 'bwa'));
  $eqc->result->set_info('Aligner_version', '0.5.5 (r1273)');
  $eqc->result->set_info('Additional_Modules', join(q[;], _additional_modules));
  $eqc->result->add_comment('Not enough properly paired reads for normal fitting');
  #### Construct expected  object: END ####

  cmp_deeply ($qc->result, $eqc->result, 'result object after the execution');

  $qc = npg_qc::autoqc::checks::insert_size->new(
                                              path      => 't/data/autoqc', 
                                              rpt_list   => '1937:1',
                                              repository => $repos,
                                              reference => $ref,
                                              use_reverse_complemented => 0,
                                              format => $format,
                                                   );

   ok($qc->execute(), 'execute returns true');
   cmp_deeply ($qc->result, $eqc->result, 'result object after the execution');
}

{
  my $qc = npg_qc::autoqc::checks::insert_size->new(
                                              path      => 't/data/autoqc', 
                                              rpt_list   => '1937:1;1938:2',
                                              repository => $repos,
                                              reference => $ref,
                                              use_reverse_complemented => 0,
                                              format => $format,
                                                   );
  throws_ok { $qc->is_paired_read() } qr/Data from multiple runs/,
    'error inferring whether reads are paired';
  throws_ok { $qc->can_run() } qr/Data from multiple runs/,
    'error inferring whether can run';

  $qc = npg_qc::autoqc::checks::insert_size->new(
                                              path      => 't/data/autoqc', 
                                              rpt_list   => '1937:1;1938:2',
                                              repository => $repos,
                                              reference => $ref,
                                              use_reverse_complemented => 0,
                                              format => $format,
                                              is_paired_read => 0,
                                                 );
  is($qc->can_run(), 0, 'cannot run');

  $qc = npg_qc::autoqc::checks::insert_size->new(
                                              path      => 't/data/autoqc', 
                                              rpt_list   => '1937:1;1938:2',
                                              repository => $repos,
                                              reference => $ref,
                                              use_reverse_complemented => 0,
                                              format => $format,
                                              is_paired_read => 1,
                                                );
  is($qc->can_run(), 1, 'can run');
}

{
  my $dir = tempdir( CLEANUP => 1 );
  my $s1 = catfile($current_dir, q[t/data/autoqc/insert_size/alignment_isize_normfit.sam]);
  t::autoqc_util::write_bwa_script(catfile($dir, 'bwa'), $s1);
  local $ENV{PATH} = join ':', $dir,  $ENV{PATH};

  my $check = npg_qc::autoqc::checks::insert_size->new(
                                              position  => 1,
                                              path      => 't/data/autoqc',
                                              id_run    => 1937,
                                              repository => $repos,
                                              reference => $ref,
                                              expected_size => [350,350],
                                              use_reverse_complemented => 0,
                                              format => $format,
                                                   );

  ok($check->execute(), 'execute returns true');
  my $result = decode_json(slurp 't/data/autoqc/insert_size/15155_8.insert_size.json');
  is ($check->result->num_well_aligned_reads, 8417, 'num_well_aligned_reads correct');
  is_deeply ($check->result->bins, $result->{'bins'}, 'bins array correct');
  is_deeply ($check->result->norm_fit_modes, $result->{'norm_fit_modes'}, 'norm_fit_modes correct');
  is ($check->result->norm_fit_confidence, 0.76, 'norm_fit_confidence correct');
  is ($check->result->norm_fit_nmode, 2, 'norm_fit_nmode correct');
  is ($check->result->norm_fit_pass, 0, 'norm_fit_pass correct');
}

{
  my $dir = tempdir( CLEANUP => 1 );
  my $s1 = catfile($current_dir, q[t/data/autoqc/alignment.sam]);
  t::autoqc_util::write_bwa_script(catfile($dir, 'bwa'), $s1);
  if ($test_bam) {
    $s1 =~ s/sam/bam/smx;
    t::autoqc_util::write_samtools_script(catfile($dir, 'samtools'), $s1);
  }
  local $ENV{PATH} = join ':', $dir,  $ENV{PATH};

  my $qc = npg_qc::autoqc::checks::insert_size->new(
                                              position  => 4, 
                                              path      => $dir, 
                                              id_run    => 4174,
                                              repository => $repos,
                                              reference => $ref,
                                              use_reverse_complemented => 0,
                                              format => $format,
                                                    );
  
  $s1 = q[t/data/autoqc/1937_1_1.fastq];
  my $s2 = q[t/data/autoqc/1937_1_2.fastq];
  my $f1 = $dir . q[/4174_4_1.fastq];
  my $f2 = $dir . q[/4174_4_2.fastq];                                               
  `cp  $s1 $f1`;
  `cp  $s2 $f2`;
  $qc->execute();

  is($qc->result->expected_size, undef, 
    'expected size result array undefined for a sample where no expected size is specified');
  like($qc->result->comments, qr/Not enough properly paired reads for normal fitting/, 'comment for a sample with not enough paired reads');
  is($qc->result->pass, undef, 'pass value undefined for a sample where no expected size is specified');
}

{
  my $dir = tempdir( CLEANUP => 1 );
  my $s1 = catfile($current_dir, q[t/data/autoqc/alignment_small.sam]);
  t::autoqc_util::write_bwa_script(catfile($dir, 'bwa'), $s1);
  if ($test_bam) {
    $s1 =~ s/sam/bam/smx;
    t::autoqc_util::write_samtools_script(catfile($dir, 'samtools'), $s1);
  }
  local $ENV{PATH} = join ':', $dir,  $ENV{PATH};

  my $qc = npg_qc::autoqc::checks::insert_size->new(
                                              position  => 1, 
                                              path      => 't/data/autoqc', 
                                              id_run    => 1937,
                                              repository => $repos,
                                              reference => $ref,
                                              expected_size => [350, 350],
                                              use_reverse_complemented => 0,
                                              format => $format,
                                                   );
  lives_ok {$qc->execute()} 'execution for a small result set lives';
}

{
  my $dir = tempdir( CLEANUP => 0 );
  my $s1 = catfile($current_dir, q[t/data/autoqc/alignment_empty.sam]);
  t::autoqc_util::write_bwa_script(catfile($dir, 'bwa'), $s1);
  if ($test_bam) {
    $s1 =~ s/sam/bam/smx;
    t::autoqc_util::write_samtools_script(catfile($dir, 'samtools'), $s1);
  }

  local $ENV{PATH} = join ':', $dir,  $ENV{PATH};

  my $qc = npg_qc::autoqc::checks::insert_size->new(
                                              position  => 1, 
                                              path      => 't/data/autoqc', 
                                              id_run    => 1937,
                                              repository => $repos,
                                              reference => $ref,
                                              expected_size => [350,350],
                                              use_reverse_complemented => 0,
                                              format => $format,
                                                   );
  $qc->execute();

  ##### Construct expected  object: START ####
  my $eqc = npg_qc::autoqc::checks::insert_size->new(
                                              position  => 1, 
                                              path      => 't/data/autoqc', 
                                              id_run    => 1937,
                                              repository => $repos,
                                              reference => $ref,
                                              expected_size => [350,350],
                                              use_reverse_complemented => 0,
                                              input_files   => ['t/data/autoqc/1937_1_1.fastq', 't/data/autoqc/1937_1_2.fastq'],
                                                    );
  $eqc->result->pass(0);
  $eqc->result->filenames(['1937_1_1.fastq', '1937_1_2.fastq']);
  $eqc->result->comments(q[No results returned from aligning]);
  $eqc->result->reference($ref);
  $eqc->result->sample_size(12500);
  $eqc->result->num_well_aligned_reads(0);
  $eqc->result->num_well_aligned_reads_opp_dir(undef);
  $eqc->result->set_info('Aligner', catfile ($dir, 'bwa'));
  $eqc->result->set_info('Aligner_version', '0.5.5 (r1273)');
  $eqc->result->set_info('Additional_Modules', join(q[;], _additional_modules));
  #### Construct expected  object: END ####

  cmp_deeply ($qc->result, $eqc->result, 'result object after the execution for an empty result set');
}

{
  my $dir = tempdir( CLEANUP => 1 );
  my $s1 = catfile($current_dir, q[t/data/autoqc/alignment_one.sam]);
  t::autoqc_util::write_bwa_script(catfile($dir, 'bwa'), $s1);
  if ($test_bam) {
    $s1 =~ s/sam/bam/smx;
    t::autoqc_util::write_samtools_script(catfile($dir, 'samtools'), $s1);
  }
  local $ENV{PATH} = join ':', $dir,  $ENV{PATH};

  my $qc = npg_qc::autoqc::checks::insert_size->new(
                                              position  => 1, 
                                              path      => 't/data/autoqc', 
                                              id_run    => 1937,
                                              repository => $repos,
                                              reference => $ref,
                                              expected_size => [350,350],
                                              use_reverse_complemented => 0,
                                              format => $format,
                                                   );
  $qc->execute();

  ##### Construct expected  object: START ####
  my $eqc = npg_qc::autoqc::checks::insert_size->new(
                                              position  => 1, 
                                              path      => 't/data/autoqc', 
                                              id_run    => 1937,
                                              repository => $repos,
                                              reference => $ref,
                                              expected_size => [350,350],
                                              use_reverse_complemented => 0,
                                              input_files   => ['t/data/autoqc/1937_1_1.fastq', 't/data/autoqc/1937_1_2.fastq'],
                                                    );
  $eqc->result->pass(0);
  $eqc->result->filenames(['1937_1_1.fastq', '1937_1_2.fastq']);
  $eqc->result->expected_size([350,350]);
  $eqc->result->mean(96);
  $eqc->result->std(0);
  $eqc->result->sample_size(12500);
  $eqc->result->quartile1(96);
  $eqc->result->median(96);
  $eqc->result->quartile3(96);
  $eqc->result->min_isize(96);
  $eqc->result->bin_width(1);
  $eqc->result->bins([1]);
  $eqc->result->num_well_aligned_reads_opp_dir(undef);
  $eqc->result->num_well_aligned_reads(1);
  $eqc->result->reference($ref);
  $eqc->result->set_info('Aligner', catfile ($dir, 'bwa'));
  $eqc->result->set_info('Aligner_version', '0.5.5 (r1273)');
  $eqc->result->set_info('Additional_Modules', join(q[;], _additional_modules));
  $eqc->result->add_comment('Not enough properly paired reads for normal fitting');
  #### Construct expected  object: END ####
  cmp_deeply ($qc->result, $eqc->result, 'result object after the execution for one result');
}

{
  my $dir = tempdir( CLEANUP => 1 );
  my $s1 = catfile($current_dir, q[t/data/autoqc/alignment_one.sam]);
  t::autoqc_util::write_bwa_script(catfile($dir, 'bwa'), $s1);
  if ($test_bam) {
    $s1 =~ s/sam/bam/smx;
    t::autoqc_util::write_samtools_script(catfile($dir, 'samtools'), $s1);
  }
  local $ENV{PATH} = join ':', $dir,  $ENV{PATH};

  my $qc = npg_qc::autoqc::checks::insert_size->new(
                                              position  => 1, 
                                              path      => 't/data/autoqc', 
                                              id_run    => 1937,
                                              repository => $repos,
                                              reference => $ref,
                                              expected_size => [340,350],
                                              use_reverse_complemented => 0,
                                              format   => $format,
                                                   );
  lives_ok {$qc->execute()} 'execution for one result lives';
}

{
  my $qc = npg_qc::autoqc::checks::insert_size->new(
                                              position  => 5, 
                                              path      => 't/data/autoqc', 
                                              id_run    => 4261,
                                              repository => $repos,
                                              reference => $ref,
                                                   );
  is(join( q[ ], @{$qc->expected_size()}), '300 500', 'expected insert size range expanded');
}

{
  my $dir = tempdir( CLEANUP => 1 );
  my $f = $dir . q[/2549_8_1.fastq];
  `touch $f`;
  $f = $dir . q[/2549_8_2.fastq];
  `touch $f`;

  my $check = npg_qc::autoqc::checks::insert_size->new(position => 8,
                                                       path => $dir,
                                                       id_run => 2549,
                                                       use_reverse_complemented => 0,
                                                       repository => $repos, );
  lives_ok { $check->execute } 'does not fail with empty files';
  is( $check->result->sample_size, undef, 'result sample size undefined');
  is( $check->result->reference, undef, 'result reference undefined');
}

{
  my $dir = tempdir( CLEANUP => 1 );
  t::autoqc_util::write_fastx_script(catfile($dir, 'fastx_reverse_complement'));
  local $ENV{PATH} = join ':', $dir,  $ENV{PATH};

  my $qc = npg_qc::autoqc::checks::insert_size->new(
                                              position  => 1, 
                                              path      => 't/data/autoqc', 
                                              id_run    => 1937,
                                              repository => $repos,
                                              reference => $ref,
                                              expected_size => [340,350],
                                              format   => $format,
                                                   );
  is ($qc->_fastx_version, '0.0.12', 'fastx version');
  $qc->_set_additional_modules_info;
  is ( $qc->result->get_info('Additional_Modules'),
    join(q[;], _additional_modules(1)), 'additional info with fastx');
}

{
  my $dir = tempdir( CLEANUP => 1 );
  t::autoqc_util::write_fastx_script(catfile($dir, 'fastx_reverse_complement'), 1);
  my $s1 = catfile($current_dir, q[t/data/autoqc/alignment_few.sam]);
  t::autoqc_util::write_bwa_script(catfile($dir, 'bwa'), $s1);
  local $ENV{PATH} = join ':', $dir,  $ENV{PATH};

  my $qc = npg_qc::autoqc::checks::insert_size->new(
                                              position  => 1, 
                                              path      => 't/data/autoqc', 
                                              id_run    => 1937,
                                              repository => $repos,
                                              reference => $ref,
                                              expected_size => [340,350],
                                              format   => $format,
                                                   );
  lives_ok {$qc->execute} 'check execute method lives, reverse comp flag set';
}

{
  local $ENV{'NPG_CACHED_SAMPLESHEET_FILE'} = q[t/data/autoqc/genotype_call/samplesheet_24135.csv];
  my $qc = npg_qc::autoqc::checks::insert_size->new(
                                              position  => 1, 
                                              tag_index => 1, 
                                              path      => 't/data/autoqc', 
                                              id_run    => 24135,
                                              repository => $repos, 
                                                   );

  is($qc->can_run, 0, 'check can_run is false for a GbS run');
}

1;



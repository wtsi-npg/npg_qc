#########
# Author:        gq1
# Created:       10 November 2009
#

use strict;
use warnings;
use File::Copy;
use Test::More tests => 63;
use Test::Exception;
use Test::Deep;
use File::Temp qw/ tempdir /;

my $repos = q[t/data/autoqc];
my $test_reference = q[t/data/autoqc/references/Homo_sapiens/default/all/bwa/someref.fa];

use_ok('npg_qc::autoqc::checks::sequence_error');

{
  my @sequences;
  my @qualities;
  open ( my $fh, q{<}, q{t/data/autoqc/sequence_error/6376_1_1.fastq.10000} ) || die q{unable to open t/data/autoqc/1937_1_1.fastq};
  my $count = 0;
  while ( <$fh> ) {
    chomp;
    if ( $count == 1 ) {
      push @sequences, $_;
    }
    if ( $count == 3 ) {
      push @qualities, $_;
      $count = 0;
    } else {
      $count++;
    }
  }
  close $fh;
  my $quality_structure = {
    15 => [],
    30 => [],
    31 => [],
  };
  my $match_array = [qw{1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 0 0 0 0 0 0 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 1 0 0 0 1 1 1 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 0 1 0 0 1 0 1 1 0 1 1 1 1 1 1 1 0 1 1 0 0 0 0 0 1 1 0 1 1 1 1 1 1 } ];
  my $index = 0;
  foreach my $q_string ( @qualities ) {
    npg_qc::autoqc::checks::sequence_error->_collate_qualities({
      match_array => $match_array,
      quality_struct => $quality_structure,
      quality_string => $q_string,
      sequence => $sequences[$index],
      flag => 0,
    });
    $index++;
  }

  my $expected_qual_struct = {
   '15' => [ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 24, 0, 0, 0, 0, 0, 0, 32, 35, 39, 40, 46, 38, 0, 0, 0, 0, 0, 0, 0, 0, 0, 71, 0, 0, 0, 249, 0, 105, 181, 176, 288, 301, 277, 328, 345, 156, 145, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 204, 0, 0, 282, 0, 246, 243, 0, 198, 226, 233, 260, 269, 231, 266, 0, 274, 342, 0, 0, 0, 0, 0, 376, 407, 0, 439, 518, 511, 507, 476, 507 ],
   '30' => [ 116, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 164, 0, 0, 0, 0, 0, 0, 243, 233, 240, 244, 240, 243, 0, 0, 0, 0, 0, 0, 0, 0, 0, 338, 0, 0, 0, 4491, 0, 1259, 4780, 4926, 4917, 5088, 5123, 5100, 5122, 447, 473, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 590, 0, 0, 699, 0, 720, 774, 0, 716, 761, 774, 791, 730, 779, 821, 0, 880, 866, 0, 0, 0, 0, 0, 1056, 1093, 0, 1100, 1174, 1291, 1324, 1294, 1701],
   '31' => [ 6943, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6698, 0, 0, 0, 0, 0, 0, 6582, 6716, 6592, 6606, 6621, 6664, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6508, 0, 0, 0, 2212, 0, 2036, 2013, 1869, 1720, 1590, 1570, 1497, 1422, 6340, 6417, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6200, 0, 0, 5901, 0, 5900, 5889, 0, 5974, 5953, 5968, 5943, 6031, 5891, 5865, 0, 5785, 5709, 0, 0, 0, 0, 0, 5554, 5420, 0, 5440, 5275, 5131, 5092, 5159, 4760],
  };
  is_deeply( $quality_structure, $expected_qual_struct, q{quality structure obtained ok} );

  foreach my $q_val ( sort { $a <=> $b } keys %{$quality_structure} ) {
    is( $quality_structure->{$q_val}[46], 0, qq{No N's give quality value at cycle 47 for qval $q_val} );
  }

  my $n_count_array = [];
  foreach my $seq ( @sequences ) {
    npg_qc::autoqc::checks::sequence_error->_collate_uncalled( {
      match_array => $match_array,
      sequence => $seq,
      count_array => $n_count_array,
      flag => 0,
    } );
  }
  my $expected = [
  2940, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, 3114, undef, undef, undef, undef, undef, undef, 3143, 3016, 3129, 3110, 3093, 3055, undef, undef, undef, undef, undef, undef, undef, undef, undef, 3083, undef, undef, undef, 3048, 10000, 6600, 3026, 3029, 3075, 3021, 3030, 3075, 3111, 3057, 2965, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, 3006, undef, undef, 3118, undef, 3134, 3094, undef, 3112, 3060, 3025, 3006, 2970, 3099, 3048, undef, 3061, 3083, undef, undef, undef, undef, undef, 3014, 3080, undef, 3021, 3033, 3067, 3077, 3071, 3032
  ];
#diag explain $n_count_array;

  is_deeply( $n_count_array, $expected, q{n_count array generated correctly} );
  is( $n_count_array->[46], 10_000, q{cycle 47 is all N's} );

}

{
  my $match_array = npg_qc::autoqc::checks::sequence_error->parsing_md_string('12A0^AA24');

  is(scalar @{$match_array}, 37, 'correct length of read');
  ok($match_array->[12], 'mismatch on position 13');
  ok(!$match_array->[36], 'match on last position');
}

{
  my $match_array = npg_qc::autoqc::checks::sequence_error->parsing_md_string('36');
  is(scalar @{$match_array}, 36, 'correct length of read');
  ok(!$match_array->[12], 'match on position 13');
  ok(!$match_array->[35], 'match on last position');
}

{
  my $match_array = npg_qc::autoqc::checks::sequence_error->parsing_md_string('0A36');
  is(scalar @{$match_array}, 37, 'correct length of read');
  ok($match_array->[0], 'mismatch on position 1');
  ok(!$match_array->[36], 'match on last position');
}

{
  my $match_array1 = npg_qc::autoqc::checks::sequence_error->parsing_md_string('35^AA1');
  my $match_array2 = npg_qc::autoqc::checks::sequence_error->modify_match_by_cigar('28M1I7M2D1M', $match_array1 );
  is (scalar @{$match_array1}, 36, 'correct array length before modifying');
  is(scalar @{$match_array2}, 37, 'correct array length after modifying');
}

{
  my $match_array1 = npg_qc::autoqc::checks::sequence_error->parsing_md_string('32A2');
  print "@{$match_array1}\n";
  my ($match_array2, $count) = npg_qc::autoqc::checks::sequence_error->modify_match_by_cigar('20M2I15M', $match_array1 );
  print "@{$match_array2}\n";
  is (scalar @{$match_array1}, 35, 'correct array length before modifying');
  is(scalar @{$match_array2}, 37, 'correct array length after modifying');
  ok($match_array1->[32], 'position 33 mismatch before modifying');
  ok(!$match_array2->[32], 'position 33 match after modifying');
}
{
  my $reverse = npg_qc::autoqc::checks::sequence_error->check_read_orientation(16);
  ok($reverse, 'reverse for 16');
}

{
  my $reverse = npg_qc::autoqc::checks::sequence_error->check_read_orientation(8);
  ok(!$reverse, 'forward for 8');
}

{
  my $reverse = npg_qc::autoqc::checks::sequence_error->check_read_orientation(128);
  ok (!$reverse, 'forward for 128');;
}

{
  my $reverse = npg_qc::autoqc::checks::sequence_error->check_read_orientation(24);
  ok ($reverse, 'reverse for 24');
}

{
  my ($match_array, $count) = npg_qc::autoqc::checks::sequence_error->matches_per_base('32A3', '2M1I34M', 0);

  is (scalar @{$match_array}, 37, 'correct array length');
  ok($match_array->[33], 'position 34 mismatch');
  ok(!$match_array->[34], 'position 35 match');
}

{
  my ($match_array, $count) = npg_qc::autoqc::checks::sequence_error->matches_per_base('34^AG2 ', '34M2D2M1S', 1);
  is (scalar @{$match_array}, 37, 'correct array length');
  ok(!$match_array->[1], 'last position 37 not mismatch, after reversing position 2');
}

{
  my $results_hash = npg_qc::autoqc::checks::sequence_error->parsing_sam('t/data/autoqc/alignment.sam');
  is( $results_hash->{error_by_base}->[0], 11, 'first base error rate correct' );
  is( $results_hash->{error_by_base}->[36], 5, 'last base error rate correct' );
  is( $results_hash->{num_reads_aligned}, 41, 'correct number aligned reads' );
  is( $results_hash->{num_reads_not_aligned}, 0, 'correct number not aligned reads');
  cmp_ok( $results_hash->{common_cigars}->[0]->[0], 'eq', '100M', 'most common cigar');
  is( $results_hash->{common_cigars}->[0]->[1], 29, 'most common cigar count');
  isnt( $results_hash->{common_cigars}->[4], undef, 'only 3 cigars found to fifth string-count pair is not undef');
  is( $results_hash->{cigar_char_count_by_cycle}->{S}->[0], 11, 'substitution count for particular (1) cycle');
  is( $results_hash->{cigar_char_count_by_cycle}->{M}->[0], 30, 'match count for particular (1) cycle');
}

{
  my $error_check = npg_qc::autoqc::checks::sequence_error->new(position => 2, path => 't/data/autoqc/090721_IL29_2549/data', id_run => 2549, aligner_cmd => 'bwa', aligner_options => '-l 32 -k 2', repository => $repos, );
  is( $error_check->sample_size, 10000, 'default required sample size');
  my @fastq_files = $error_check->get_input_files ();
  is( $fastq_files[0], 't/data/autoqc/090721_IL29_2549/data/2549_2_1.fastq', 'correct first fastq full name');
}

{
  my $dir = tempdir( CLEANUP => 1 );
  my $bwa = join q[/], $dir, q[bwa];
  `touch $bwa`;
  `chmod +x $bwa`;
  my $f = $dir . q[/2549_8_1.fastq];
  `touch $f`;
  $f = $dir . q[/2549_8_2.fastq];
  `touch $f`;

  my $error_check = npg_qc::autoqc::checks::sequence_error->new(position => 8, path => $dir, id_run => 2549, bwa_cmd => $bwa, aligner_options => '-l 32 -k 2', reference=>$test_reference, repository => $repos,);
  is( $error_check->_actual_sample_size, undef, 'actual sample size undefined');
  lives_ok { $error_check->execute } 'does not fail with empty files';
  is( $error_check->_actual_sample_size, undef, 'actual sample size undefined');
  is( $error_check->result->sample_size, undef, 'result sample size undefined');
  is( $error_check->result->reference, undef, 'result reference undefined');
  is( $error_check->result->pass, undef, 'result pass undefined');

  `cp t/data/autoqc/090721_IL29_2549/data/2549_7_1.fastqcheck $dir`;
  $f = $dir . q[/2549_7_1.fastq];
  `touch $f`;
  $error_check = npg_qc::autoqc::checks::sequence_error->new(position => 7, path => $dir, id_run => 2549, bwa_cmd => $bwa, aligner_options => '-l 32 -k 2', reference=>$test_reference, repository => $repos,);
  is( $error_check->_actual_sample_size, undef, 'actual sample size undefined');
  lives_ok { $error_check->execute } 'does not fail with empty files';
  is( $error_check->_actual_sample_size, undef, 'actual sample size undefined');
  is( $error_check->result->sample_size, undef, 'result sample size undefined');
  is( $error_check->result->reference, undef, 'result reference undefined');
}

{
  is( npg_qc::autoqc::checks::sequence_error::_reverse_cigar(q(10M1D20M2I30M)),q(30M2I20M1D10M), 'cigar reversed');
}

{
  my $error_check = npg_qc::autoqc::checks::sequence_error->new(position => 7, id_run => 2549, path => q(/dev/null), repository => q(t/data));
  lives_ok { $error_check->_calc_and_set_pass(); } 'calc pass on no data lives';
  is($error_check->result->pass, undef, 'no data then pass is undefined');
  $error_check->result->forward_common_cigars([[q(30M1D45M),10000]]);
  lives_ok { $error_check->_calc_and_set_pass(); } 'calc pass on forward_common_cigar data lives';
  is($error_check->result->pass, 0, 'fail when most common forward cigar has deletion');
  $error_check->result->forward_common_cigars([[q(75M),10000]]);
  lives_ok { $error_check->_calc_and_set_pass(); } 'calc pass on forward_common_cigar data lives';
  is($error_check->result->pass, 1, 'pass when most common forward cigar has deletion');
  $error_check->result->reverse_common_cigars([[q(30M1D45M),10000]]);
  lives_ok { $error_check->_calc_and_set_pass(); } 'calc pass with reverse_common_cigar data lives';
  is($error_check->result->pass, 0, 'pass when most common reverse cigar has deletion');
}

{
  local $ENV{PATH} = q[/usr/bin];

  my $error_check = npg_qc::autoqc::checks::sequence_error->new(
                     position => 2,
                     path => 't/data/autoqc/090721_IL29_2549/data',
                     id_run => 2549,
                     repository => $repos,
                     reference => $test_reference);
   throws_ok {$error_check->execute() } 
              qr[no 'bwa' executable is on the path],
              'error since bwa executable is not on the path';
}

1;

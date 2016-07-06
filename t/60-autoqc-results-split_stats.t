use strict;
use warnings;
use Test::More tests => 5;
use Test::Exception;

use_ok ('npg_qc::autoqc::results::split_stats');

{
  my $r = npg_qc::autoqc::results::split_stats->new(
    id_run              => 4,
    position            => 3,
    filename1           => '1.fastq',
    filename2           => '2.fastq',
    ref_name            => 'human',
    reference           => '/references/Homo_sapiens/NCBI36/all/bwa/ Homo_sapiens.NCBI36.48.dna.all.fa',
    num_aligned1        => 1223,
    num_not_aligned1    => 222,
    alignment_coverage1 => {'y' => 0.34, 'x' => 0.89,},
    alignment_depth1    => {'y'=>{4=>1234, 5=>3212},'x'=>{3=>1234, 6=>3212},},
    num_aligned2        => 1243,
    num_not_aligned2    => 202,
    alignment_coverage2 => {'y' => 0.34, 'x' => 0.89,},
    calignment_depth2    => {'y'=>{4=>1234, 5=>3212}, 'x'=>{3=>1234, 6=>3212},},
    num_aligned_merge     => 1345,
    num_not_aligned_merge => 100,
  );
  isa_ok ($r, 'npg_qc::autoqc::results::split_stats');
    
  lives_ok{ $r->freeze() } 'no error when save data into json';
  is($r->subset, 'human', 'human subset');
  is($r->check_name, q[split stats human], 'check name');
}

1;

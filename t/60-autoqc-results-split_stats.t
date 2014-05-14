#########
# Author:        gq1
# Maintainer:    $Author$
# Created:       2009-09-21
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

use strict;
use warnings;
use Test::More tests => 8;
use English qw(-no_match_vars);
use Carp;
use File::Temp qw/ tempdir /;

our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/mx; $r; };

use_ok ('npg_qc::autoqc::results::split_stats');

{
    my $tempdir = tempdir( CLEANUP => 1);
    my $r = npg_qc::autoqc::results::split_stats->new(
                                                      filename1           => '1.fastq',
                                                      filename2           => '2.fastq',
                                                      ref_name            => 'human',
                                                      reference           => '/nfs/repository/d0031/references/Homo_sapiens/NCBI36/all/bwa/ Homo_sapiens.NCBI36.48.dna.all.fa',
                                                      num_aligned1        => 1223,
                                                      num_not_aligned1    => 222,
                                                      alignment_coverage1 => {'y' => 0.34, 'x' => 0.89,},
                                                      alignment_depth1    => {'y'=>{4=>1234, 5=>3212},
                                                                              'x'=>{3=>1234, 6=>3212},
                                                                             },
                                                      num_aligned2        => 1243,
                                                      num_not_aligned2    => 202,
                                                      alignment_coverage2 => {'y' => 0.34, 'x' => 0.89,},
                                                      alignment_depth2    => {'y'=>{4=>1234, 5=>3212},
                                                                               'x'=>{3=>1234, 6=>3212},
                                                                             },
                                                      num_aligned_merge     => 1345,
                                                      num_not_aligned_merge => 100,
    );
    isa_ok ($r, 'npg_qc::autoqc::results::split_stats');
    
    eval{
      $r->freeze();
      $r->store(qq{$tempdir/split_stats.json});
      1;
    };
    is($EVAL_ERROR, q{}, 'no croak when save data into json');
    
    eval{
      $r->stats_to_xml();
      $r->save_stats_xml(qq{$tempdir/split_stats.xml});
      1;
    };
    is($EVAL_ERROR, q{}, 'no croak when save data into xml');    
    cmp_ok(sprintf('%.2f',$r->percent_split), '==', 93.08, 'percent split');
}

{
  my $result = npg_qc::autoqc::results::split_stats->load(q[t/data/autoqc/5374_2_1-5374_2_2_human_split_stats.json]);
  is($result->image_url(1), q[http://chart.apis.google.com/chart?cht=bvs&chxt=x,y&chs=432x250&chd=t:6.40,5.71,4.92,4.56,4.28,3.97,3.65,3.36,3.09,2.95,2.68,2.58,1.84&chds=0,7&chxl=0:|1|2|4|8|16|32|64|128|256|512|1024|2048|4096|1:|0|10|100|1000|10000|100000|1000000|10000000&chxp=1,0,1,2,3,4,5,6,7|&chtt=Number+of+bases+at+and+above+depth|5374_2_1.fastq], 'forward image url');
  is($result->image_url(2), q[http://chart.apis.google.com/chart?cht=bvs&chxt=x,y&chs=403x250&chd=t:6.20,5.43,4.87,4.60,4.30,4.00,3.65,3.28,3.02,2.75,2.64,2.33&chds=0,7&chxl=0:|1|2|4|8|16|32|64|128|256|512|1024|2048|1:|0|10|100|1000|10000|100000|1000000|10000000&chxp=1,0,1,2,3,4,5,6,7|&chtt=Number+of+bases+at+and+above+depth|5374_2_2.fastq], 'reverse_image_url');

  is($result->check_name, q[split stats human], 'check name');
}

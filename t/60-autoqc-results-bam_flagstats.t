#########
# Author:        gq1
# Created:       2010-06-23
#

use strict;
use warnings;
use Test::More tests => 21;
use Test::Exception;
use Test::Deep;
use File::Temp qw/ tempdir /;
use Perl6::Slurp;
use JSON;

use_ok ('npg_qc::autoqc::results::bam_flagstats');
{
    my $tempdir = tempdir( CLEANUP => 1);
    my $r = npg_qc::autoqc::results::bam_flagstats->new(
                                       position => 5,
                                       id_run   => 4783,                                       
                                 );
    isa_ok ($r, 'npg_qc::autoqc::results::bam_flagstats');

    $r->parsing_metrics_file('t/data/autoqc/4783_5_metrics_optical.txt');

    open my $flagstats_fh, '<', 't/data/autoqc/4783_5_mk.flagstat';
    $r->parsing_flagstats($flagstats_fh);
    close $flagstats_fh;
  

    my $result_json;
    lives_ok {
      $result_json = $r->freeze();
      $r->store(qq{$tempdir/4783_5_bam_flagstats.json});
    } 'no error when save data into json';

 
     my $from_json_hash = from_json($result_json);
     delete $from_json_hash->{__CLASS__};
     is_deeply($from_json_hash, from_json(slurp q{t/data/autoqc/4783_5_bam_flagstats.json}, {chomp=>1}), 'correct json output');

    is($r->total_reads(), 32737230 , 'total reads');
    is($r->total_mapped_reads(), '30992462', 'total mapped reads');
    is($r->percent_mapped_reads, 94.6703859795102, 'percent mapped reads');
    is($r->percent_duplicate_reads, 15.6023713120952, 'percent duplicate reads');
    is($r->percent_properly_paired ,89.7229484595978, 'percent properly paired');
    is($r->percent_singletons, 2.92540938863795, 'percent singletons');
    is($r->check_name(), 'bam flagstats', 'correct check name');
    $r->human_split('human');
    is($r->check_name(), 'bam flagstats human', 'correct check name');
    is($r->read_pairs_examined(), 15017382, 'read_pairs_examined');
    
        
    open my $flagstats_fh2, '<', 't/data/autoqc/6440_1#0.bamflagstats';
    $r->parsing_flagstats($flagstats_fh2);
    close $flagstats_fh2; 
    is($r->total_reads(), 2978224 , 'total reads');
    is($r->proper_mapped_pair(),2765882, 'properly paired');
}

{
    my $r = npg_qc::autoqc::results::bam_flagstats->load('t/data/autoqc/4921_3_bam_flagstats.json');
    ok( !$r->total_reads(), 'total reads not available' ) ;
    
}

{
    my $r = npg_qc::autoqc::results::bam_flagstats->new(
                                       position => 5,
                                       id_run   => 4783,                                       
                                 );
    $r->parsing_metrics_file('t/data/autoqc/estimate_library_complexity_metrics.txt');
    is($r->read_pairs_examined(),2384324, 'read_pairs_examined');
    is($r->paired_mapped_reads(),  0, 'paired_mapped_reads');    
}

{
    my $r = npg_qc::autoqc::results::bam_flagstats->new(
                                       position => 5,
                                       id_run   => 4783,
                                       tag_index => 0); 
    lives_ok {$r->parsing_metrics_file('t/data/autoqc/12313_1#0_bam_flagstats.txt')}
      'file with library size -1 parsed';
    is($r->library_size, undef, 'library size is undefined');
    is($r->read_pairs_examined, 0, 'examined zero read pairs');
}

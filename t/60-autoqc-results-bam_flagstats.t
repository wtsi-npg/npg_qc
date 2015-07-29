use strict;
use warnings;
use Test::More tests => 49;
use Test::Exception;
use Test::Deep;
use File::Temp qw/ tempdir /;
use Perl6::Slurp;
use JSON;

use_ok ('npg_qc::autoqc::results::bam_flagstats');

{
    my $r = npg_qc::autoqc::results::bam_flagstats->new(
            position => 5,
            id_run   => 4783);
    isa_ok ($r, 'npg_qc::autoqc::results::bam_flagstats');
    is($r->check_name(), 'bam flagstats', 'correct check name');
    is($r->filename4serialization(), '4783_5.bam_flagstats.json',
      'default file name');
    is($r->human_split, undef, 'human_split field is not set');
    is($r->subset, undef, 'subset field is not set');
    $r->human_split('human');
    is($r->check_name(), 'bam flagstats', 'check name has not changed');
    $r->subset('human');
    is($r->check_name(), 'bam flagstats human', 'check name has changed');
    is($r->filename4serialization(), '4783_5_human.bam_flagstats.json',
      'file name contains "human" flag');

    $r = npg_qc::autoqc::results::bam_flagstats->new(
            position => 5,
            id_run   => 4783,
            human_split => 'phix');
    is ($r->subset, 'phix', 'subset attr is set correctly');
    my $json = $r->freeze();
    like ($json, qr/\"subset\":\"phix\"/, 'subset field is serialized');
    like ($json, qr/\"human_split\":\"phix\"/, 'human_split field is serialized');

    $r = npg_qc::autoqc::results::bam_flagstats->new(
            position => 5,
            id_run   => 4783,
            subset   => 'phix');
    is ($r->human_split, 'phix', 'human_split attr is set correctly');
    $json = $r->freeze();
    like ($json, qr/\"subset\":\"phix\"/, 'subset field is serialized');
    like ($json, qr/\"human_split\":\"phix\"/, 'human_split field is serialized');

    throws_ok { npg_qc::autoqc::results::bam_flagstats->new(
            position => 5,
            id_run   => 4783,
            subset   => 'phix',
            human_split => 'yhuman')
    } qr/human_split and subset attrs are different: yhuman and phix/,
    'error when human_split and subset attrs are different';

    lives_ok { npg_qc::autoqc::results::bam_flagstats->new(
            position => 5,
            id_run   => 4783,
            subset   => 'yhuman',
            human_split => 'yhuman')
    } 'no error when human_split and subset attrs are consistent';
}

{
    my $tempdir = tempdir( CLEANUP => 1);
    my $package = 'npg_qc::autoqc::results::bam_flagstats';
    my $dups  = 't/data/autoqc/4783_5_metrics_optical.txt';
    my $fstat = 't/data/autoqc/4783_5_mk.flagstat';
    my $dups_attr_name  = 'markdups_metrics_file';
    my $fstat_attr_name = 'flagstats_metrics_file';
    my $stats_attr_name = 'samtools_stats_file';
    my $h1 = {position => 5,id_run => 4783,};

    my $r1 = $package->new($h1);
    $r1->parsing_metrics_file($dups);

    open my $flagstats_fh, '<', $fstat;
    $r1->parsing_flagstats($flagstats_fh);
    close $flagstats_fh;

    $h1->{$dups_attr_name} = $dups;
    $h1->{$fstat_attr_name} = $fstat;
    my $r2 = $package->new($h1);
    my $expected = from_json(slurp q{t/data/autoqc/4783_5_bam_flagstats.json}, {chomp=>1});
    for my $r (($r1, $r2)) {

        # for $r1 the files to parse are not given
        # for $r2 the metrics files are given but the stats files are nor available
        lives_ok { $r->execute() } 'execute method does not error';
        is(scalar keys %{$r->$stats_attr_name}, 0, 'stats files hash empty');
        lives_and { is scalar @{$r->related_data}, 0} 'no related data';         

        my $result_json;
        lives_ok {
            $result_json = $r->freeze();
            $r->store(qq{$tempdir/4783_5_bam_flagstats.json});
        } 'no error when serializing to json string and file';

        my $from_json_hash = from_json($result_json);
        delete $from_json_hash->{__CLASS__}; 
        delete $from_json_hash->{$dups_attr_name};
        delete $from_json_hash->{$fstat_attr_name};
        delete $from_json_hash->{$stats_attr_name};

        is_deeply($from_json_hash, $expected, 'correct json output');
        is($r->total_reads(), 32737230 , 'total reads');
        is($r->total_mapped_reads(), '30992462', 'total mapped reads');
        is($r->percent_mapped_reads, 94.6703859795102, 'percent mapped reads');
        is($r->percent_duplicate_reads, 15.6023713120952, 'percent duplicate reads');
        is($r->percent_properly_paired ,89.7229484595978, 'percent properly paired');
        is($r->percent_singletons, 2.92540938863795, 'percent singletons');
        is($r->read_pairs_examined(), 15017382, 'read_pairs_examined');
    }

    open my $flagstats_fh2, '<', 't/data/autoqc/6440_1#0.bamflagstats';
    $r1->parsing_flagstats($flagstats_fh2);
    close $flagstats_fh2; 
    is($r1->total_reads(), 2978224 , 'total reads');
    is($r1->proper_mapped_pair(),2765882, 'properly paired');
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

1;

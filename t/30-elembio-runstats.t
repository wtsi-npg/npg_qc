use strict;
use warnings;
use List::Util qw/sum/;
use Test::More;
use Test::Exception;

use_ok('npg_qc::elembio::run_stats');
{
    my $manifest = 't/data/elembio/20240416_AV234003_16AprilSGEB2_2x300_NT1799722A/RunManifest.json';
    my $stats_file = 't/data/elembio/20240416_AV234003_16AprilSGEB2_2x300_NT1799722A/slim_20240416_AV234003_16AprilSGEB2_2x300_NT1799722A.json';
    my $lane_count = 1;

    my $stats = npg_qc::elembio::run_stats::run_stats_from_file($manifest, $stats_file, $lane_count);
    ok($stats);
    # Insert some useful tests with realistic data?
    is_deeply([keys %{$stats->lanes}], ['1']);
    cmp_ok($stats->r1_cycle_count, '==', 300);
    cmp_ok($stats->r2_cycle_count, '==', 300);

    my $lane_stats = $stats->lanes->{1};
    is($lane_stats->lane, 1, 'Lane 1 is indeed lane 1');
    cmp_ok($lane_stats->num_polonies, '==', 363641937);
    ok(exists $lane_stats->deplexed_samples->{Adept_CB1}, 'Controls are present as "samples"');
    cmp_ok ($lane_stats->unassigned_reads, '==', 2541588, 'Unassigned reads are calculated from percentage');
    my @sample_names = keys %{$lane_stats->deplexed_samples};
    cmp_ok(scalar @sample_names, '==', 6, 'Subset of samples extracted from truncated run stats, even though manifest has ~94 in it');
    foreach my $sample_name (@sample_names) {
        my $sample_stats = $lane_stats->get_sample($sample_name);
        is($sample_stats->lane, '1');
        cmp_ok(scalar keys %{$sample_stats->barcodes}, '==', 1, 'One barcode per lane/sample in this run');
        cmp_ok($sample_stats->index_lengths(), '==', 8);
    }
}

{
    my $manifest = 't/data/elembio/20250225_AV244103_NT1850075L_NT1850808B_repeat3/RunManifest.json';
    my $stats_file = 't/data/elembio/20250225_AV244103_NT1850075L_NT1850808B_repeat3/slim_20250225_AV244103_NT1850075L_NT1850808B_repeat3.json';
    my $lane_count = 2;

    my $stats = npg_qc::elembio::run_stats::run_stats_from_file($manifest, $stats_file, $lane_count);
    ok($stats);
    is_deeply([sort keys %{$stats->lanes}], ['1','2']);
    cmp_ok($stats->r1_cycle_count, '==', 100);
    cmp_ok($stats->r2_cycle_count, '==', 100);

    # This run has the same sample in both lanes.
    my $lane_stats = $stats->lanes->{1};
    my $lane_two = $stats->lanes->{2};

    my @lane_one_samples = $lane_stats->all_samples;
    my @lane_two_samples = $lane_two->all_samples;
    is_deeply(
        [sort map {$_->sample_name} @lane_one_samples],
        [sort map {$_->sample_name} @lane_two_samples],
        'Sample names are in both lanes'
    );
}

{
    # Testing high barcode count per sample.
    my $manifest = 't/data/elembio/20250401_AV244103_NT1853579T/RunManifest.json';
    my $stats_file = 't/data/elembio/20250401_AV244103_NT1853579T/slim_20250401_AV244103_NT1853579T.json';
    my $lane_count = 1;

    my $stats = npg_qc::elembio::run_stats::run_stats_from_file($manifest, $stats_file, $lane_count);
    ok($stats);
    is_deeply([keys %{$stats->lanes}], ['1']);
    cmp_ok($stats->r1_cycle_count, '==', 300);
    cmp_ok($stats->r2_cycle_count, '==', 300);

    my $lane_stats = $stats->lanes->{1};
    my @all_samples = $lane_stats->all_samples;
    cmp_ok(
        144 * scalar @all_samples,
        '==',
        sum(map { scalar keys %{$_->barcodes} } @all_samples),
        '12 I1 x 12 I2 permutations means barcode count is much larger than sample count'
    );
    for my $sample (@all_samples) {
        ok($sample->barcode_string(), 'Barcode stringification never fails on multi-barcode samples');
    }
}


done_testing();
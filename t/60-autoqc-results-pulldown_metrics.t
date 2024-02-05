use strict;
use warnings;
use Test::More tests => 11;
use Test::Exception;

use_ok ('npg_qc::autoqc::results::pulldown_metrics');

{
    my $r = npg_qc::autoqc::results::pulldown_metrics->new(id_run => 12, position => 3, path => q[mypath]);
    isa_ok ($r, 'npg_qc::autoqc::results::pulldown_metrics');
    is($r->check_name(), 'pulldown metrics', 'check name');
    is($r->class_name(), 'pulldown_metrics', 'class name');
}

{
    my $pulldown;
    lives_ok {
        $pulldown = npg_qc::autoqc::results::pulldown_metrics->load(
            't/data/autoqc/pulldown_metrics/39193_3_14.pulldown_metrics.json'
        );
    } 'Deserializing from JSON serialisation of pulldown result';

    cmp_ok($pulldown->picard_version_base_count, '==', 4813559010, 'Older Picard output gives correct base metric');
    cmp_ok(sprintf("%.1f", $pulldown->on_bait_bases_percent), '==', 52.8, 'Percentage on bait is calculated correctly');
}

{
    my $pulldown;
    lives_ok {
        $pulldown = npg_qc::autoqc::results::pulldown_metrics->load(
            't/data/autoqc/pulldown_metrics/40739_2_29.pulldown_metrics.json'
        );
    } 'Deserializing from JSON serialisation of pulldown result';

    cmp_ok($pulldown->picard_version_base_count, '==', 4629842424, 'GATK-embedded Picard output gives correct base metric');
    cmp_ok(sprintf("%.1f", $pulldown->on_bait_bases_percent), '==', 61.0, 'Percentage on bait is calculated correctly');
}

subtest 'invoke methods for a partially defined result' => sub {
  plan tests => 23;

   my $pulldown;
    lives_ok {
        $pulldown = npg_qc::autoqc::results::pulldown_metrics->load(
            't/data/autoqc/pulldown_metrics/48367_2_2.pulldown_metrics.json'
        );
    } 'Load pulldown JSON with most data absent';
    for my $method (qw/
        bait_design_efficiency unique_reads_percent unique_reads_aligned_percent
        on_bait_reads_percent near_bait_reads_percent on_target_reads_percent
        selected_bases_percent on_bait_bases_percent near_bait_bases_percent
        off_bait_bases_percent  on_bait_vs_selected_percent
        on_target_bases_percent zero_coverage_targets_percent
        target_bases_coverage_percent bait_bases_coverage_percent
        bait_bases_coverage_percent hs_penalty picard_version_base_count
    /) {
        my $value;
        lives_ok { $value = $pulldown->$method } "no error invoking '$method'";
        if (defined $value) {
            ok ((ref $value eq 'HASH') && (scalar keys %{$value} == 0),
                q[if the value is defined, it's an empty hash]);
        }
    }
};

1;

#########
# Author:        mg8
# Created:       2 May 2012
#

use strict;
use warnings;
use Test::More tests => 10;
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

1;
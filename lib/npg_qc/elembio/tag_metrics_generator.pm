package npg_qc::elembio::tag_metrics_generator;

use strict;
use warnings;
use base qw(Exporter);
use Readonly;
use npg_qc::autoqc::results::tag_metrics;

our @EXPORT_OK = qw(convert_run_stats_to_tag_metrics);
our $VERSION = '0';
Readonly::Scalar my $PERCENT_TO_DECIMAL => 100;

sub convert_run_stats_to_tag_metrics {
    my $run_stats = shift;
    my $id_run = shift;

    my @metrics;

    while (my($lane, $lane_stats) = each %{$run_stats->lanes}) {
        my $metrics_obj = npg_qc::autoqc::results::tag_metrics->new(
            id_run => $id_run,
            position => $lane_stats->lane,
        );
        foreach my $sample ($lane_stats->all_samples()) {
            # Polony counts found in RunStats.json are all after the perfomance filter
            # For numbers prior to filtering, see AvitiRunStats.json.
            $metrics_obj->reads_pf_count->{$sample->tag_index} = $sample->num_polonies;
            $metrics_obj->tags->{$sample->tag_index} = $sample->barcode_string();
            # It's hard to infer unfiltered polonies per sample from source
            # data. Set equal to regular polony count
            $metrics_obj->reads_count->{$sample->tag_index} = $sample->num_polonies;
            $metrics_obj->one_mismatch_matches_count->{$sample->tag_index} = ($sample->percentMismatch / $PERCENT_TO_DECIMAL) * $sample->num_polonies;
            $metrics_obj->perfect_matches_count->{$sample->tag_index} = ($PERCENT_TO_DECIMAL - $sample->percentMismatch) / $PERCENT_TO_DECIMAL * $sample->num_polonies;
            $metrics_obj->one_mismatch_matches_pf_count->{$sample->tag_index} = ($sample->percentMismatch / $PERCENT_TO_DECIMAL) * $sample->num_polonies;
            $metrics_obj->perfect_matches_pf_count->{$sample->tag_index} = ($PERCENT_TO_DECIMAL - $sample->percentMismatch) / $PERCENT_TO_DECIMAL * $sample->num_polonies;
            $metrics_obj->matches_pf_percent->{$sample->tag_index} = $sample->num_polonies / $lane_stats->num_polonies;
            $metrics_obj->matches_percent->{$sample->tag_index} = $sample->num_polonies / $lane_stats->num_polonies;

            # To get automatic calculations of variation/underrepresented tags
            # we need to set spiked_control_index once. Can only work properly
            # once SciOps are using a single name for the PhiX sample.
            # if ($sample->sample_name !~ /Adept/xsm) {
            #  $metrics->spiked_control_index($sample->tag_index);
            #}
        }
        # Add tag 0 (unassigned reads) as a sample
        # As above, pf_count is what we get. Assign it to both
        $metrics_obj->reads_count->{'0'} = $lane_stats->unassigned_reads;
        $metrics_obj->reads_pf_count->{'0'} = $lane_stats->unassigned_reads;

        my ($sample) = $lane_stats->all_samples();
        my ($i1_length, $i2_length) = $sample->index_lengths();
        $metrics_obj->tags->{'0'} = 'N' x $i1_length;
        if ($i2_length) {
            $metrics_obj->tags->{'0'} .= q{-} . 'N' x $i2_length;
        }

        push @metrics, $metrics_obj;
    }
    return @metrics;
}

1;
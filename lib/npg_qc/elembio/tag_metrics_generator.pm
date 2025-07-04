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

__END__


=head1 NAME

    npg_qc::elembio::tag_metrics_generator

=head1 SYNOPSIS

    my @per_lane_metrics = convert_run_stats_to_tag_metrics($run_stats, $id_run);
    foreach my $tag_metrics (@per_lane_metrics) {
        $tag_metrics->store();
    }

=head1 DESCRIPTION

A single function for use in scripts that converts from npg_qc::elembio::run_stats
objects into npg_qc::autoqc::results::tag_metrics objects.

It handles the mappings from ElemBio space to NPG QC space

=head1 SUBROUTINES/METHODS

=head2 convert_run_stats_to_tag_metrics

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Exporter

=item Readonly

=item npg_qc::autoqc::results::tag_metrics;

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Kieron Taylor E<lt>kt19@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2025 Genome Research Ltd.

This file is part of NPG.

NPG is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut

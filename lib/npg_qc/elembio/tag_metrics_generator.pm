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
    my ($run_stats, $id_run) = @_;

    my @metrics = ();

    while (my($lane, $lane_stats) = each %{$run_stats->lanes}) {
        my $metrics_obj = npg_qc::autoqc::results::tag_metrics->new(
            id_run => $id_run,
            position => $lane_stats->lane,
        );
        my $sample_count = 0;
        my $barcode_count = 0;
        foreach my $sample ($lane_stats->all_samples()) {
            $sample_count++;
            my $barcode_string = $sample->barcode_string();
            my $num_barcodes = scalar keys %{$sample->barcodes};
            $barcode_count += $num_barcodes;
            if ($num_barcodes > 1) {
                # Add a hint about the number of barcodes.
                $barcode_string .= sprintf '[+%i]', $num_barcodes - 1;
            }
            $metrics_obj->tags->{$sample->tag_index} = $barcode_string;
            _add_decode_stats($metrics_obj, $sample, $lane_stats);
        }

        # Add tag zero (unassigned reads) as a sample.
        _add_tagzero_data($metrics_obj, $lane_stats);

        if ($barcode_count > $sample_count) {
            _add_multibarcode_message($metrics_obj);
        }

        push @metrics, $metrics_obj;
    }
    return @metrics;
}

sub _add_decode_stats{
    my ($metrics_obj, $sample, $lane_stats) = @_;

    my $tag_index = $sample->tag_index;
    # Polony counts found in RunStats.json are all after the perfomance filter
    # For numbers prior to filtering, see AvitiRunStats.json.
    $metrics_obj->reads_pf_count->{$tag_index} = $sample->num_polonies;
    # It's hard to infer unfiltered polonies per sample from source
    # data. Set equal to regular polony count
    $metrics_obj->reads_count->{$tag_index} = $sample->num_polonies;

    my $num_perfect_matches = int sprintf '%.0f', (
        ($PERCENT_TO_DECIMAL - $sample->percentMismatch) / $PERCENT_TO_DECIMAL * $sample->num_polonies
    );
    $metrics_obj->perfect_matches_count->{$tag_index} = $num_perfect_matches;
    $metrics_obj->perfect_matches_pf_count->{$tag_index} = $num_perfect_matches;

    my $num_one_mismatches = ($sample->percentMismatch / $PERCENT_TO_DECIMAL) * $sample->num_polonies;
    $metrics_obj->one_mismatch_matches_count->{$tag_index} = $num_one_mismatches;
    $metrics_obj->one_mismatch_matches_pf_count->{$tag_index} = $num_one_mismatches;
    _assign_fraction_of_matches($tag_index, $metrics_obj, $lane_stats->num_polonies);
    return;
}

sub _add_tagzero_data {
    my ($metrics_obj, $lane_stats) = @_;

    my $tag_index = '0';
    my $reads_count = $lane_stats->unassigned_reads;
    $metrics_obj->reads_count->{$tag_index} = $reads_count;
    $metrics_obj->reads_pf_count->{$tag_index} = $reads_count;
    $metrics_obj->perfect_matches_pf_count->{$tag_index} = 0;
    $metrics_obj->perfect_matches_count->{$tag_index} = 0;
    $metrics_obj->one_mismatch_matches_count->{$tag_index} = 0;
    $metrics_obj->one_mismatch_matches_pf_count->{$tag_index} = 0;
    _assign_fraction_of_matches($tag_index, $metrics_obj, $lane_stats->num_polonies);
    my ($sample) = $lane_stats->all_samples();
    my ($i1_length, $i2_length) = $sample->index_lengths();
    $metrics_obj->tags->{$tag_index} = 'N' x $i1_length;
    if ($i2_length) {
        $metrics_obj->tags->{$tag_index} .= q{-} . 'N' x $i2_length;
    }

    return;
}

sub _assign_fraction_of_matches {
    my ($tag_index, $metrics_obj, $lane_num_polonies) = @_;
    my $fraction_of_matches = $lane_num_polonies ?
        $metrics_obj->reads_count->{$tag_index} / $lane_num_polonies : 0;
    $metrics_obj->matches_pf_percent->{$tag_index} = $fraction_of_matches;
    $metrics_obj->matches_percent->{$tag_index} = $fraction_of_matches;
    return;
}

sub _add_multibarcode_message {
    my $metrics_obj = shift;
    my $message = 'Where the barcode has a number in square brackets appended, ' .
        'the tag index represents multiple barcodes. ' .
        'Use MLWH to inspect decode rate on individual barcodes.';
    $metrics_obj->add_comment($message);
    return;
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

A single function for use in scripts that converts from C<npg_qc::elembio::run_stats>
objects into C<npg_qc::autoqc::results::tag_metrics> objects.

It handles the mappings from ElemBio space to NPG QC space.

=head1 SUBROUTINES/METHODS

=head2 convert_run_stats_to_tag_metrics

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Exporter

=item Readonly

=item npg_qc::autoqc::results::tag_metrics

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

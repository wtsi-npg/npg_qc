package npg_qc::elembio::run_stats;

use Moose;
use Carp;
use File::Slurp qw(read_file);
use JSON;
use List::Util qw(uniq sum);
use Readonly;
use namespace::autoclean;

use npg_qc::elembio::barcode_stats;
use npg_qc::elembio::lane_stats;
use npg_qc::elembio::sample_stats;

our $VERSION = '0';

has lanes => (
    traits => ['Hash'],
    isa => 'HashRef[npg_qc::elembio::lane_stats]',
    is => 'rw',
    handles => {
        get_lane => 'get',
        set_lane => 'set',
    },
);

has r1_cycle_count => (
    isa => 'Int',
    is => 'rw',
);

has r2_cycle_count => (
    isa => 'Int',
    is => 'rw',
);

__PACKAGE__->meta->make_immutable;

no Moose;
# Builder functions that create the run_stats instance with data

Readonly::Scalar my $ALL_THE_PERCENT => 100;

sub run_stats_from_json {
    my $runstats_ref = shift;
    my $manifest_ref = shift;
    my $lane_count = shift;

    my $data = decode_json(${$runstats_ref});
    my $manifest = decode_json(${$manifest_ref});

    # Make some sample objects from the manifest to be fleshed out with stats
    # later on. The safest way to get the barcodes is via manifest.
    my %sample_lookup;
    foreach my $sample (@{$manifest->{Samples}}) {
        foreach my $lane (1..$lane_count) {
            my $sample_obj = npg_qc::elembio::sample_stats->new(
                sample_name => $sample->{SampleName},
                tag_index => int($sample->{SampleNumber}),
                lane => $lane,
            );
            my (@tags_in_lane) = grep { $_->{Lane} == $lane } @{ $sample->{Indexes} };
            for my $tag (@tags_in_lane) {
                my $barcode = [$tag->{Index1}];
                if ($tag->{Index2}) {
                    push @{$barcode}, $tag->{Index2};
                }
                my $stats = npg_qc::elembio::barcode_stats->new(barcodes => $barcode);
                $sample_obj->add_barcode($stats->barcode_string, $stats);
            }

            $sample_lookup{$lane}->{$sample->{SampleName}} = $sample_obj;
        }
    }

    # For one lane, find the Reads section for R1, extract the MeanReadLength
    # and cast to int. Then repeat for R2. R2 not always present!
    # We can examine the RunParameters.json file for this, but it's implied
    # directly in RunStats.json by the absence.
    my $run_stats = npg_qc::elembio::run_stats->new(
        r1_cycle_count => int((grep { $_->{Read} eq 'R1' } @{$data->{Lanes}[0]{Reads}} )[0]->{MeanReadLength}),
    );
    my @read_two_data = grep { $_->{Read} eq 'R2' } @{$data->{Lanes}[0]{Reads}};
    if (scalar @read_two_data > 0) {
        $run_stats->r2_cycle_count(int($read_two_data[0]->{MeanReadLength}));
    }
    # Add lane stats to the runstats object
    foreach my $lane (@{$data->{Lanes}}) {
        # We get a false Lane 2 when a 300 cycle run is configured
        # This can only be determined from the original manifest
        next if $lane->{Lane} > $lane_count;
        my $lane_number = $lane->{Lane};
        $run_stats->set_lane(
            $lane_number,
            npg_qc::elembio::lane_stats->new(
                lane => $lane_number,
                num_polonies => $lane->{NumPolonies},
                total_yield => $lane->{TotalYield},
                # We do not explicitly get the unassigned read count for lanes
                # It has to be approximated by calculation
                unassigned_reads => int sprintf('%.0f',
                  (($ALL_THE_PERCENT - $lane->{PercentAssignedReads}) * $lane->{NumPolonies}) / $ALL_THE_PERCENT),
                unassigned_reads_percent => $ALL_THE_PERCENT - $lane->{PercentAssignedReads},
                percentQ30 => $lane->{PercentQ30},
                percentQ40 => $lane->{PercentQ40},
            )
        );
    }

    # Add sample stats to the lanes
    foreach my $sample (@{$data->{SampleStats}}) {
        # Occurrences describe the number of times a sample was found across
        # all lanes. Potentially multiple hits where many barcodes are used
        # for a single sample
        foreach my $lane (1..$lane_count) {
            my $laned_sample = $sample_lookup{$lane}->{$sample->{SampleName}};

            foreach my $occurrence (grep { $_->{Lane} eq $lane } @{$sample->{Occurrences}}) {
                # 1+2 300 cycle run appears in stats as lane 2 being full of nulls
                # and 0's. This also "disappears" any incorrectly requested
                # barcodes from the stats. What else can we do?

                my ($i1, $i2) = $laned_sample->index_lengths;
                my $expected_barcode = $occurrence->{ExpectedSequence};
                if ($i2) {
                    substr $expected_barcode, $i1, 0, q{-};
                }
                if (!exists $laned_sample->barcodes->{$expected_barcode}) {
                    croak "Cannot match $expected_barcode with what was found in manifest\n";
                }
                my $barcode_stats = $laned_sample->barcodes->{$expected_barcode};
                $barcode_stats->num_polonies($occurrence->{NumPolonies});
                $barcode_stats->yield($occurrence->{Yield});
                $barcode_stats->percentQ30($occurrence->{PercentQ30});
                $barcode_stats->percentQ40($occurrence->{PercentQ40});
                $barcode_stats->percentMismatch($occurrence->{PercentMismatch});
            }
            $run_stats->lanes->{$lane}->set_sample($sample->{SampleName}, $laned_sample);
        }
    }
    return $run_stats;
}

sub run_stats_from_file {
    my $manifest_file = shift;
    my $run_stats_file = shift;
    my $lane_count = shift;

    if (!$run_stats_file || !$manifest_file || !$lane_count) {
        croak 'Missing argument(s), specify RunStats.json, RunManifest.json and lane count';
    }

    my $manifest = read_file($manifest_file);
    my $run_stats = read_file($run_stats_file);
    return run_stats_from_json(\$run_stats, \$manifest, $lane_count);
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

npg_qc::elembio::run_stats

=head1 SYNOPSIS

  use npg_qc::elembio::run_stats;
  my $run_stats = npg_qc::elembio::run_stats::run_stats_from_file(
    "RunManifest.json",
    "RunStats.json",
    2
  );

  my $lane_stats = $run_stats->get_lane('1');
  ...

=head1 DESCRIPTION

Contains a definition of C<npg_qc::elembio::run_stats> class and factory
methods for generating an instance of this class from information in
RunStats.json and RunManifest.json files.

These JSON files are generated by Elembio C<bases2fastq> tool.

C<npg_qc::elembio::run_stats> class has the following attributes:

=over

=item lanes - A dictionary of C<npg_qc::elembio::lane_stats> objects keyed
by their lane numbers.

=item r1_cycle_count - Number of cycles in Read 1.

=item r2_cycle_count - Number of cycles in Read 1.

=back

=head1 SUBROUTINES/METHODS

=head2 run_stats_from_file

Accepts two filenames, one for RunStats.json and one for RunManifest.json.
It also requires a number of lanes to expect, which can be inferred from
the manifest, or by using Monitor::Elembio::RunFolder->lane_count.
It then creates and returns a C<npg_qc::elembio::run_stats> instance populated
with the information found in those files.

=head2 run_stats_from_json

Accepts two strings by reference containing RunStats.json and RunManifest.json
content. Also requires a number of lanes to expect, see above.
This function exists to allow bypassing of the file-reading component.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Carp

=item File::Slurp

=item JSON

=item List::Util

=item Readonly

=item namespace::autoclean

=item npg_qc::elembio::lane_stats

=item npg_qc::elembio::sample_stats

=item npg_qc::elembio::barcode_stats

=back

=head1 INCOMPATIBILITIES

Only applicable to Sequencing-type runs from the Aviti24. Cell profiling is
not compatible.

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

package npg_qc::elembio::lane_stats;

use Moose;
use namespace::autoclean;
use npg_qc::elembio::sample_stats;


our $VERSION = '0';

has lane => (
    isa => 'Int',
    is => 'ro'
);

has num_polonies => (
    isa => 'Int',
    is => 'ro',
);

has deplexed_samples => (
    isa => 'HashRef[npg_qc::elembio::sample_stats]',
    is => 'ro',
    init_arg => undef,
    required => 0,
    traits => ['Hash'],
    handles => {
        set_sample => 'set',
        get_sample => 'get',
        all_samples => 'values',
    },
);

has total_yield => (
    isa => 'Num',
    is => 'ro',
);

has unassigned_reads => (
    isa => 'Int',
    is => 'ro',
);

has unassigned_reads_percent => (
    isa => 'Num',
    is => 'ro',
);

has percentQ30 => (
    isa => 'Num',
    is => 'ro',
);

has percentQ40 => (
    isa => 'Num',
    is => 'ro',
);

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

npg_qc::elembio::lane_stats

=head1 SYNOPSIS

=head1 DESCRIPTION

Represents lane stats from an Elembio bases2fastq RunStats.json file.
It has overall statistics for the lane.

=head1 SUBROUTINES/METHODS

=head2 lane

An attribute. Sequential index of this lane.

=head2 num_polonies

An attribute. Effectively the number of reads from this lane.

=head2 deplexed_samples

An attribute. A dictionary of C<npg_qc::elembio::sample_stats> objects
keyed by its sample number.

=head2 total_yield

An attribute. Gigabase count for the lane.

=head2 unassigned_reads

An attribute. Number of reads that were not deplexed successfully.

=head2 unassigned_reads_percent

An attribute. Percentage of reads that were not deplexed successfully.

=head2 percentQ30

An attribute.

=head2 percentQ40

An attribute.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item npg_qc::elembio::sample_stats

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

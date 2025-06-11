package npg_qc::elembio::lane_stats;

use Moose;
use namespace::autoclean;
use npg_qc::elembio::sample_stats;


our $VERSION = '0';

has num_polonies => (
    isa => 'Int',
    is => 'ro',
    documentation => 'Effectively the number of reads from this lane',
);

has deplexed_samples => (
    isa => 'HashRef',
    is => 'ro',
    init_arg => undef,
    required => 0,
    traits => ['Hash'],
    handles => {
        set_sample => 'set',
        all_samples => 'values',
    },
);

has total_yield => (
    isa => 'Num',
    is => 'ro',
    documentation => 'Gigabase count for the lane',
);

has unassigned_reads => (
    isa => 'Int',
    is => 'ro',
    documentation => 'Number of reads that were not deplexed successful',
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
It has overall statistics for the lane, and deplexed_samples attribute that
indexes each sample found in the lane.

=head1 SUBROUTINES/METHODS

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

Copyright (C) 2025 GRL

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

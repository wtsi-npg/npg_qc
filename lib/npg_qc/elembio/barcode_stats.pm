package npg_qc::elembio::barcode_stats;

use Moose;
use namespace::autoclean;


our $VERSION = '0';

# In npg_qc, AAAAAAA-TTTTTT
# barcodes => [AAAAA, TTTTTT]
has barcodes => (
    isa => 'ArrayRef',
    is => 'rw',
    documentation => 'I1 and I2 sequences in order',
    default => sub {[]},
);

sub barcode_string {
    my $self = shift;
    return join q{-}, @{$self->barcodes};
}

sub index_lengths {
    my $self = shift;
    return length($self->barcodes->[0]), $self->barcodes->[1] ? length($self->barcodes->[1]) : undef;
}

has percentQ30 => (
    isa => 'Num',
    is => 'rw',
    documentation => 'Percentage of base calls over the Q30 threshold',
);

has percentQ40 => (
    isa => 'Num',
    is => 'rw',
    documentation => 'Percentage of base calls over the Q40 threshold',
);

has percentMismatch => (
    isa => 'Num',
    is => 'rw',
    documentation => 'Percentage of assigned reads that had "a" mismatch',
);
# See wording: https://docs.elembio.io/docs/elembio-cloud/run-charts-metrics/#indexing-assignment

has num_polonies => (
    isa => 'Int',
    is => 'rw',
    traits => ['Number'],
    default => 0,
    handles => {
        add_polonies => 'add'
    },
);

has yield => (
    isa => 'Num',
    is => 'rw',
    documentation => 'Gigabases for a barcode',
    default => 0,
);

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

npg_qc::elembio::barcode_stats

=head1 SYNOPSIS

$barcode->barcode_string(); # -> AAAAAAA-TTTTTTT
my ($i1, i2) = $sample->index_lengths;
if ($i2) {
    # $i2 might be undef
}

=head1 DESCRIPTION

Represents deplexed stats for a barcode from one lane.
Populated from an Elembio bases2fastq RunStats.json file by
npg_qc::elembio::run_stats.

=head1 SUBROUTINES/METHODS

=head2 barcode_string

Generates an npg_qc compatible barcode string from the individual index reads
stored in $self->barcodes. Limitation: Only renders one barcode to string, even
when there are many on this sample.

=head2 index_lengths

Returns I1 and I2 lengths. If there is no I2 the second return value is undef

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

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

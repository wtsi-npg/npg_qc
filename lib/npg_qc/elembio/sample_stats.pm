package npg_qc::elembio::sample_stats;

use Moose;
use namespace::autoclean;
use List::Util qw(sum);
use npg_qc::elembio::barcode_stats;


our $VERSION = '0';

has barcodes => (
    isa => 'HashRef[npg_qc::elembio::barcode_stats]',
    is => 'rw',
    documentation => 'Barcode pairs and their stats keyed by their barcode_string',
    default => sub {{}},
    traits => ['Hash'],
    handles => {
        add_barcode => 'set'
    },
);

sub barcode_string {
    my $self = shift;
    my ($first_barcode) = values %{$self->barcodes};
    return $first_barcode->barcode_string;
}

# Assumes all barcodes are equal length. Not necessarily true, but the ElemBio
# docs suggest that shorter barcodes would be padded with adapter sequence to
# bring them up to the same length
sub index_lengths {
    my $self = shift;
    my ($first_barcode) = values %{$self->barcodes};
    return $first_barcode->index_lengths();
}

has tag_index => (
    isa => 'Int',
    is => 'rw',
    documentation => 'Copied from SampleNumber from Elembio source data. \
      Not equivalent to the Illumina tag index, can represent multiple barcodes',
);

has sample_name => (
    isa => 'Str',
    is => 'ro',
);

sub _average_over_all_members {
    my $self = shift;
    my $key = shift;
    return sum(
        map { $_->{$key} ? $_->{$key} : 0 } values %{$self->barcodes}
    ) / scalar keys %{$self->barcodes}
}

##no critic NamingConventions::Capitalization
sub percentQ30 {
    my $self = shift;
    return $self->_average_over_all_members('percentQ30');
}

sub percentQ40 {
    my $self = shift;
    return $self->_average_over_all_members('percentQ40');
}

sub percentMismatch {
    my $self = shift;
    return $self->_average_over_all_members('percentMismatch');
}

sub num_polonies {
    my $self = shift;
    return sum(map {$_->num_polonies} values %{$self->barcodes});
}

sub yield {
    my $self = shift;
    return sum(map {$_->yield} values %{$self->barcodes});
}

has lane => (
    isa => 'Int',
    is => 'ro',
    documentation => 'Keep track of which lane these sample stats came from',
);

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

npg_qc::elembio::sample_stats

=head1 SYNOPSIS

$sample->barcode_string(); # -> AAAAAAA-TTTTTTT
my ($i1, i2) = $sample->index_lengths;
if ($i2) {
    # $i2 might be undef
}

my $pct_mismatch = $sample->percentMismatch();;

=head1 DESCRIPTION

Represents deplexed stats for sample for just one lane.
Populated from an Elembio bases2fastq RunStats.json file by
npg_qc::elembio::run_stats.

It can hold multiple barcodes for the same sample, esp. when the PhiX controls
are given a single name, rather than unique ones for each pair of index reads.

=head1 SUBROUTINES/METHODS

=head2 barcode_string

Generates an npg_qc compatible barcode string from the individual index reads
stored in $self->barcodes. Limitation: Only renders one barcode to string, even
when there are many on this sample.

=head2 index_lengths

Returns I1 and I2 lengths. If there is no I2 the second return value is undef

=head2 num_polonies
=head2 percentMismatch
=head2 percentQ30
=head2 percentQ40
=head2 yield

Calls the attribute on all barcodes in this sample and returns the sum or
averaged result as appropriate.


=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item npg_qc::elembio::barcode_stats

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

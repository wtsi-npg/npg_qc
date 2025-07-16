package npg_qc::elembio::sample_stats;

use Moose;
use namespace::autoclean;
use List::Util qw(sum);
use npg_qc::elembio::barcode_stats;


our $VERSION = '0';

has barcodes => (
    isa => 'HashRef[npg_qc::elembio::barcode_stats]',
    is => 'rw',
    default => sub {{}},
    traits => ['Hash'],
    handles => {
        add_barcode => 'set'
    },
);

sub barcode_string {
    my $self = shift;
    return $self->_first_barcode_object()->barcode_string();
}

sub index_lengths {
    my $self = shift;
    return $self->_first_barcode_object()->index_lengths();
}

has tag_index => (
    isa => 'Int',
    is => 'rw',
);

has sample_name => (
    isa => 'Str',
    is => 'ro',
);

has lane => (
    isa => 'Int',
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
##use critic

sub num_polonies {
    my $self = shift;
    return sum(map {$_->num_polonies} values %{$self->barcodes});
}

sub yield {
    my $self = shift;
    return sum(map {$_->yield} values %{$self->barcodes});
}

sub _first_barcode_object {
    my $self = shift;
    my @sorted_barcodes = sort { $a->barcode_string cmp $b->barcode_string } values %{$self->barcodes};
    return $sorted_barcodes[0];
}

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

my $pct_mismatch = $sample->percentMismatch();

=head1 DESCRIPTION

Represents deplexed stats for sample for just one lane.
Populated from an Elembio bases2fastq RunStats.json file by
npg_qc::elembio::run_stats.

It can hold multiple barcodes for the same sample, esp. when the PhiX controls
are given a single name, rather than unique ones for each pair of index reads.

Even when there are multiple barcodes per sample, a few methods of this
class return a property of a single C<npg_qc::elembio::barcode_stats>
object rather than an average or sum over all objects. To ensure idempotency
of these methods, C<npg_qc::elembio::barcode_stats> objects are sorted in
the alphabetical order of a returned value of the C<barcode_string> method
of the object and the relevant property of the first member of the sorted
list is returned.

=head1 SUBROUTINES/METHODS

=head2 barcodes

An attribute. A dictionary of c<npg_qc::elembio::barcode_stats> objects
keyed by their barcode_string.

=head2 tag_index

An attribute. Copied from SampleNumber from Elembio source data.
Not equivalent to the Illumina tag index, can represent multiple barcodes.

=head2 sample_name

An attribute. Sample name as provided in the manifest.

=head2 lane

An attribute. Keeps track of which lane these sample stats came from.

=head2 barcode_string

Generates an npg_qc compatible barcode string from the individual index reads
stored in $self->barcodes. Limitation: Only renders one barcode to string, even
when there are many on this sample.

=head2 index_lengths

Returns I1 and I2 lengths. If there is no I2 the second return value is undef.

Assumes all barcodes are equal length. Not necessarily true, but the ElemBio
docs suggest that shorter barcodes would be padded with adapter sequence to
bring them up to the same length

=head2 num_polonies

An attribute. Effectively the number of reads for this sample.

=head2 percentMismatch

An attribute. The percentage of reads that were assigned to this sample with a
single mismatch.

=head2 percentQ30

An attribute. Percentage of base calls at and over the Q30 threshold.

=head2 percentQ40

An attribute. Percentage of base calls at and over the Q40 threshold.

=head2 yield

Calls the attribute on all barcodes in this sample and returns the sum or
averaged result as appropriate. In gigabases.


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

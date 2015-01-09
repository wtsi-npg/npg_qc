package npg_qc::autoqc::role::adapter;

use Moose::Role;
use Readonly;

with qw(npg_qc::autoqc::role::result);

our $VERSION = '0';

Readonly::Scalar our $PERCENT              => 100;

sub forward_percent_contam_reads {
    my $self = shift;
    if (!defined $self->forward_fasta_read_count ||
            !defined $self->forward_contaminated_read_count ||
            $self->forward_fasta_read_count == 0) {
        return;
    }
    return sprintf '%0.2f',
        $PERCENT
        * $self->forward_contaminated_read_count()
        / $self->forward_fasta_read_count();
}


sub reverse_percent_contam_reads {
    my $self = shift;
    if (!defined $self->reverse_fasta_read_count ||
            !defined $self->reverse_contaminated_read_count ||
            $self->reverse_fasta_read_count == 0) {
        return;
    }
    return sprintf '%0.2f',
        $PERCENT
        * $self->reverse_contaminated_read_count()
        / $self->reverse_fasta_read_count();
}


no Moose;

1;

__END__


=head1 NAME

    npg_qc::autoqc::role::adapter

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SUBROUTINES/METHODS

=head2 forward_percent_contam_reads

=head2 reverse_percent_contam_reads

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

John O'Brien
Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 Genome Research Ltd

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

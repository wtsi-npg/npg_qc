package npg_qc::autoqc::role::rna_seqc;

use Moose::Role;
use Readonly;

our $VERSION = '0';

sub intronic_rate {
    my $self = shift;
    if ($self->other_metrics) {
        return $self->other_metrics->{'Intronic Rate'};
    }
    return;
}

sub transcripts_detected {
    my $self = shift;
    if ($self->other_metrics) {
        return $self->other_metrics->{'Transcripts Detected'};
    }
    return;
}

no Moose::Role;

1;

__END__


=head1 NAME

    npg_qc::autoqc::role::rna_seqc

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 intronic_rate

 Extract "Intronic Rate" metric from column other_metrics.

=cut

=head2 transcripts_detected

 Extract "Transcripts Detected" metric from column other_metrics.

=cut

=head2 get_comments

 Extract "comments" join them with new lines.

=cut

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

Ruben Bautista E<lt>rb11@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018 GRL

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

package npg_qc::autoqc::role::qX_yield;

use Moose::Role;
use Carp;

our $VERSION = '0';

## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc::autoqc::role::qX_yield

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 yield1_q20

Q20 yield in KBs for the first (forward) read -
aliase for yield1

=cut
sub yield1_q20 {
    my $self = shift;
    return $self->yield1();
}

=head2 yield2_q20

Q20 yield in KBs for the second (reverse) read -
aliase for yield2

=cut
sub yield2_q20 {
    my $self = shift;
    return $self->yield2();
}

=head2 criterion

Criterion that was used to evaluate a pass/fail for this check.

=cut
sub criterion {
    my ($self) = @_;
    return q[yield (number of KBs at and above Q] . $self->threshold_quality .
        q[) is greater than the threshold];
};

=head2 pass_per_read 

Returns a pass for an individual read, takes 1 or 2 as read index

=cut
sub pass_per_read {
    my ($self, $read_index) = @_;
    $self->_validate_read_index($read_index);
    my $pass = undef;
    my $yield_method = "yield$read_index";
    my $threshold_yield_method = "threshold_yield$read_index";
    if (defined $self->$threshold_yield_method && defined $self->$yield_method) {
        $pass = 0;
        if($self->$yield_method > $self->$threshold_yield_method) { $pass = 1 };
    }
    return $pass;
}

sub _validate_read_index {
    my ($self, $read_index) = @_;
    if ($read_index != 1 && $read_index != 2) {
        croak qq[Invalid read index $read_index, use 1 or 2 ];
    }
    return 1;
}

no Moose::Role;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Carp

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2016 GRL

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

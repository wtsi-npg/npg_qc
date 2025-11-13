package npg_qc::autoqc::role::qX_yield;

use Moose::Role;
use Carp;
use Readonly;

our $VERSION = '0';

## no critic (Documentation::RequirePodAtEnd)

Readonly::Scalar my $HUNDRED => 100;

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

=head2 percent1_q20

Q20 yield as percent for the forward read. Undefined if either Q20 yield
is undefined or the total forward read yield is either undefined or zero.

=cut

sub percent1_q20 {
    my $self = shift;
    if (defined $self->yield1() && $self->yield1_total()) {
       return ($self->yield1()/$self->yield1_total()) * $HUNDRED;
    }
    return;
}

=head2 percent2_q20

Q20 yield as percent for the reverse read. Undefined if either Q20 yield
is undefined or the total reverse read yield is either undefined or zero.

=cut

sub percent2_q20 {
    my $self = shift;
    if (defined $self->yield2() && $self->yield2_total()) {
       return ($self->yield2()/$self->yield2_total()) * $HUNDRED;
    }
    return;

}

=head2 percent1_q30

Q30 yield as percent for the forward read. Undefined if either Q30 yield
is undefined or the total forward read yield is either undefined or zero.

=cut

sub percent1_q30 {
    my $self = shift;
    if (defined $self->yield1_q30() && $self->yield1_total()) {
       return ($self->yield1_q30()/$self->yield1_total()) * $HUNDRED;
    }
    return;
}

=head2 percent2_q30

Q30 yield as percent for the reverse read. Undefined if either Q30 yield
is undefined or the total reverse read yield is either undefined or zero.

=cut

sub percent2_q30 {
    my $self = shift;
    if (defined $self->yield2_q30() && $self->yield2_total()) {
       return ($self->yield2_q30()/$self->yield2_total()) * $HUNDRED;
    }
    return;
}

=head2 percent_q20

Q20 overall yield as percent. Undefined if none of forward or revers Q20
is defined or the total yield is either undefined or zero.

=cut

sub percent_q20 {
    my $self = shift;

    my $q20 = $self->yield1();
    if (defined $q20 && defined $self->yield2()) {
        $q20 += $self->yield2();
    }
    my $total = $self->_total();
    if (defined $q20 && $total) {
       return ($q20/$total) * $HUNDRED;
    }

    return;
}

=head2 percent_q30

Q30 overall yield as percent. Undefined if none of forward or revers Q20
is defined or the total yield is either undefined or zero.

=cut

sub percent_q30 {
    my $self = shift;

    my $q30 = $self->yield1_q30();
    if (defined $q30 && defined $self->yield2_q30()) {
        $q30 += $self->yield2_q30();
    }
    my $total = $self->_total();
    if (defined $q30 && $total) {
       return ($q30/$total) * $HUNDRED;
    }

    return;
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

sub _total {
    my $self = shift;
    my $total = $self->yield1_total();
    if (defined $total && defined $self->yield2_total()) {
        $total += $self->yield2_total();
    }
    return $total;
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

=item Readonly

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

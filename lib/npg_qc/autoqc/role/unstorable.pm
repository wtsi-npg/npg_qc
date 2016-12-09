package npg_qc::autoqc::role::unstorable;

use Moose::Role;
use Carp;

our $VERSION = '0';

has 'store_nomore' => (is   => 'rw',
                       isa  => 'Bool',
                       default => 0,);

sub stop_storing {
    my $self = shift;
    $self->store_nomore(1);
    return;
}

1;
__END__

=head1 NAME

npg_qc::autoqc::role::unstorable

=head1 SYNOPSIS

# in your check's result class
# consume as any other role

package npg_qc::autoqc::results::myresult;
use Moose;
with 'npg_qc::autoqc::role::unstorable';

# then in the check class (that has a 'result'
# class attached to it when instantiated)

package npg_qc::autoqc::check::mycheck;
use Moose;
...
override 'execute' => sub {
    ... # some conditions to execute
    if (!$can_execute) {
       $self->result->stop_storing;
       carp 'this check should not be executed';
       return 1;
    }
    system $command or die; # conditions met
    return 1;
}
...

=head1 DESCRIPTION

Make a result unstorable by providing it with a flag that can be
used to avoid serialization.

=head1 SUBROUTINES/METHODS

=head2 stop_storing

Sets value of store_nomore flag to 1

=cut

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

Ruben E Bautista-Garcia<lt>rb11@sanger.ac.uk<gt>

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

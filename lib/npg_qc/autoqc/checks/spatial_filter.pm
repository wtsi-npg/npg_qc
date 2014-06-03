# Author:        david.jackson@sanger.ac.uk
# Created:       2011-09-29
#
#

package npg_qc::autoqc::checks::spatial_filter;

use strict;
use warnings;
use Moose;
use Carp;

extends qw(npg_qc::autoqc::checks::check);

our $VERSION = '0';

override 'execute' => sub {
	my ($self) = @_;

        $self->result->parse_output(); #read stderr from spatial_filter -a on stdin ....

	return 1;
};


no Moose;
__PACKAGE__->meta->make_immutable();


1;

__END__


=head1 NAME

npg_qc::autoqc::checks::spatial_filter - parse err stream from spatial_filter -a to record number of read filtered

=head1 SYNOPSIS

    use npg_qc::autoqc::checks::spatial_filter;

=head1 DESCRIPTION


=head1 SUBROUTINES/METHODS

=head2 new

    Moose-based.

=head1 DIAGNOSTICS

    None.

=head1 CONFIGURATION AND ENVIRONMENT

=head1 INCOMPATIBILITIES

    None known.

=head1 BUGS AND LIMITATIONS

=head1 DEPENDENCIES

=head1 AUTHOR

    Kevin Lewis, kl2

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2011 GRL, by David K. Jackson

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

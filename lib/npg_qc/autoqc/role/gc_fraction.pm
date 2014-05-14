#########
# Author:        Marina Gourtovaia
# Maintainer:    $Author: gq1 $
# Created:       03 February 2010
# Last Modified: $Date: 2009-12-14 15:21:01 +0000 (Mon, 14 Dec 2009) $
# Id:            $Id: sequence_error.pm 7671 2009-12-14 15:21:01Z gq1 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/branches/prerelease-24.0/lib/npg_qc/autoqc/role/sequence_error.pm $
#

package npg_qc::autoqc::role::gc_fraction;

use strict;
use warnings;
use Moose::Role;
use Readonly;

with qw(npg_qc::autoqc::role::result);

our $VERSION = do { my ($r) = q$Revision: 7671 $ =~ /(\d+)/smx; $r; };

sub criterion {
    my $self = shift;

    if ($self->threshold_difference) {
        return q[The difference between actual and expected GC percent is less than ] . $self->threshold_difference;
    }

    return q[];
}

no Moose;

1;

__END__


=head1 NAME

    npg_qc::autoqc::role::gc_fraction

=head1 VERSION

    $Revision: 7671 $

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 criterion

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

Author: Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Marina Gourtovaia

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

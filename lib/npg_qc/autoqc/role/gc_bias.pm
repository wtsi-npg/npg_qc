#########
# Author:        John O'Brien
# Maintainer:    $Author: jo3 $
# Created:       14 April 2009
# Last Modified: $Date: 2010-03-30 16:27:48 +0100 (Tue, 30 Mar 2010) $
# Id:            $Id: gc_bias.pm 8942 2010-03-30 15:27:48Z jo3 $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/autoqc/role/gc_bias.pm $
#

package npg_qc::autoqc::role::gc_bias;

use strict;
use warnings;
use Carp;
use Moose::Role;
use Readonly;
use POSIX qw(WIFEXITED);

with qw(npg_qc::autoqc::role::result);

our $VERSION = '0';


no Moose;

1;

__END__

=head1 NAME

    npg_qc::autoqc::role::gc_bias

=head1 VERSION

    $Revision: 8942 $

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Readonly

=item strict

=item warnings

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Author: John O'Brien E<lt>jo3@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by John O'Brien

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


#########
# Author:        Marina Gourtovaia
# Created:       13 July 2010
#

package npg_qc::autoqc::qc_store::options;

use strict;
use warnings;
use base 'Exporter';
use Readonly;

our $VERSION = '0';

our @EXPORT_OK = qw/$ALL $PLEXES $LANES/;

Readonly::Scalar our $ALL    => 1;
Readonly::Scalar our $PLEXES => 2;
Readonly::Scalar our $LANES  => 3;

1;
__END__


=head1 NAME

npg_qc::autoqc::qc_store::options

=head1 SYNOPSIS

=head1 DESCRIPTION

Constants to define retrival options for autoqc results

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item Readonly

=item Exporter

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

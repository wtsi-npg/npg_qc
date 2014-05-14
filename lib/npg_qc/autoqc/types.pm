#########
# Author:        Marina Gourtovaia
# Maintainer:    $Author$
# Created:       14 April 2009
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

package npg_qc::autoqc::types;

use strict;
use warnings;
use Moose::Util::TypeConstraints;
use English qw(-no_match_vars);
use Readonly;

our $VERSION    = do { my ($r) = q$Revision$ =~ /(\d+)/smx; $r; };
## no critic (Documentation::RequirePodAtEnd)


=head1 NAME

npg_qc::autoqc::types

=head1 VERSION

$Revision$

=head1 SYNOPSIS

=head1 DESCRIPTION

Custom types for this application.

=head1 SUBROUTINES/METHODS

=cut


Readonly::Scalar our $POSITION_MIN  => 1;
Readonly::Scalar our $POSITION_MAX  => 9;
Readonly::Scalar our $MIN_READS_TO_ALIGN  => 2;
Readonly::Scalar our $MAX_READS_TO_ALIGN  => 100_000;

subtype 'PositiveInt'
      => as Int
      => where { $_ > 0 };

subtype 'NonNegativeInt'
      => as Int
      => where { $_ >= 0 };

subtype 'LaneNumber'
      => as Int
      => where { $_ >= $POSITION_MIN && $_ <= $POSITION_MAX };

subtype 'Executable'
      => as Str
      => where { -x $_ };

subtype 'ReadableFile'
      => as Str
      => where { -r $_ };

subtype 'SampleSize4Aligning'
      => as Int
      => where { $_ >= $MIN_READS_TO_ALIGN && $_ <= $MAX_READS_TO_ALIGN };


no Moose::Util::TypeConstraints;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item Moose::Util::TypeConstraints

=item Carp

=item English

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

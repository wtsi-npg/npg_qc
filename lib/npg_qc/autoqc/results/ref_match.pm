#########
# Author:        John O'Brien
# Created:       14 April 2009
#

package npg_qc::autoqc::results::ref_match;

use strict;
use warnings;
use Moose;

extends qw(npg_qc::autoqc::results::result);
with qw(npg_qc::autoqc::role::ref_match);

our $VERSION = '0';


has aligned_read_count => ( is => 'rw', isa => 'HashRef[Int]', );
has reference_version  => ( is => 'rw', isa => 'HashRef[Str]', );
has aligner_version    => ( is => 'rw', isa => 'Str', );
has sample_read_count  => ( is => 'rw', isa => 'Int', );
has sample_read_length => ( is => 'rw', isa => 'Int', );

no Moose;

1;

__END__


=head1 NAME

    npg_qc::autoqc::results::ref_match

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 aligned_read_count

=head2 aligner_version

=head2 reference_version

=head2 sample_read_count

=head2 sample_read_length

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

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

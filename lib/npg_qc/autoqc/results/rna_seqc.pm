#########
# Author:        Ruben Bautista
# Created:       2015-08-13
#

package npg_qc::autoqc::results::rna_seqc;

use Moose;
use namespace::autoclean;

extends qw(npg_qc::autoqc::results::result);

our $VERSION = '0';

# No additional results functionality required by RNA-SeQC check.

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

  npg_qc::autoqc::results::rna_seqc

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item npg_qc::autoqc::results::result

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Ruben E Bautista-Garcia<lt>rb11@sanger.ac.uk<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2016 Genome Research Limited

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

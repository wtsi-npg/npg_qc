#########
# Author:        Ruben Bautista
# Created:       2015-08-13
#

package npg_qc::autoqc::results::rna_seqc;

use Moose;
use namespace::autoclean;
use Readonly;

extends qw(npg_qc::autoqc::results::result);
with qw(npg_qc::autoqc::role::rna_seqc);

our $VERSION = '0';
## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

  npg_qc::autoqc::results::rna_seqc

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 metrics_path

An absolute path to the directory with RNA-SeQC metrics files.

=cut
has 'rnaseqc_metrics_path' => (isa        => 'Maybe[Str]',
                               is         => 'rw',
                               required   => 0,
                               );

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Author: Ruben E Bautista-Garcia<lt>rb11@sanger.ac.uk<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2012 GRL, by Ruben Bautista

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

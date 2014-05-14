#########
# Author:        gq1
# Maintainer:    $Author$
# Created:       16 November 2009
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

package npg_qc::autoqc::results::sequence_error;

use strict;
use warnings;
use Moose;

extends qw(npg_qc::autoqc::results::result);
with qw(npg_qc::autoqc::role::sequence_error);

our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/smx; $r; };

has sequence_type                   => ( isa      => 'Maybe[Str]',
                                         is       => 'rw',
                                       );

has reference                       => ( isa      => 'Maybe[Str]',
                                         is       => 'rw',
                                       );

has forward_read_filename           => ( is  => 'rw',
                                         isa => 'Maybe[Str]',
                                       );

has reverse_read_filename           => ( is  => 'rw',
                                         isa => 'Maybe[Str]',
                                       );

has sample_size                     => ( is  => 'rw',
                                         isa => 'Maybe[Int]',
                                       );

has forward_aligned_read_count      => ( is  => 'rw',
                                         isa => 'Maybe[Int]',
                                       );

has reverse_aligned_read_count      => ( is  => 'rw',
                                         isa => 'Maybe[Int]',
                                       );

has forward_errors                  => ( is  => 'rw',
                                         isa => 'Maybe[ArrayRef]',
                                       );

has reverse_errors                  => ( is  => 'rw',
                                         isa => 'Maybe[ArrayRef]',
                                       );

has forward_n_count                 => ( is  => 'rw',
                                         isa => 'Maybe[ArrayRef]',
                                       );

has reverse_n_count                 => ( is  => 'rw',
                                         isa => 'Maybe[ArrayRef]',
                                       );

has forward_count                   => ( is  => 'rw',
                                         isa => 'Maybe[ArrayRef]',
                                       );

has reverse_count                   => ( is  => 'rw',
                                         isa => 'Maybe[ArrayRef]',
                                       );

has forward_quality_bins            => ( is  => 'rw',
                                         isa => 'Maybe[ArrayRef]',
                                       );

has reverse_quality_bins            => ( is  => 'rw',
                                         isa => 'Maybe[ArrayRef]',
                                       );

has quality_bin_values              => ( is  => 'rw',
                                         isa => 'Maybe[ArrayRef]',
                                       );

has forward_common_cigars           => ( is  => 'rw',
                                         isa => 'Maybe[ArrayRef]',
                                       );

has reverse_common_cigars           => ( is  => 'rw',
                                         isa => 'Maybe[ArrayRef]',
                                       );

has forward_cigar_char_count_by_cycle => ( is  => 'rw',
                                           isa => 'Maybe[HashRef]',
                                         );

has reverse_cigar_char_count_by_cycle => ( is  => 'rw',
                                           isa => 'Maybe[HashRef]',
                                         );

no Moose;

1;

__END__


=head1 NAME

    npg_qc::autoqc::results::sequence_error

=head1 VERSION

    $Revision$

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SUBROUTINES/METHODS

=head2 reference

=head2 forward_read_filename

=head2 reverse_read_filename

=head2 sample_size

=head2 forward_aligned_read_count

=head2 reverse_aligned_read_count

=head2 forward_errors

=head2 reverse_errors

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Author: Guoying Qi E<lt>gq1@sanger.ac.ukE<gt><gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Guoying Qi

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

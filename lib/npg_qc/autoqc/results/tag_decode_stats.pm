#########
# Author:        gq1
# Created:       16 November 2009
#

package npg_qc::autoqc::results::tag_decode_stats;

use strict;
use warnings;
use Moose;
use namespace::autoclean;

extends qw(npg_qc::autoqc::results::result);
with qw(npg_qc::autoqc::role::tag_decode_stats);

our $VERSION = '0';

has '+path'               =>  (
                               required   => 0,
		                        );

has 'tag_code'            =>  (isa => 'Maybe[HashRef]',
                               is => 'rw',
                               required => 0,
                               default  => sub { {} },
                              );

has 'distribution_all'    =>  (isa => 'Maybe[HashRef]',
                               is => 'rw',
                               required => 0,
                               default  => sub { {} },
                               );

has 'distribution_good'    =>  (isa => 'Maybe[HashRef]',
                               is => 'rw',
                               required => 0,
                               default  => sub { {} },
                               );

has 'errors_all'           =>  (isa => 'Maybe[HashRef]',
                               is => 'rw',
                               required => 0,
                               default  => sub { {} },
                               );

has 'errors_good'          =>  (isa => 'Maybe[HashRef]',
                               is => 'rw',
                               required => 0,
                               default  => sub { {} },
                               );

__PACKAGE__->meta->make_immutable;

1;

__END__


=head1 NAME

    npg_qc::autoqc::results::tag_decode_stats

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

=item npg_qc::autoqc::role::tag_decode_stats

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

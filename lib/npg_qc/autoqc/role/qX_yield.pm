#########
# Author:        gq1
# Maintainer:    $Author: mg8 $
# Created:       29 October 2009
# Last Modified: $Date: 2010-04-23 11:58:24 +0100 (Fri, 23 Apr 2010) $
# Id:            $Id: qX_yield.pm 9099 2010-04-23 10:58:24Z mg8 $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/autoqc/role/qX_yield.pm $
#

package npg_qc::autoqc::role::qX_yield;

use strict;
use warnings;
use Moose::Role;
use Carp;
use English qw(-no_match_vars);

with qw( npg_qc::autoqc::role::result );


our $VERSION = '0';

## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc::autoqc::role::qX_yield

=head1 VERSION

$Revision: 9099 $

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=cut


sub _validate_read_index {
    my ($self, $read_index) = @_;
    if ($read_index != 1 && $read_index != 2) {
        croak qq[Invalid read index $read_index, use 1 or 2 ];
    }
    return 1;
}


=head2 criterion

Criterion that was used to evaluate a pass/fail for this check.

=cut
sub criterion {
    my ($self) = @_;
    return q[yield (number of KBs at and above Q] . $self->threshold_quality . q[) is greater than the threshold];
};


=head2 pass_per_read 

Returns a pass for an individual read, takes 1 or 2 as read index

=cut
sub pass_per_read {
    my ($self, $read_index) = @_;
    $self->_validate_read_index($read_index);
    my $pass = undef;
    my $yield_method = "yield$read_index";
    my $threshold_yield_method = "threshold_yield$read_index";
    if (defined $self->$threshold_yield_method && defined $self->$yield_method) {
        $pass = 0;
        if($self->$yield_method > $self->$threshold_yield_method) { $pass = 1 };
    }
    return $pass;
}


no Moose;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Carp

=item English

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

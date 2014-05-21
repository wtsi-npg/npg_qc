#########
# Author:        Marina Gourtovaia
# Maintainer:    $Author: mg8 $
# Created:       10 May 2012
# Last Modified: $Date: 2012-05-15 09:52:42 +0100 (Tue, 15 May 2012) $
# Id:            $Id: alignment_filter_metrics.pm 15586 2012-05-15 08:52:42Z mg8 $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/autoqc/results/alignment_filter_metrics.pm $
#

package npg_qc::autoqc::results::alignment_filter_metrics;

use Moose;
use Readonly;

extends qw(npg_qc::autoqc::results::result);
with qw(npg_qc::autoqc::role::alignment_filter_metrics);

our $VERSION = '0';

has 'all_metrics'  =>  (isa       => 'HashRef',
                        is        => 'rw',
                        required  => 0,
		       );

no Moose;

1;

__END__

=head1 NAME

  npg_qc::autoqc::results::alignment_filter_metrics

=head1 VERSION

  $Revision: 15586 $

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 all_metrics

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Author: Marina Gourtovaia<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2012 GRL, by Marina Gourtovaia

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

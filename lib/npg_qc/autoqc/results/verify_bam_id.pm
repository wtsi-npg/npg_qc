#########
# Author:        Kevin Lewis
# Maintainer:    $Author: kl2 $
# Created:       27 April 2011
# Last Modified: $Date: 2013-04-11 16:31:25 +0100 (Thu, 11 Apr 2013) $
# Id:            $Id: genotype.pm 17015 2013-04-11 15:31:25Z kl2 $
# $HeadURL: svn+ssh://intcvs1/repos/svn/new-pipeline-dev/npg-qc/branches/prerelease-55.0/lib/npg_qc/autoqc/results/genotype.pm $
#

package npg_qc::autoqc::results::verify_bam_id;

use strict;
use warnings;
use Moose;

extends qw(npg_qc::autoqc::results::result);
with qw(npg_qc::autoqc::role::verify_bam_id);

our $VERSION = '0';

has bam_file    => ( is => 'rw', isa => 'Str', );
has number_of_snps    => ( is => 'rw', isa => 'Int', );
has number_of_reads    => ( is => 'rw', isa => 'Int', );
has avg_depth    => ( is => 'rw', isa => 'Num', );
has freemix    => ( is => 'rw', isa => 'Num', );
has freeLK0    => ( is => 'rw', isa => 'Num', );
has freeLK1    => ( is => 'rw', isa => 'Num', );
has warn    => ( is => 'rw', isa => 'Bool', );
has pass    => ( is => 'rw', isa => 'Bool', );

no Moose;

1;

__END__


=head1 NAME

    npg_qc::autoqc::results::verify_bam_id

=head1 VERSION

    $Revision: 17015 $

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 expected_sample_name

=head2 search_parameters

=head2 sample_name_match

=head2 sample_name_relaxed_match

=head2 alternate_match_count

=head2 alternate_relaxed_match_count

=head2 alternate_match

=head2 alternate_relaxed_match

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Author: Kevin Lewis<lt>kl2@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2011 GRL, by Kevin Lewis

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

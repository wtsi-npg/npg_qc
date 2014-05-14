#########
# Author:        Kevin Lewis
# Maintainer:    $Author: kl2 $
# Created:       25 August 2011
# Last Modified: $Date: $
# Id:            $Id: $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/branches/prerelease-24.0/lib/npg_qc/autoqc/role/genotype.pm $
#

package npg_qc::autoqc::role::genotype;

use strict;
use warnings;
use Moose::Role;
use Readonly;

with qw(npg_qc::autoqc::role::result);

our $VERSION = do { my ($r) = q$Revision: $ =~ /(\d+)/smx; $r; };
## no critic (Documentation::RequirePodAtEnd)

=head2 criterion

 Pass/Fail criterion

=cut

sub criterion {
	my $self = shift;

	if($self->expected_sample_name and $self->search_parameters and $self->search_parameters->{min_common_snps} and $self->search_parameters->{poss_dup_level}) {
		return q[Sample name is ] . $self->expected_sample_name . q[, number of common SNPs &ge; ] . $self->search_parameters->{min_common_snps} . q[ and percentage of loosely matched calls &gt; ] . $self->search_parameters->{poss_dup_level} . q[%] . q[ (fail: &lt;50%)];
	}

	return q[];
}

=head2 check_name

 The name of the check, modified to include the SNP call set

=cut

sub check_name {
	my $self = shift;

	my $ref = $self->class_name;
	$ref =~ s/_/ /gsmx;
	if($self->snp_call_set) {
		$ref = $ref.q{ }.$self->snp_call_set;
	}

	return $ref;
}

no Moose;

1;

__END__


=head1 NAME

    npg_qc::autoqc::role::genotype

=head1 VERSION

    $Revision: $

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 criterion

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Author: Kevin Lewis E<lt>kl2@sanger.ac.ukE<gt>

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

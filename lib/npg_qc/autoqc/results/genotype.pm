#########
# Author:        Kevin Lewis
# Created:       27 April 2011
#

package npg_qc::autoqc::results::genotype;

use strict;
use warnings;
use Moose;

extends qw(npg_qc::autoqc::results::result);
with qw(npg_qc::autoqc::role::genotype);

our $VERSION = '0';

has '+id_run' => (isa => 'Maybe[NpgTrackingRunId]', required => 0);
has '+position' => (isa => 'Maybe[NpgTrackingLaneNumber]', required => 0);

has genotype_data_set    => ( is => 'rw', isa => 'Str', );

has snp_call_set    => ( is => 'rw', isa => 'Str', );
has genotype_data_set    => ( is => 'rw', isa => 'Str', );
has bam_file    => ( is => 'rw', isa => 'Str', );
has bam_file_md5    => ( is => 'rw', isa => 'Str', );
has reference    => ( is => 'rw', isa => 'Str', );
has bam_call_count    => ( is => 'rw', isa => 'Int', );
has bam_call_string    => ( is => 'rw', isa => 'Str', );
has bam_gt_depths_string    => ( is => 'rw', isa => 'Str', );
has bam_gt_likelihood_string    => ( is => 'rw', isa => 'Str', );

has expected_sample_name    => ( is => 'rw', isa => 'Str', );
has search_parameters  => ( is => 'rw', isa => 'HashRef', );
has sample_name_match  => ( is => 'rw', isa => 'HashRef', );
has sample_name_relaxed_match  => ( is => 'rw', isa => 'HashRef', );
has alternate_matches => ( is => 'rw', isa => 'ArrayRef', );
has alternate_match_count  => ( is => 'rw', isa => 'Int', );
has alternate_relaxed_matches => ( is => 'rw', isa => 'ArrayRef', );
has alternate_relaxed_match_count  => ( is => 'rw', isa => 'Int', );

no Moose;

1;

__END__


=head1 NAME

    npg_qc::autoqc::results::genotype

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

package npg_qc::autoqc::results::verify_bam_id;

use Moose;
use namespace::autoclean;

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

__PACKAGE__->meta->make_immutable;

1;

__END__


=head1 NAME

    npg_qc::autoqc::results::verify_bam_id

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

=item namespace::autoclean

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Kevin Lewis<lt>kl2@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2016 GRL

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

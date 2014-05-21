# Author:        Marina Gourtovaia
# Maintainer:    $Author: mg8 $
# Created:       2012-04-25
# Last Modified: $Date: 2012-11-15 12:01:21 +0000 (Thu, 15 Nov 2012) $
# Id:            $Id: alignment_filter_metrics.pm 16223 2012-11-15 12:01:21Z mg8 $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/autoqc/checks/alignment_filter_metrics.pm $
#
#

package npg_qc::autoqc::checks::alignment_filter_metrics;

use Moose;
use English qw( -no_match_vars );
use JSON;
use Perl6::Slurp;
use Readonly;

extends qw(npg_qc::autoqc::checks::check);

our $VERSION = '0';

has '+input_file_ext' => (default => 'bam_alignment_filter_metrics.json',);

override 'execute' => sub {
    my ($self) = @_;

    if (super() == 0) {  return 1; }
    my $contents = slurp $self->input_files->[0];
    my $all_fields = from_json($contents);
    foreach my $field (qw/programName programVersion/) {
        if ($all_fields->{$field}) {
            my $new_field = $field eq 'programName' ? 'Aligner' : 'Aligner_version';
            $self->result->set_info( $new_field, $all_fields->{$field} );
            delete $all_fields->{$field};
        }
    }

    my @refs = @{$all_fields->{'refList'}};
    my $num_refs = scalar @refs;
    my $i = 0;
    while ( $i < $num_refs ) {
        my $ref = $refs[$i];
        if ( scalar @{$ref} > 1 ) {
            $all_fields->{'refList'}->[$i] = [$ref->[0]];
	}
        $i++;
    }

    $self->result->all_metrics($all_fields);
    return 1;
};

no Moose;
__PACKAGE__->meta->make_immutable();


1;
__END__


=head1 NAME

npg_qc::autoqc::checks::alignment_filter_metrics - stats for splitting files by alignment

=head1 VERSION

    $Revision: 16223 $

=head1 SYNOPSIS

=head1 DESCRIPTION


=head1 SUBROUTINES/METHODS

=head2 new

    Moose-based.


=head1 DIAGNOSTICS

    None.

=head1 CONFIGURATION AND ENVIRONMENT

=head1 INCOMPATIBILITIES

    None known.

=head1 BUGS AND LIMITATIONS

=head1 DEPENDENCIES

=over

=item Moose

=item English

=item JSON

=item Perl6::Slurp

=item Readonly

=back

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

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

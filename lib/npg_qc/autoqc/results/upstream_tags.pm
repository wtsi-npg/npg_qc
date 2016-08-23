package npg_qc::autoqc::results::upstream_tags;

use Moose;
use namespace::autoclean;

extends qw(npg_qc::autoqc::results::result);
with qw(npg_qc::autoqc::role::upstream_tags);

our $VERSION = '0';

has [ qw/ unexpected_tags
          prev_runs /    ] =>  (isa => 'ArrayRef',
                               is => 'rw',
                               default  => sub { return []; },
                               );

has [ qw/ tag_length
          total_lane_reads
          perfect_match_lane_reads
          tag0_perfect_match_reads
          total_tag0_reads /    ] => (isa => 'Maybe[Int]',
                                      is =>  'rw',
                                      );

has [ qw/ instrument_name
          instrument_slot
          barcode_file / ] => (isa => 'Maybe[Str]',
                                         is =>  'rw',
                                         );

__PACKAGE__->meta->make_immutable;

1;

__END__


=head1 NAME

 npg_qc::autoqc::results::upstream_tags

=head1 SYNOPSIS

 my $rObj = npg_qc::autoqc::results::upstream_tags->new(id_run => 6551, position => 1, path => q[my_path]);

=head1 DESCRIPTION

 An autoqc result object that checks for unexpected tags in the tag#0 bam file for a lane.
 Uses BamIndexDecoder (see http://wtsi-npg.github.io/illumina2bam/#BamIndexDecoder) to
 decode the bam file against a specified tag set, and reports presence of tags which are
 not expected in the lane. Also checks upstream runs (earlier runs on the same instrument/slot)
 to see if the tags may have come from there.

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item npg_qc::autoqc::results::result

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Kevin Lewis E<lt>kl2@sanger.ac.ukE<gt><gt>

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

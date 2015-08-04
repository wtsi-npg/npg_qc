package npg_qc_viewer::TransferObjects::ProductMetrics4RunTO;

use Moose;
use namespace::autoclean;

use npg_tracking::util::types;

our $VERSION = '0';
## no critic (Documentation::RequirePodAtEnd)

=begin stopwords

deplexing lims

=end stopwords

=head1 NAME

npg_qc_viewer::TransferObjects::ProductMetrics4RunTO

=head1 SYNOPSIS

=head1 DESCRIPTION

A transfer object to pass Product Metric data from the model to the view.

=head1 SUBROUTINES/METHODS

=cut

=head2 position

Lane number.

=cut
has 'position'     => (
  isa      => 'NpgTrackingLaneNumber',
  is       => 'rw',
  required => 1,
);

=head2 id_run

Run id.

=cut
has 'id_run'       => (
  isa      => 'NpgTrackingRunId',
  is       => 'rw',
  required => 1,
);

=head2 tag_index

Plex.

=cut
has 'tag_index'    => (
  isa      => 'Maybe[Int]',
  is       => 'rw',
  required => 0,
);

=head2 num_cycles

Number of cycles. Usually cycles@iseq_run_lane_metric

=cut
has 'num_cycles'   => (
  isa      => 'Maybe[Int]',
  is       => 'rw',
  required => 1,
);

=head2 time_comp

When run was complete

=cut
has 'time_comp'    => (
  is       => 'rw',
  required => 0,
);

=head2 tag_sequence

Tag sequence for deplexing

=cut
has 'tag_sequence' => (
  is       => 'rw',
  required => 0,
);

=head2 manual_qc

Result of manual qc.

=cut
has 'manual_qc'    => (
  isa      => 'Maybe[Int]',
  is       => 'rw',
  required => 0,
);

=head2 id_study_lims

Id of study lims

=cut
has 'id_study_lims'     => (
  is       => 'rw',
  required => 0,
);

=head2 study_name

Name study lims

=cut
has 'study_name'     => (
  is       => 'rw',
  required => 0,
);

=head2 sample_id

Id of sample lims

=cut
has 'id_sample_lims' => (
  is       => 'rw',
  required => 0,
);

=head2 sample_name

Name of sample lims

=cut
has 'sample_name' => (
  is       => 'rw',
  required => 0,
);

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item npg_tracking::util::types

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 Genome Research Ltd.

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

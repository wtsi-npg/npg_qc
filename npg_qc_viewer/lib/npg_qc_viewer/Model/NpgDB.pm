package npg_qc_viewer::Model::NpgDB;

use Carp;
use Moose;
use Readonly;

BEGIN { extends 'Catalyst::Model::DBIC::Schema' }

our $VERSION  = '0';
## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc_viewer::Model::NpgDB

=head1 SYNOPSIS  

=head1 DESCRIPTION

A model for the NPG database DBIx schema

=head1 SUBROUTINES/METHODS

=cut

__PACKAGE__->config(
  schema_class => 'npg_tracking::Schema',
  connect_info => [], #a fall-back position if connect_info is not defined in the config file
);

=head2 runlane_annotations

Returns annotations for lanes ordered by lane and date

=cut
sub runlane_annotations {
  my ($self, $id_run) = @_;

  if (!defined $id_run) {
    croak q[Run id not defined when quering runlane annotations];
  }

  my $rs = $self->resultset('RunLaneAnnotation')->search(
    {
      'run_lane.id_run' => $id_run,
    },
    {
      join     => [qw/run_lane annotation/],
      order_by => [qw/run_lane.position annotation.date/],
    },
  );

    return $rs;
}

=head2 run_annotations

Returns annotations for a run ordered by date

=cut
sub run_annotations {
  my ($self, $id_run) = @_;

  if (!defined $id_run) {
    croak q[Run id not defined when quering run annotations];
  }

  my $rs = $self->resultset('RunAnnotation')->search(
    {
      id_run => $id_run,
    },
    {
      join     => 'annotation',
      prefetch => 'annotation',
      order_by => 'annotation.date',
    },
  );
  return $rs;
}

=head2 update_lane_manual_qc_complete

Updates the status of a lane to manual qc complete

  $o->update_lane_manual_qc_complete( $iIdRun, $iPosition, $bDecision, $idUser);

=cut

sub update_lane_manual_qc_complete {
  my ( $self, $id_run, $position, $id_user ) = @_;

  if (!$id_user || !$position || !$id_run) {
    croak 'One of (user id, position, run id) is not given';
  }

  my $run_lane = $self->resultset( q{RunLane} )->find( {
      id_run => $id_run,
      position => $position,
  } );
  if (!$run_lane) {
    croak qq{Failed to get run_lane row for id_run $id_run, position $position};
  }
  $run_lane->update_status( q{manual qc complete}, $id_user );

  return;
}

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Readonly

=item Catalyst::Model::DBIC::Schema

=item npg_tracking::Schema

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 Genome Research Ltd.

This file is part of NPG software.

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


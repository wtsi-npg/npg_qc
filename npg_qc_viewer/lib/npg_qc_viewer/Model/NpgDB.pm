package npg_qc_viewer::Model::NpgDB;

use Carp;
use Moose;
use DateTime;
use Readonly;

BEGIN { extends 'Catalyst::Model::DBIC::Schema' }

our $VERSION  = '0';
## no critic (Documentation::RequirePodAtEnd)

Readonly::Array our @MQC_FIELDS => qw/
                                      status
                                      lims_object_id 
                                      lims_object_type
                                      referer
                                      batch_id
                                      position
                                     /;

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

=head2 runs_list

Result set with runs that should have qc checks available

=cut
sub runs_list {
    my $self = shift;

    my $QC_REVIEW_PENDING    = q{qc review pending};
    my $QC_IN_PROGRESS       = q{qc in progress};
    my $ARCHIVAL_PENDING     = q{archival pending};
    my $ARCHIVAL_IN_PROGRESS = q{archival in progress};
    my $ARCHIVAL_COMPLETE    = q{run archived};
    my $QC_COMPLETE          = q{qc complete};

    my @runs = ();

    foreach my $status ($QC_REVIEW_PENDING, $QC_IN_PROGRESS, $ARCHIVAL_PENDING,
                      $ARCHIVAL_IN_PROGRESS, $ARCHIVAL_COMPLETE,
                      $QC_COMPLETE) {
        my $temp =  $self->resultset('RunStatusDict')->search({description => $status});
        push @runs, $self->resultset('RunStatus')->search(
		     {
                        'iscurrent' => 1,
                        'id_run_status_dict' => {'IN', $temp->get_column('id_run_status_dict')->as_query},
                     },
		     {

                        join => 'run',
                        prefetch => 'run',
                        order_by => { -desc => 'run.id_run' },
		     },
							 )->all();
    }

    return \@runs;
}


=head2 log_manual_qc_action

Logs a new manual qc status to the database, flags the previous statuses for the same
object as not current.

=cut
sub log_manual_qc_action {
    my ($self, $values_in) = @_;

    if (!defined $values_in) {croak q[Manual qc logging: values hash should be defined];}
    my $user = $values_in->{user};
    if (!$user) {croak q[Manual qc logging: user should be set];}
    my $lims_object_id = $values_in->{lims_object_id};
    if (!$lims_object_id) { croak q[Manual qc logging: no lims object id];}
    my $lims_object_type = $values_in->{lims_object_type};
    if (!$lims_object_type) { croak q[Manual qc logging: no lims object type];}
    if (!defined $values_in->{status}) { croak q[Manual qc logging: no qc status];}
       my $status = $values_in->{status};
    if ($status != 1 && $status != 0) {
        croak qq[Manual qc logging: invalid status value $status];
    }

    my $values = {};
    foreach my $field (@MQC_FIELDS) {
      if (exists $values_in->{$field}) {
        $values->{$field} = $values_in->{$field};
      }
    }
    $values->{id_user} = $user;
    $values->{date} = DateTime->now();
    $values->{iscurrent} = 1;

    my $row_id;
    my $transaction = sub {
        my @current_rows = $self->resultset('ManualQcStatus')->search({lims_object_id => $lims_object_id, lims_object_type => $lims_object_type, iscurrent => 1,});
        map { $_->update({'iscurrent' => 0}) } @current_rows;
        my $row = $self->resultset('ManualQcStatus')->create($values);
        $row_id = $row->id_manual_qc_status;
    };
    $self->txn_do( $transaction );

    return $row_id;
}


=head2 runlane_annotations

Returns annotations for lanes ordered by lane and date

=cut
sub runlane_annotations {
    my ($self, $id_run) = @_;

    if (!defined $id_run) {
      croak q[Run id not defined when quering runlane annotations];
    }
    # Do not return without assigning to a variable
    # Gets garbage-collected
    my $rs = $self->resultset('RunLaneAnnotation')->search(
      {
        'run_lane.id_run' => $id_run,
      },
      {
        join => [qw/run_lane annotation/],
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
    # Do not return without assigning to a variable
    # Gets garbage-collected
    my $rs = $self->resultset('RunAnnotation')->search(
      {
        id_run => $id_run,
      },
      {
        join => 'annotation',
        prefetch => 'annotation',
        order_by => 'annotation.date',
      },
    );
    return $rs;
}


=head2 run_on_staging

Returns true if the run is still on staging, false otherwise

=cut
sub run_on_staging {
    my ($self, $id_run) = @_;

    if (!defined $id_run) {
        croak q[Run id not defined when quering whether the run is on staging];
    }
    return $self->resultset('TagRun')->search(
      {
        id_run => $id_run,
        id_tag => 19,
      }
    )->count;
}

=head2 update_lane_manual_qc_complete

Updates the status of a lane to manual qc complete, and sets the good_bad to 1 for good or 0 for bad

  $o->update_lane_manual_qc_complete( $iIdRun, $iPosition, $bDecision, $idUser);

=cut

sub update_lane_manual_qc_complete {
  my ( $self, $id_run, $position, $decision, $id_user ) = @_;

  if (!$id_user || !defined $decision || !$position || !$id_run) {
    croak 'One of (user id, pass-fail decision, position, run id) is not given';
  }

  my $run_lane = $self->resultset( q{RunLane} )->find( {
      id_run => $id_run,
      position => $position,
  } );
  if (!$run_lane) {
    croak qq{Failed to get run_lane row for id_run $id_run, position $position};
  }
  $run_lane->update( {'good_bad' => $decision,} );
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

=item DateTime

=item Catalyst::Model::DBIC::Schema

=item npg_tracking::Schema

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014 Genome Research Ltd.

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


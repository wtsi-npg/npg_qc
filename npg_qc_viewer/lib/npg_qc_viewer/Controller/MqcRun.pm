package npg_qc_viewer::Controller::MqcRun;

use Moose;
use namespace::autoclean;
use Readonly;
use Try::Tiny;
use Carp;

BEGIN { extends 'Catalyst::Controller::REST' }
with qw/
        npg_qc_viewer::Util::Error
        npg_qc_viewer::Util::ExtendedHttpStatus
       /;

our $VERSION = '0';

__PACKAGE__->config( default => 'application/json' );

Readonly::Scalar my $MQC_LANE_ENT  => q[MqcOutcomeEnt];
Readonly::Scalar my $MQC_LIB_ENT   => q[MqcLibraryOutcomeEnt];

sub _fill_entity_for_response{
  my ($self, $id_run, $c) = @_;

  my $hash_entity = {};
  $hash_entity->{'id_run'}                     = $id_run;
  my $crs = $c->model('NpgDB')->resultset('Run')->find($id_run)->current_run_status;
  $hash_entity->{'current_status_description'} = $crs ? $crs->description    : q[];
  $hash_entity->{'taken_by'}                   = $crs ? $crs->user->username : q[];
  my $user_info = $c->model('User')->logged_user($c);
  $hash_entity->{'current_user'}       = $user_info->{'username'};
  $hash_entity->{'has_manual_qc_role'} = $user_info->{'has_mqc_role'};

  return $hash_entity;
}

## no critic (NamingConventions::Capitalization)
sub mqc_runs : Path('/mqc/mqc_runs') : ActionClass('REST') { }

sub mqc_runs_GET {
  my ( $self, $c, $id_run ) = @_;

  try {
    if (!$id_run) {
      croak 'Run id is needed';
    }
    my $hash_entity = $self->_fill_entity_for_response($id_run, $c);
    $hash_entity->{'qc_lane_status'} = $c->model('NpgQcDB')
                                        ->resultset($MQC_LANE_ENT)
                                        ->get_outcomes_as_hash($id_run);
    $self->status_ok($c, entity => $hash_entity,);
  } catch {
    my ( $error1, $error_code ) = $self->parse_error($_);
    $self->status_internal_server_error($c, message => $error1,);
  };

  return;
}

## no critic (NamingConventions::Capitalization)
sub mqc_libraries : Path('/mqc/mqc_libraries') : ActionClass('REST') { }

sub mqc_libraries_GET {
  my ( $self, $c, $id_run_position ) = @_;

  my $qc_name = $npg_qc_viewer::Model::MLWarehouseDB::HASH_KEY_QC_TAGS;
  my $non_qc_name = $npg_qc_viewer::Model::MLWarehouseDB::HASH_KEY_NON_QC_TAGS;

  try {
    $id_run_position //= q[];
    my ($id_run, $position) = split /_/sm, $id_run_position;
    if (!$id_run || !$position) {
      croak 'Both run id and position are needed';
    }
    my $qc_outcomes = $c->model('NpgQcDB')
                        ->resultset($MQC_LIB_ENT)
                        ->get_outcomes_as_hash($id_run, $position);
    my $ent_lane = $c->model('NpgQcDB')
                     ->resultset($MQC_LANE_ENT)
                     ->find({'id_run' => $id_run, 'position' => $position},);
    my $current_lane_outcome = $ent_lane ? $ent_lane->mqc_outcome->short_desc
                                         : q[Undecided];

    my $hash_entity = $self->_fill_entity_for_response($id_run, $c);
    my $tags_hash = $c->model('MLWarehouseDB')
                   ->fetch_tag_index_array_for_run_position($id_run, $position);
    $hash_entity->{'mqc_lib_limit'}        = npg_qc::Schema::Mqc::OutcomeEntity->mqc_lib_limit;
    $hash_entity->{'position'}             = $position;
    $hash_entity->{'qc_plex_status'}       = $qc_outcomes;
    $hash_entity->{'current_lane_outcome'} = $current_lane_outcome;
    $hash_entity->{'qc_tags'}              = $tags_hash->{$qc_name};
    $hash_entity->{'non_qc_tags'}          = $tags_hash->{$non_qc_name};
    $self->status_ok($c, entity => $hash_entity,);
  } catch {
    my ( $error1, $error_code ) = $self->parse_error($_);
    $self->status_internal_server_error($c, message => $error1,);
  };

  return;
}

__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

npg_qc_viewer::Controller::MqcRun

=head1 SYNOPSIS

=head1 DESCRIPTION

Controller to expose manual qc outcome and other data about a run through REST

=head1 SUBROUTINES/METHODS 

=head2 mqc_runs

  Placeholder for the REST path for runs.

=head2 mqc_runs_GET

  Returns general information about the status of the run specified as part
  of the URL.

=head2 mqc_libraries

  Placeholder for the REST path for lane.

=head2 mqc_libraries_GET

  Returns general information about the status of the run and the lane 
  (its plexes) specified as part of the URL.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item Readonly

=item Try::Tiny

=item Carp

=item Catalyst::Controller::REST

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Jaime Tovar E<lt>jmtc@sanger.ac.ukE<gt>

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

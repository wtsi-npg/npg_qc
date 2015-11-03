package npg_qc_viewer::Controller::Mqc;

use Moose;
use namespace::autoclean;
use Readonly;
use Try::Tiny;
use JSON;
use Carp;
BEGIN { extends 'Catalyst::Controller' }

use npg_qc_viewer::Model::MLWarehouseDB;
with 'npg_qc_viewer::Util::Error';

our $VERSION  = '0';

Readonly::Scalar my $BAD_REQUEST_CODE      => 400;
Readonly::Scalar my $METHOD_NOT_ALLOWED    => 405;
Readonly::Scalar my $MODE_LANE_MQC         => q[LANE_MQC];
Readonly::Scalar my $MODE_LIBRARY_MQC      => q[LIBRARY_MQC];

sub _validate_req_method {
  my ($self, $c, $allowed) = @_;
  if ($c->request->method ne $allowed) {
    $self->raise_error(
      qq[Only $allowed requests are allowed.], $METHOD_NOT_ALLOWED);
  }
  return;
}

sub _set_response {
  my ($c, $message_data, $code) = @_;

  if (!$message_data) {
    croak 'Message hash should be supplied';
  }

  $c->response->headers->content_type('application/json');
  if ($code) {
    $c->response->status($code);
  }
  $c->response->body(to_json $message_data);

  return;
}

sub _request_params {
  my ($self, $c, @names) = @_;
  my $p = $c->request->parameters;
  my $values = {};
  foreach my $a (@names) {
    if (!$p->{$a}) {
      $self->raise_error(qq[$a should be defined], $BAD_REQUEST_CODE);
    }
    $values->{$a} = $p->{$a};
  }
  return $values;
}

sub _update_outcome {
  my ($self, $c, $working_as) = @_;

  if (!$working_as) {
    croak q[Working_as should be defined];
  }

  my $username;
  my $params = $c->request->parameters;
  my $new_outcome = $params->{'new_oc'};
  my $id_run      = $params->{'id_run'};
  my $position    = $params->{'position'};
  my $tag_index   = $params->{'tag_index'};

  try {

    $self->_validate_req_method($c, 'POST');
    $c->controller('Root')->authorise($c, qw/manual_qc/);
    $username    = $c->user->username;
    $self->_request_params($c, qw/id_run position new_oc/);
    if (!$username) {
      $self->raise_error(q[Username should be defined], $BAD_REQUEST_CODE)
    }

    my $message;
    if ($working_as eq $MODE_LANE_MQC) {
      my $hash_tags = $c->model('MLWarehouseDB')
                        ->fetch_tag_index_array_for_run_position($id_run, $position);
      my $qc_tags = $hash_tags->{$npg_qc_viewer::Model::MLWarehouseDB::HASH_KEY_QC_TAGS};

      $c->model('NpgQcDB')
               ->resultset('MqcOutcomeEnt')
               ->search_outcome_ent(
                 $id_run,
                 $position,
      )->update_outcome_with_libraries($new_outcome, $username, $qc_tags);
      $message = qq[Manual QC $new_outcome for run $id_run, position $position saved.];
      if ($c->model('NpgQcDB')->is_final_outcome($new_outcome)) {
        try {
          $c->model('NpgDB')->update_lane_manual_qc_complete($id_run, $position, $username);
        } catch {
          $message .= qq[ Error: Problem while updating lane status. $_];
        };
      }
    } else {
      $c->model('NpgQcDB')
               ->resultset('MqcLibraryOutcomeEnt')
               ->find_or_create_library_outcome_ent(
                 $id_run,
                 $position,
                 $tag_index,
                 $username
      )->update_nonfinal_outcome($new_outcome, $username);
      $message = qq[Manual QC $new_outcome for run $id_run, position $position, tag_index $tag_index saved.]
    }
    _set_response($c, {'message' => $message});
  } catch {
    my ($e, $response_code) = $self->parse_error($_);
    _set_response($c, {'message' => $e}, $response_code);
  };

  return;
}

sub update_outcome_library : Path('update_outcome_library') {
  my ($self, $c) = @_;
  return $self->_update_outcome($c, $MODE_LIBRARY_MQC);
}

sub update_outcome_lane : Path('update_outcome_lane') {
  my ($self, $c) = @_;
  return $self->_update_outcome($c, $MODE_LANE_MQC);
}

sub _get_outcome {
  my ($self, $c, $resultset_name, @params) = @_;

  try {
    $self->_validate_req_method($c, 'GET');
    my $values = $self->_request_params($c, @params);
    my $ent = $c->model('NpgQcDB')->resultset($resultset_name)->search($values)->next;
    _set_response($c, {'outcome'=> $ent ? $ent->mqc_outcome->short_desc : q[] });
  }  catch {
    my ($error, $error_code) = $self->parse_error($_);
    _set_response($c, {message => qq[Error: $error] }, $error_code);
  };

  return;
}

sub get_current_outcome : Path('get_current_outcome') {
  my ($self, $c) = @_;
  return $self->_get_outcome($c, 'MqcOutcomeEnt', qw/id_run position/);
}

sub get_current_library_outcome : Path('get_current_library_outcome') {
  my ($self, $c) = @_;
  return $self->_get_outcome($c, 'MqcLibraryOutcomeEnt', qw/id_run position tag_index/);
}

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 NAME

npg_qc_viewer::Controller::Mqc

=head1 SYNOPSIS

=head1 DESCRIPTION

A Catalyst Controller for retrieving and saving  manual qc outcomes.

=head1 SUBROUTINES/METHODS

=head2 update_outcome_lane

  Updates the mqc outcome for the lane using parameters from
  request (id_run, position, new_oc).

=head2 update_outcome_library

  Updates the mqc outcome for the library using parameters from
  request (id_run, position, tag_index, new_oc).

=head2 get_current_outcome

  Returns JSON with current outcome for the paramaters in
  request (id_run, position).

=head2 get_current_library_outcome

  Returns JSON with current outcome for the parameters in
  request(id_run, position, tag_index).

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Readonly

=item namespace::autoclean

=item Moose

=item Catalyst::Controller

=item Try::Tiny

=item JSON

=item Carp

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

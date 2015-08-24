package npg_qc_viewer::Controller::Mqc;

use Moose;
use namespace::autoclean;
use Readonly;
use Try::Tiny;
use JSON;
use Carp;

BEGIN { extends 'Catalyst::Controller' }

with 'npg_qc_viewer::Util::Error';

our $VERSION  = '0';

Readonly::Scalar my $BAD_REQUEST_CODE    => 400;
Readonly::Scalar my $OK_CODE             => 200;
Readonly::Scalar my $METHOD_NOT_ALLOWED  => 405;
Readonly::Scalar my $ALLOW_METHOD_POST   => q[POST];
Readonly::Scalar my $ALLOW_METHOD_GET    => q[GET];
Readonly::Scalar my $MQC_ROLE            => q[manual_qc];

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

  if ($code) { #There was an error
    $c->response->status($code);
  }
  $c->response->body(to_json $message_data);

  return;
}

sub update_outcome : Path('update_outcome') {
  my ($self, $c) = @_;

  my $id_run;
  my $position;
  my $tag_index;
  my $username;
  my $new_outcome;
  my $error;

  my $ent;

  try {
    ####Validating request method
    $self->_validate_req_method($c, $ALLOW_METHOD_POST);
    ####Authorisation
    $c->controller('Root')->authorise($c, ($MQC_ROLE));

    ####Loading state
    my $params = $c->request->parameters;
    $position    = $params->{'position'};
    $tag_index   = $params->{'tag_index'};
    $new_outcome = $params->{'new_oc'};
    $id_run      = $params->{'id_run'};
    $username    = $c->user->username;

    if (!$id_run) {
      $self->raise_error(q[Run id should be defined], $BAD_REQUEST_CODE);
    }
    if (!$position) {
      $self->raise_error(q[Position should be defined], $BAD_REQUEST_CODE);
    }
    if (!$new_outcome) {
      $self->raise_error(q[Mqc outcome should be defined], $BAD_REQUEST_CODE)
    }
    if (!$username) {
      $self->raise_error(q[Username should be defined], $BAD_REQUEST_CODE)
    }

    if (!$tag_index) { # Working as lane MQC
      $ent = $c->model('NpgQcDB')->resultset('MqcOutcomeEnt')->search(
        {'id_run' => $id_run, 'position' => $position})->next;
      if (!$ent) {
        $ent = $c->model('NpgQcDB')->resultset('MqcOutcomeEnt')->new_result({
          id_run         => $id_run,
          position       => $position,
          username       => $username,
          modified_by    => $username});
      }
      $ent->update_outcome($new_outcome, $username);
    } else { # Working as library MQC
      $ent = $c->model('NpgQcDB')->resultset('MqcLibraryOutcomeEnt')->search(
        {'id_run' => $id_run, 'position' => $position, 'tag_index' => $tag_index})->next;
      if (!$ent) {
        $ent = $c->model('NpgQcDB')->resultset('MqcLibraryOutcomeEnt')->new_result({
          id_run         => $id_run,
          position       => $position,
          tag_index      => $tag_index,
          username       => $username,
          modified_by    => $username});
      }
      $ent->update_outcome($new_outcome, $username);
    }

  } catch {
    $error = $_;
  };

  my $error_code = $OK_CODE;
  my $mqc_update_error;

  if ($error) {
    ($error, $error_code) = $self->parse_error($error);
  } else {
    if($ent->has_final_outcome && !$tag_index) { #If final outcome update lane as qc complete
      try {
        $c->model('NpgDB')->update_lane_manual_qc_complete($id_run, $position, $username);
      } catch {
        $mqc_update_error = qq[ Error updating lane status: $_];
      };
    }
  }

  my $message = $error || $tag_index ? qq[Manual QC $new_outcome for run $id_run, position $position, tag_index $tag_index saved.] 
                                          : qq[Manual QC $new_outcome for run $id_run, position $position saved.];
  if ($mqc_update_error) {
    $message .= $mqc_update_error;
  }

  _set_response($c, {'message' => $message}, $error_code);

  return;
}

sub get_current_outcome : Path('get_current_outcome') {
  my ($self, $c) = @_;

  my $desc;
  my $error;
  try {
    $self->_validate_req_method($c, $ALLOW_METHOD_GET);

    my $params = $c->request->parameters;
    my $position = $params->{'position'};
    my $id_run   = $params->{'id_run'};

    if (!$id_run) {
      $self->raise_error(q[Run id should be defined], $BAD_REQUEST_CODE);
    }
    if (!$position) {
      $self->raise_error(q[Position should be defined], $BAD_REQUEST_CODE);
    }

    my $ent = $c->model('NpgQcDB')->resultset('MqcOutcomeEnt')->search(
      {id_run => $id_run, position => $position})->next;
    $desc = $ent ? $ent->mqc_outcome->short_desc : q[];
  }  catch {
    my $error_code;
    ($error, $error_code) = $self->parse_error($_);
    _set_response($c, {message => qq[Error: $error] }, $error_code);
  };

  if (!$error) {
    _set_response($c, {'outcome'=> $desc });
  }

  return;
}

#For future use
sub get_all_outcomes : Path('get_all_outcomes') {
  my ($self, $c) = @_;

  my $error;
  my $id_run;
  my $positions = {};

  try {
    $self->_validate_req_method($c, $ALLOW_METHOD_GET);

    my $params = $c->request->parameters;
    $id_run   = $params->{'id_run'};
    if (!$id_run) {
      $self->raise_error(q[Run id should be defined], $BAD_REQUEST_CODE);
    }

    my $res = $c->model('NpgQcDB')->resultset('MqcOutcomeEnt')->search({id_run => $id_run},);
    while(my $ent = $res->next) {
      my $position = $ent->position;
      my $short_desc = $ent->mqc_outcome->short_desc;
      $positions->{$position} = $short_desc;
    }
  } catch {
    my $error_code;
    ($error, $error_code) = $self->parse_error($_);
     _set_response($c, {message => qq[Error: $error] }, $error_code);
  };

  if (!$error) {
    _set_response($c, {$id_run => $positions});
  }

  return;
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

npg_qc_viewer::Controller::Mqc

=head1 SYNOPSIS

=head1 DESCRIPTION

A Catalyst Controller for logging manual qc actions.

=head1 SUBROUTINES/METHODS


=head2 update_outcome

  Updates the mqc outcome using parameters from request (id_run, position, new_oc).

=head2 get_current_outcome

  Return JSON with current outcome for the paramaters from request (id_run, position).

=head2 get_all_outcomes

  Return JSON with all current outcomes for the parameter from request (id_run).

=head2 

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

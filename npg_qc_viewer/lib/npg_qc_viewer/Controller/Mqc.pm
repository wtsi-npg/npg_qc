package npg_qc_viewer::Controller::Mqc;

use Moose;
use namespace::autoclean;
use Readonly;
use English qw(-no_match_vars);
use Try::Tiny;
use JSON;

BEGIN { extends 'Catalyst::Controller' }

our $VERSION  = '0';
## no critic (ProhibitBuiltinHomonyms)

Readonly::Array our @PARAMS  => qw/status 
                                   batch_id 
                                   position
                                   lims_object_id
                                   lims_object_type
                                  /;

Readonly::Scalar our $BAD_REQUEST_CODE    => 400;
Readonly::Scalar our $INTERNAL_ERROR_CODE => 500;
Readonly::Scalar our $METHOD_NOT_ALLOWED  => 405;
Readonly::Scalar our $ALLOW_METHOD_POST   => q[POST];
Readonly::Scalar our $ALLOW_METHOD_GET    => q[GET];
Readonly::Scalar our $MQC_ROLE            => q[manual_qc];

sub _validate_req_method {
  my ($self, $c, $allowed) = @_;
  my $result = 0;
  my $request = $c->request; 
  if ($request->method ne $allowed) {
    $c->response->headers->header('ALLOW' => $allowed);
    _error($c, $METHOD_NOT_ALLOWED, qq[Manual QC action logging error: only $allowed requests are allowed.]);
  }
  return $request->method;
}

sub _validate_role {
  my ($self, $c) = @_;
  $c->controller('Root')->authorise($c, ($MQC_ROLE));
  return 1;
}

sub _validate_referer {
  my ($self, $c) = @_;
  my $referrer_url = $c->request->referer;
  if (!$referrer_url) {
    _error($c, $BAD_REQUEST_CODE,
    q[Manual QC action logging error: referrer header should be set.]);
  }
  return $referrer_url;
}

sub _validate_id_run {
  my ($self, $c) = @_;
  my $referrer_url = $c->request->referer;
  if(!$referrer_url) {
    _error($c, $INTERNAL_ERROR_CODE,
    qq{Manual QC action logging error: failed to get valid referrer url});
  }
  my ($id_run) = $referrer_url =~ m{(\d+)\z}xms;
  if (!$id_run) {
    _error($c, $INTERNAL_ERROR_CODE,
    qq{Manual QC action logging error: failed to get id_run from referrer url $referrer_url});
  }
  return $id_run;
}

sub _get_parameters {
  my ($self, $c) = @_;
  my $params = $c->request->parameters;
  return $params;
}

sub _get_params{
  my ($self, $c, $values) = @_;
  my $params = $c->request->body_parameters;
  foreach my $param (@PARAMS) {
    if ($param =~ /^batch_id|position$/smx ) {
      if($params->{$param}) {
          $values->{$param} = $params->{$param};
      }
    } else {
      if(!$params->{$param}) {
        _error($c, $BAD_REQUEST_CODE, qq[Manual QC action logging error: $param should be defined.]);
      }
      if ($param eq q[status]) {
        my $status = $params->{$param};
        if ($status !~ /^fail|pass/smx) {
          _error($c, $BAD_REQUEST_CODE,
          qq[Manual QC action logging error: invalid status $status.]);
        }
        $values->{$param} = $status =~ /^pass/smx ? 1 : 0;
      } else {
              $values->{$param} = $params->{$param};
      }
    }
  }
  return $params;
}

sub _get_values {
  my ($self, $c, $referrer_url) = @_;
  my $values = {};
  $values->{'referer'} = $referrer_url;
  $values->{'user'} = $c->user->id;
  return $values;
}

sub _error {
  my ($c, $code, $message) = @_;
  return $c->controller('Root')->detach2error($c, $code, $message);
}

####Public

sub log : Path('log') {
    my ( $self, $c ) = @_;
    my $request = $c->request;
    my $req_method = $self->_validate_req_method($c, $ALLOW_METHOD_POST);
    $self->_validate_role($c);
    my $referrer_url = $self->_validate_referer($c);
    my $id_run = $self->_validate_id_run($c);
    my $values = $self->_get_values($c, $referrer_url);    
    my $params = $self->_get_params($c, $values);

#    try {
#      $c->model('NpgDB')->update_lane_manual_qc_complete( 
#	      $id_run, $values->{'position'}, $values->{'status'}, $c->user->username
#	    );
#    } catch {
#        _error($c, $INTERNAL_ERROR_CODE, qq[Error when logging manual qc action: $_]);
#    };

    $c->response->body(q[Manual QC ] . $values->{status} . q[ for ] . $values->{lims_object_type} . q[ ] . $values->{lims_object_id} . q[ logged by NPG.]);
    return;
}

sub update_outcome : Path('update_outcome') {
  my ($self, $c) = @_;
  try {
    ####Validation
    my $req_method = $self->_validate_req_method($c, $ALLOW_METHOD_POST);
    my $validate_role = $self->_validate_role($c);
    #my $id_run = $self->_validate_id_run($c); 
    ####Loading state
    my $params = $self->_get_parameters($c);
    my $position = $params->{'position'};
    my $new_outcome = $params->{'new_oc'};
    my $id_run = $params->{'id_run'}; #TODO back to validate.
    my $username = $c->user->username;
  
    my $ent = $c->model('NpgQcDB')->resultset('MqcOutcomeEnt')->search({"id_run" => $id_run, "position" => $position})->next;
    if (!$ent) {
      $ent = $c->model('NpgQcDB')->resultset('MqcOutcomeEnt')->new_result({
        id_run         => $id_run,
        position       => $position,
        username       => $username,
        modified_by    => $username});
  
      $ent->update_outcome($new_outcome, $username);
      $c->response->headers->content_type('application/json');
      $c->response->body($ent->id_mqc_outcome);
    } else {
      $ent->update_outcome($new_outcome, $username);
      $c->response->headers->content_type('application/json');
      $c->response->body($ent->id_mqc_outcome);
    }
  } catch {
    $c->response->headers->content_type('application/json');
    my %data = ('message'=>qq[Error when logging manual qc action: $_]);
    $c->response->body(encode_json \%data);
  };  
  return;
}

sub get_current_outcome : Path('get_current_outcome') {
  my ($self, $c) = @_;
  ####Validation
  my $req_method = $self->_validate_req_method($c, $ALLOW_METHOD_GET);
  my $id_run = $self->_validate_id_run($c);
  ####Loading state
  my $params = $self->_get_parameters($c);
  my $position = $params->{'position'};
  
  my $res = $c->model('NpgQcDB')->resultset('MqcOutcomeEnt')->search({"id_run" => $id_run, "position" => $position});
  if (!$res) {
    $c->stash->{error_message} = qq[Impossible to retrieve outcome.];
    $c->detach(q[Root], q[error_page]);
    return;
  } else { 
    my $ent = $res->next;
    $c->response->headers->content_type('application/json');
    my %data = ('outcome'=>$ent->mqc_outcome->short_desc);
    $c->response->body(encode_json \%data);
  }
  return;
}

sub get_dummy_value_true : Path('dummy_true'){
  my ($self, $c) = @_;
  my $params = $self->_get_parameters($c);
  my %data = ('value'=>'true');
  $c->response->headers->content_type('application/json');
  $c->response->body(encode_json \%data);
  return;
}

sub get_dummy_value_false : Path('dummy_false'){
  my ($self, $c) = @_;
  my %data = ('value'=>'false');
  $c->response->headers->content_type('application/json');
  $c->response->body(encode_json \%data);
  return;
}

sub get_all_outcomes : Path('get_all_outcomes') {
  my ($self, $c) = @_;
  ####Validation
  my $req_method = $self->_validate_req_method($c, $ALLOW_METHOD_GET);
  my $id_run = $self->_validate_id_run($c);
  ####Loading state
  my $params = $self->_get_parameters($c);
  
  my $res = $c->model('NpgQcDB')->resultset('MqcOutcomeEnt')->search({"id_run" => $id_run},);
  my @all = ();
  while(my $ent = $res->next) {
    my $position = $ent->position;
    my $short_desc = $ent->mqc_outcome->short_desc;
    push(@all, {'position'=>$position, 'outcome'=>$short_desc});    
  }
  my %result = ('run_id'=>$id_run, 'positions'=>\@all);
  $c->response->headers->content_type('application/json');
  $c->response->body(encode_json \%result);
  return;
}

1;
__END__

=head1 NAME

npg_qc_viewer::Controller::Mqc

=head1 SYNOPSIS

=head1 DESCRIPTION

A Catalyst Controller for logging manual qc actions,

=head1 SUBROUTINES/METHODS

=head2 index - action for an index page ~/mqc

=head2 log - logging action ~/mqc/log

=head2 update_outcome - Update the mqc outcome using parameters from request (id_run, position, new_oc).

=head2 get_current_outcome - Return JSON with current outcome for the paramaters from request (id_run, position).

=head2 get_all_outcomes - Return JSON with all current outcomes for the parameter from request (id_run).

=head2 

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Readonly

=item English

=item namespace::autoclean

=item Moose

=item Catalyst::Controller

=item Try::Tiny

=item JSON

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

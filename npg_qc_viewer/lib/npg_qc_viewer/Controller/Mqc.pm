package npg_qc_viewer::Controller::Mqc;

#TODO jaime modify

use Moose;
use namespace::autoclean;
use Readonly;
use English qw(-no_match_vars);

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
  my ($id_run) = $referrer_url =~ m{(\d+)\z}xms;
  if (!$id_run) {
    _error($c, $INTERNAL_ERROR_CODE,
    qq{Manual QC action logging error: failed to get id_run from referrer url $referrer_url});
  }
  return $id_run;
}

sub log : Path('log') {
    my ( $self, $c ) = @_;
    use Test::More;
    my $request = $c->request;
    my $req_method = $self->_validate_req_method($c, $ALLOW_METHOD_POST);
    $self->_validate_role($c);
    my $referrer_url = $self->_validate_referer($c);
    my $id_run = $self->_validate_id_run($c);
    my $values = {};
    $values->{'referer'} = $referrer_url;
    $values->{'user'} = $c->user->id;

    my $params = $request->body_parameters;
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
    eval {
      $c->model('NpgDB')->log_manual_qc_action($values); #TODO This can go.
      $c->model('NpgDB')->update_lane_manual_qc_complete( #TODO This needs to stay
	    $id_run, $values->{'position'}, $values->{'status'}, $c->user->username);
      1;
    } or do {
        my $error = $EVAL_ERROR;
        _error($c, $INTERNAL_ERROR_CODE,
             qq[Error when logging manual qc action: $error]);
    };

    $c->response->body(q[Manual QC ] . $values->{status} . q[ for ] . $values->{lims_object_type} . q[ ] . $values->{lims_object_id} . q[ logged by NPG.]);
    return;
}

sub _error {
  my ($c, $code, $message) = @_;
  return $c->controller('Root')->detach2error($c, $code, $message);
}

#### Jaime

sub _create_lane() {
  return;
}

sub update_outcome :Chained('base') :PathPart('update_outcome') :Args(2) {
  my ($self, $c) = @_;
  my $row = $c->model('npg_qc::McqOutcomeEnt')->search({})->next;
    if (!$row) {
        $c->stash->{error_message} = qq[Impossible to update outcome.];
        $c->detach(q[Root], q[error_page]);
        return;
    }
  
  return;
}

sub get_current_outcome :Chained('base') :PathPart('get_current_outcome'): Args(2) {
  my ($self, $c) = @_;
  my $run_id = 1;
  my $position = 1;
  
  my $row = $c->model('npg_qc::McqOutcomeEnt')->search({})->next;
  if (!$row) {
    $c->stash->{error_message} = qq[Impossible to retrieve outcome.];
    $c->detach(q[Root], q[error_page]);
    return;
  } else { 
    
  }
  return;
}

sub get_dummy_value_true : Path('dummy_true'){
  my ($self, $c) = @_;
  return 1;
}

sub get_dummy_value_false : Path('dummy_false'){
  my ($self, $c) = @_;
  return 0;
}

sub get_all_outcomes :Chained('base') :PathPart('') Args(1) {
  my ($self, $c) = @_;
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

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Readonly

=item English

=item namespace::autoclean

=item Moose

=item Catalyst::Controller

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

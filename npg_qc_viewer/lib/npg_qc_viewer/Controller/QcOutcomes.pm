package npg_qc_viewer::Controller::QcOutcomes;

use Moose;
use namespace::autoclean;
use Try::Tiny;
use Carp;
use List::MoreUtils qw/ any /;

use npg_tracking::glossary::rpt;
use npg_tracking::glossary::composition::factory::rpt_list;
use npg_qc::Schema::Mqc::OutcomeDict;
use npg_qc::mqc::outcomes::keys qw/$LIB_OUTCOMES $SEQ_OUTCOMES $QC_OUTCOME/;
use npg_qc::mqc::outcomes;

BEGIN { extends 'Catalyst::Controller::REST'; }

our $VERSION  = '0';

__PACKAGE__->config(default => 'application/json');

##no critic (Documentation::RequirePodAtEnd NamingConventions::Capitalization)

=head1 NAME

npg_qc_viewer::Controller::QcOutcomes

=head1 SYNOPSIS

Controller for the manual QC  and user utility QC outcomes JSON service.
The service allows for retrieving, creating and updating QC outcomes.
For user utility outcomes only the retrieval part is implemented.

=head1 DESCRIPTION

Handles GET and POST requests on the /qcoutcomes URL.

Retrieving records:

  curl -X GET -H "Content-type: application/json" -H "Accept: application/json"  \
    "http://server:5050/qcoutcomes?rpt_list=5%3A8%3A7"&rpt_list=6%3A3"
  curl -H "Accept: application/json" -H "Content-type: application/json" -X POST \
    -d '{"5:8:7":{},"6:3":{}]}' http://server:5050/qcoutcomes

Updating/creating records:

  curl -H "Accept: application/json" -H "Content-type: application/json" -X POST \
    -d '{"lib":{"5:8:7":{"mqc_outcome":"Final rejected"}},"Action":"UPDATE"}' http://server:5050/qcoutcomes

=head1 SUBROUTINES/METHODS

=head2 outcomes

Handles the '/qcoutcomes' endpoint URL delegating GET and POST requests to relevant methods.

=cut

sub outcomes : Path('/qcoutcomes') : ActionClass('REST') : Args(0) {}

=head2 outcomes_GET

Handles GET requests for the '/qcoutcomes' URL. Expects 'rpt_list' parameter defined.

=cut

sub outcomes_GET {
  my ( $self, $c ) = @_;
  my $rpt_lists = $c->request->query_parameters->{'rpt_list'} || [];
  if (!ref $rpt_lists) {
    $rpt_lists = [$rpt_lists];
  }
  $self->_get_outcomes($c, $rpt_lists);
  return;
}

=head2 outcomes_POST

Handles POST requests for the '/qcoutcomes' URL. If the data part of the
request contains 'Action' key and it is set to 'UPDATE', the request is interpreted as
an UPDATE_OR_CREATE action. In all other cases the request is interpreted as GET.

JSON payload example for retrieving the data

 '{"5:8:7":{},"5:8:6":{},"6:8:7":{},"6:8:6":{}}'

The payload for updating the data has the same structure as this controller's
reply to outcomes_GET.

 '{"Action":"UPDATE","seq":{"5:8":{"mqc_outcome":"Undecided"}}}'.

An update request can contain both 'seq' and 'lib' sections, each of the
sections can contain multiple entries. See npg_qc::mqc::outcome->save() for details.

=cut

sub outcomes_POST {
  my ( $self, $c ) = @_;

  my $data = $c->request->data();
  my $action = (delete $data->{'Action'}) || q[];
  $c->log->debug($action);
  if ($action eq 'UPDATE') {
    $c->log->debug('Will call outcome update');
    $self->_update_outcomes($c, $data);
  } else {
    $c->log->debug('Will retrieve outcomes');
    $self->_get_outcomes($c, [keys %{$data}]);
  }
  return;
}

sub _get_outcomes {
  my ( $self, $c, $rpt_lists ) = @_;

  if (! @{$rpt_lists} ) {
     $self->status_bad_request(
       $c,
       'message' => 'rpt list not defined!',
     );
  } else {
     try {
       $self->status_ok($c,
         'entity' => npg_qc::mqc::outcomes
                   ->new(qc_schema => $c->model('NpgQcDB')->schema())
                   ->get($rpt_lists),
       );
     } catch {
       $self->status_bad_request(
         $c,
         'message' => $_,
       );
     };
  }

  return;
}

sub _update_outcomes {
  my ( $self, $c, $data ) = @_;

  my $error;
  my $user_info = $c->model('User')->logged_user($c);
  my $username = $user_info->{'username'};
  if (!$username) {
    $error = 'Login failed';
  } else {
    if (!$user_info->{'has_mqc_role'}) {
      $error = qq[User $username is not authorised for manual qc];
    }
  }

  # Present only in test scenario
  delete $data->{'user'};
  delete $data->{'password'};

  if ($error) {
    $self->status_forbidden($c, 'message' => $error,);
  } else {

    try {
      my $seq_outcomes = $data->{$SEQ_OUTCOMES} || {};
      my $lane_info = keys %{$seq_outcomes} ?
        $self->_lane_info($c->model('MLWarehouseDB'), $seq_outcomes) : {};

      my $outcomes = npg_qc::mqc::outcomes->new(
                       qc_schema => $c->model('NpgQcDB')->schema())
                     ->save($data, $username, $lane_info);

      $seq_outcomes = $outcomes->{$SEQ_OUTCOMES} || {};
      $self->_update_runlanes($c, $seq_outcomes, $username);

      $self->status_ok($c, 'entity' => $outcomes,);
    } catch {
      my $e = $_;
      if (ref $e eq 'DBIx::Class::Exception') {
        $e = $e->{'msg'} || q[]; # This exception class does not provide
                                 # any accessors.
      }
      $self->status_bad_request($c, 'message' => $e,);
    };
  }

  return;
}

sub _lane_info {
  my ($self, $mlwh_schema, $seq_outcomes) = @_;

  my $info = {};
  foreach my $rpt_key ( keys %{$seq_outcomes} ) {
    $info->{$rpt_key} = $mlwh_schema->tags4lane(
      npg_tracking::glossary::rpt->inflate_rpt($rpt_key));
  }

  return $info;
}

sub _update_runlanes {
  my ($self, $c, $seq_outcomes, $username) = @_;

  foreach my $key ( keys %{$seq_outcomes} ) {

    my $outcome = $seq_outcomes->{$key};
    if (!npg_qc::Schema::Mqc::OutcomeDict
          ->is_final_outcome_description($outcome->{$QC_OUTCOME})) {
      next;
    }

    my $composition = npg_tracking::glossary::composition::factory::rpt_list
                          ->new(rpt_list => $key)
                          ->create_composition();
    if ($composition->num_components > 1) {
      croak 'Run-lane status update is not implemented for multi-component compositions';
    }
    my $component = $composition->get_component(0);
    try {
      $c->model('NpgDB')->update_lane_manual_qc_complete(
        $component->id_run, $component->position, $username);
    } catch {
      $c->log->warn(qq[Error updating lane status for rpt key '$key': $_]);
    };
  }

  return;
}


__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item Catalyst::Controller::REST

=item Try::Tiny

=item Carp

=item List::MoreUtils

=item npg_tracking::glossary::rpt

=item npg_tracking::glossary::composition::factory::rpt_list

=item npg_qc::mqc::outcomes

=item npg_qc::Schema::Mqc::OutcomeDict

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2017 Genome Research Ltd.

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

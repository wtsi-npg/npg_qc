package npg_qc_viewer::Controller::QcOutcomes;

use Moose;
use namespace::autoclean;
use Try::Tiny;
use Carp;
use List::MoreUtils qw/ any /;

use npg_tracking::glossary::rpt;
use npg_qc_viewer::Util::CompositionFactory;
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

Controller for the QC outcomes JSON service. The service allows for
retrieving, creating and updating QC outcomes.

=head1 DESCRIPTION

Handles GET and post requests on the /qcoutcomes URL.

Retrieving records:

  curl -X GET -H "Content-type: application/json" -H "Accept: application/json"  \
    "http://server:5050/qcoutcomes?rpt_list=5%3A8%3A7"&rpt_list=6%3A3"
  curl -H "Accept: application/json" -H "Content-type: application/json" -X POST \
    -d '{"rpt_list":["5:8:7","6:3"]}' http://server:5050/qcoutcomes

Updating/creating records:

  curl -H "Accept: application/json" -H "Content-type: application/json" -X POST \
    -d '{"lib":{"5:8:7":{"qc_outcome":"Final Rejected"}},"Action":"UPDATE"}' http://server:5050/qcoutcomes 

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

The UPDATE action has not yet been implemented.

=cut

sub outcomes_POST {
  my ( $self, $c ) = @_;

  my $data = $c->request->data();
  my $action = (delete $data->{'Action'}) || q[];
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
       my $obj = npg_qc::mqc::outcomes->new(qc_schema => $c->model('NpgQcDB')->schema());
       my @qlist = map { _inflate_rpt($_) } @{$rpt_lists};
       $self->status_ok($c,
         'entity' => $obj->get(\@qlist),
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

sub _inflate_rpt {
  my $rpt = shift;

  my $comp = npg_qc_viewer::Util::CompositionFactory->new(rpt_list => $rpt)
             ->create_composition();
  if ($comp->num_components > 1) {
    croak 'Cannot deal with multi-component compositions';
  }
  # TODO in tracking - create a public method
  return $comp->components->[0]->_pack_custom();
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

  if ($error) {
    $self->status_forbidden($c, 'message' => $error,);
    return;
  }

  try {
    my $query     = $self->_format_outcomes($data);
    my $lane_info = $self->_lane_info($c, $query);
    my $response  = npg_qc::mqc::outcomes->new(
      qc_schema => $c->model('NpgQcDB')->schema())->save($query, $username, $lane_info);
    foreach my $key (keys %{$lane_info}) {
      my $ids = npg_tracking::glossary::rpt->inflate_rpt($key);
      try {
        $c->model('NpgDB')->update_lane_manual_qc_complete(
          $ids->{'id_run'}, $ids->{'position'}, $username);
      } catch {
        carp qq[Error updating lane status for rpt key '$key': $_];
      };
    }
    $self->status_ok($c, 'entity' => $response,);
  } catch {
    $self->status_bad_request($c, 'message' => $_,);
  };

  return;
}

sub _format_outcomes {
  my ($self, $data) = @_;

  my $query = {};
  my $count = 0;
  foreach my $outcome_type ( ($LIB_OUTCOMES, $SEQ_OUTCOMES) ) {
    my $outcomes = $data->{$outcome_type} || [];
    my $keys = {};
    foreach my $o ( @{$outcomes} ) {
      $count++;
      my ($rpt_key, $outcome) = each %{$o};
      if (exists $keys->{$rpt_key}) {
        croak qq[Duplicate entries for rpt key '$rpt_key'];
      }
      $keys->{$rpt_key} = 1;
      my $q = _inflate_rpt($rpt_key);
      $q->{$QC_OUTCOME} = $outcome->{$QC_OUTCOME} ||
        croak qq[Outcome description is missing for rpt key '$rpt_key'];
      push @{$query->{$outcome_type}}, {$rpt_key => $q};
    }
  }

  if ($count == 0) {
    croak 'No data sent';
  }

  return $query;
}

sub _lane_info {
  my ($self, $c, $query) = @_;

  my $info = {};
  foreach my $o ( @{$query->{$SEQ_OUTCOMES}} ) {
    my ($rpt_key, $outcome) = each %{$o};
    my %q = %{$outcome};
    my $outcome_desc = delete $q{$QC_OUTCOME};
    if (npg_qc::Schema::Mqc::OutcomeDict->is_final_outcome_description($outcome_desc)) {
      $info->{$rpt_key} = $c->model('MLWarehouseDB')->tags4lane(\%q);
    }
  }

  return $info;
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

=item npg_qc::mqc::outcomes

=item npg_qc::Schema::Mqc::OutcomeDict

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2016 Genome Research Ltd.

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

package npg_qc::Schema::ResultSet::MqcOutcomeEnt;

use Moose;
use namespace::autoclean;
use MooseX::NonMoose;
use Carp;

extends 'DBIx::Class::ResultSet';

our $VERSION = '0';

sub BUILDARGS {
  my ($class, $rsrc, $args) = @_;
  return $args;
} # ::RS::new() expects my ($class, $rsrc, $args) = @_

sub get_not_reported {
  my $self = shift;
  return $self->search({$self->current_source_alias . '.reported' => undef});
}

sub get_rows_with_final_current_outcome {
  my $self = shift;
  #Final outcome comes from the short_desc of the relationship with the dictionary, only those with current status
  return $self->search({'mqc_outcome.short_desc' => {like => '%final'}, 'mqc_outcome.iscurrent' => 1}, {'join'=>'mqc_outcome'});
}

sub get_ready_to_report{
  my $self = shift;
  return $self->get_not_reported->get_rows_with_final_current_outcome;
}

sub get_outcomes_as_hash{
  my ($self, $id_run) = @_;

  #Loading previuos status qc for tracking and mqc.
  my $previous_mqc = {};
  my $previous_rs = $self->search({'id_run'=>$id_run});
  while (my $obj = $previous_rs->next) {
    $previous_mqc->{$obj->position} = $obj->mqc_outcome->short_desc;
  }
  return $previous_mqc;
}

sub search_outcome_ent {
  my ( $self, $id_run, $position, $username ) = @_;
  my $ent;
  my $values = {};
  $values->{'id_run'}   = $id_run;
  $values->{'position'} = $position;
  $ent = $self->search($values)->next;
  if (!$ent) {
    $values->{'username'}    = $username;
    $values->{'modified_by'} = $username;
    $ent = $self->new_result($values);
  }
  return $ent;
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

npg_qc::Schema::ResultSet::MqcOutcomeEnt

=head1 SYNOPSIS

=head1 DESCRIPTION

Extended ResultSet with specific functionality for for manual MQC.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 SUBROUTINES/METHODS

=head2 BUILDARGS

  Calling parent constructor.

=head2 get_not_reported

  Returns a list of entities with a null reported timestamp.

=head2 get_rows_with_final_current_outcome

  Returns a list of entities with final outcomes acording to business rules. Currently it looks into the relationship with the dictionary to find those outcomes with a short description ending in 'final'.

=head2 get_ready_to_report

  Returns a list of MqcOutcomeEnt rows which are ready to be reported (have a final status but haven't been reported yet and which have an outcome marked as current in the dictionary).

=head2 get_outcomes_as_hash

  Returns a hash of lane=>outcome for those lanes in the database for the id_run specified.

=head2 search_outcome_ent

  Find previous mqc outcome for the id_run/position, create
  it for the specified user if it does not exist.

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item Moose

=item namespace::autoclean

=item MooseX::NonMoose

=item DBIx::Class::ResultSet

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Jaime Tovar <lt>jmtc@sanger.ac.uk<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 GRL Genome Research Limited

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


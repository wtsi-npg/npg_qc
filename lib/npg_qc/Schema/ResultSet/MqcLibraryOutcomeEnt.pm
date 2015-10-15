package npg_qc::Schema::ResultSet::MqcLibraryOutcomeEnt;

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

sub get_outcomes_as_hash{
  my ($self, $id_run, $position) = @_;

  if(!defined $id_run) {
    croak q[Mandatory parameter 'id_run' missing in call];
  }
  if(!defined $position) {
    croak q[Mandatory parameter 'position' missing in call];
  }
  #Loading previuos status qc for tracking and mqc.
  my $previous_mqc = {};
  my $previous_rs = $self->search({
    'id_run'   => $id_run,
    'position' => $position
  });
  while (my $obj = $previous_rs->next) {
    $previous_mqc->{$obj->tag_index} = $obj->mqc_outcome->short_desc; #TODO tag_index = undef?
  }
  return $previous_mqc;
}

sub search_library_outcome_ent {
  my ( $self, $id_run, $position, $tag_index, $username ) = @_;

  if(!defined $id_run) {
    croak q[Mandatory parameter 'id_run' missing in call];
  }
  if(!defined $position) {
    croak q[Mandatory parameter 'position' missing in call];
  }
  if(!defined $username) {
    croak q[Mandatory parameter 'username' missing in call];
  }
  my $values = {};
  $values->{'id_run'}    = $id_run;
  $values->{'position'}  = $position;
  $values->{'tag_index'} = $tag_index; #TODO tag_index = undef?
  $self->result_class->deflate_unique_key_components($values);
  my $ent = $self->search($values)->next;
  if (!$ent) {
    #TODO Check if I should send tag_index back to undef
    $values->{'username'}    = $username;
    $values->{'modified_by'} = $username;
    $ent = $self->new_result($values);
  }
  return $ent;
}

sub fetch_mqc_library_outcomes {
  my ($self, $id_run, $position) = @_;

  if(!defined $id_run) {
    croak q[Mandatory parameter 'id_run' missing in call];
  }
  if(!defined $position) {
    croak q[Mandatory parameter 'position' missing in call];
  }

  my $rs1 = $self->search({
    'id_run' => $id_run,
    'position' => $position,
  });
  return $rs1;
}

sub batch_update_libraries {
  my ($self, $lane_ent, $tag_indexes_in_lims, $username) = @_;

  foreach my $tag_index (@{$tag_indexes_in_lims}) {
    my $library_ent = $self->search_library_outcome_ent($lane_ent->id_run, $lane_ent->position, $tag_index, $username);
    my $new_outcome = q[Undecided];
    if ($library_ent->in_storage) {
      if($library_ent->mqc_outcome->short_desc eq q[Accepted preliminary]) {
        $new_outcome = q[Accepted final];
      } elsif ($library_ent->mqc_outcome->short_desc eq q[Rejected preliminary]) {
        $new_outcome = q[Rejected final];
      }
    }
    $library_ent->update_outcome($new_outcome, $username);
  }

  return 1;
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

npg_qc::Schema::ResultSet::MqcLibraryOutcomeEnt

=head1 SYNOPSIS

=head1 DESCRIPTION

Extended ResultSet with specific functionality for for manual MQC.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 SUBROUTINES/METHODS

=head2 BUILDARGS

  Calling parent constructor.

=head2 get_outcomes_as_hash

  Returns a hash of plex=>outcome for those plexes in the database for the id_run/position specified.

=head2 search_library_outcome_ent

  Find previous mqc outcome for the id_run/position/tag_index,
  create it for the specified user if it does not exist.

=head2 fetch_mqc_library_outcomes

  Returns a resultset with mqc library outcome entity for id_run, position
  passed as parameters

=head2 batch_update_libraries

  Iterates on the list of tag_indexes provided to update outcomes to final for
  the library outcome entities related to the lane entity passed as parameter.

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


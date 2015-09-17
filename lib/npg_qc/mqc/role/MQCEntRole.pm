package npg_qc::mqc::role::MQCEntRole;

use strict;
use warnings;
use Carp;

our $VERSION = '0';

use Moose::Role;

requires 'short_desc';
requires 'mqc_outcome';
requires 'update';
requires 'insert';
requires 'data_for_historic';
requires 'historic_resultset';

around 'update' => sub {
  my $orig = shift;
  my $self = shift;
  $self->last_modified($self->get_time_now);
  my $return_super = $self->$orig(@_);

  $self->_create_historic();
  return $return_super;
};

around 'insert' => sub {
  my $orig = shift;
  my $self = shift;
  $self->last_modified($self->get_time_now);
  my $return_super = $self->$orig(@_);

  $self->_create_historic();
  return $return_super;
};

sub update_outcome {
  my ($self, $outcome, $username) = @_;

  #Validation
  if(!defined $outcome){
    croak q[Mandatory parameter 'outcome' missing in call];
  }
  if(!defined $username){
    croak q[Mandatory parameter 'username' missing in call];
  }
  if ($username =~ /^\d+$/smx) {
    croak "Have a number $username instead as username";
  }
  my $outcome_dict_obj = $self->_valid_outcome($outcome);
  if($outcome_dict_obj) { # The new outcome is a valid one
    my $outcome_id = $outcome_dict_obj->id_mqc_outcome;
    #There is a row that matches the id_run and position
    if ($self->in_storage) {
      #Check if previous outcome is not final
      if($self->mqc_outcome->is_final_outcome) {
        croak(sprintf 'Error while trying to update a final outcome for %s',
              $self->short_desc);
      } else { #Update
        $self->update({'id_mqc_outcome' => $outcome_id, 'username' => $username, 'modified_by' => $username});
      }
    } else { #Is a new row just insert.
      $self->id_mqc_outcome($outcome_id);
      $self->username($username);
      $self->modified_by($username);
      $self->insert();
    }
  } else {
    croak(sprintf 'Error while trying to transit %s to a non-existing outcome "%s".',
          $self->short_desc, $outcome);
  }
  return 1;
}

sub has_final_outcome {
  my $self = shift;
  return $self->mqc_outcome->is_final_outcome;
}

sub is_accepted {
  my $self = shift;
  return $self->mqc_outcome->is_accepted;
}

sub is_final_accepted {
  my $self = shift;
  return $self->mqc_outcome->is_final_accepted;
}

sub is_undecided {
  my $self = shift;
  return $self->mqc_outcome->is_undecided;
}

#Create and save historic from the entity current data.
sub _create_historic {
  my $self = shift;
  my $rs = $self->result_source->schema->resultset($self->historic_resultset);
  my $historic = $rs->create($self->data_for_historic);
  return 1;
}

#Fetches valid outcome object from the database.
sub _valid_outcome {
  my ($self, $outcome) = @_;

  my $rs = $self->result_source->schema->resultset('MqcOutcomeDict');
  my $outcome_dict;
  if ($outcome =~ /\d+/xms) {
    $outcome_dict = $rs->find($outcome);
  } else {
    $outcome_dict = $rs->search({short_desc => $outcome})->next;
  }
  if ((defined $outcome_dict) && $outcome_dict->iscurrent) {
    return $outcome_dict;
  }
  return;
}

no Moose;

1;

__END__


=head1 NAME

  npg_qc::mqc::role::MQCEntRole

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SUBROUTINES/METHODS

=head2 update_outcome

  Updates the outcome of the entity with values provided.

  $obj->($outcome, $username)

=head2 has_final_outcome

  Returns true id this entry corresponds to a final outcome, otherwise returns false.
  
=head2 is_accepted

  Returns the result of checking if the outcome is considered accepted. Delegates the 
  check to L<npg_qc::Schema::Result::MqcOutcomeDict>
  
=head2 is_final_accepted

  Returns the result of checking if the outcome is considered final and accepted. 
  Delegates the check to L<npg_qc::Schema::Result::MqcOutcomeDict>

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Jaime Tovar <lt>jmtc@sanger.ac.uk<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 Genome Research Ltd

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
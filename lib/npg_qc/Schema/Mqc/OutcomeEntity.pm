package npg_qc::Schema::Mqc::OutcomeEntity;

use Moose::Role;
use DateTime;
use DateTime::TimeZone;
use Carp;
use Readonly;

our $VERSION = '0';

requires 'mqc_outcome';
requires 'update';
requires 'insert';

Readonly::Scalar my $MQC_LIB_LIMIT => 400;
Readonly::Scalar my $ACCEPTED_FINAL  => 'Accepted final';
Readonly::Scalar my $REJECTED_FINAL  => 'Rejected final';
Readonly::Scalar my $UNDECIDED_FINAL => 'Undecided final';

Readonly::Hash my %DELEGATION_TO_MQC_OUTCOME => {
  'has_final_outcome' => 'is_final_outcome',
  'is_accepted'       => 'is_accepted',
  'is_final_accepted' => 'is_final_accepted',
  'is_undecided'      => 'is_undecided',
  'is_rejected'       => 'is_rejected',
};

foreach my $this_class_method (keys %DELEGATION_TO_MQC_OUTCOME ) {
  __PACKAGE__->meta->add_method( $this_class_method, sub {
      my $self = shift;
      my $that_class_method = $DELEGATION_TO_MQC_OUTCOME{$this_class_method};
      return $self->mqc_outcome->$that_class_method;
    }
  );
}

around [qw/update insert/] => sub {
  my $orig = shift;
  my $self = shift;
  $self->last_modified($self->get_time_now);
  my $return_super = $self->$orig(@_);
  $self->_create_historic();
  return $return_super;
};

sub get_time_now {
  return DateTime->now(time_zone => DateTime::TimeZone->new(name => q[local]));
}

sub mqc_lib_limit {
  return $MQC_LIB_LIMIT;
}

sub data_for_historic {
  my $self = shift;
  my %my_cols = $self->get_columns;
  my @hist_cols = $self->result_source
                       ->schema
                       ->source($self->_rs_name('Hist'))
                       ->columns;
  my $vals = {};
  foreach my $x (@hist_cols) {
    if ( exists $my_cols{$x} ) {
      $vals->{$x} = $my_cols{$x};
    }
  }
  return $vals;
}

sub validate_username {
  my ( $self, $username ) = @_;

  if(!defined $username){
    croak q[Mandatory parameter 'username' missing in call];
  }
  if ($username =~ /^\d+$/smx) {
    croak "Have a number $username instead as username";
  }
  return;
}

sub _rs_name {
  my ($self, $suffix) = @_;
  if (!$suffix) {
    croak 'Suffix undefined';
  }
  my $class = ref $self;
  ($class) = $class =~ /([^:]+)Ent\Z/smx;
  return $class . $suffix;
}

sub _create_historic {
  my $self = shift;
  $self->result_source
       ->schema
       ->resultset($self->_rs_name('Hist'))
       ->create($self->data_for_historic);
  return;
}

sub find_valid_outcome {
  my ($self, $outcome) = @_;

  my $rs = $self->result_source
                ->schema
                ->resultset($self->_rs_name('Dict'));
  my $outcome_dict;
  if ($outcome =~ /\d+/xms) {
    $outcome_dict = $rs->find($outcome);
  } else {
    $outcome_dict = $rs->search({
      short_desc => $outcome
    })->next;
  }
  if (!defined $outcome_dict || !$outcome_dict->iscurrent) {
    croak("Outcome $outcome is invalid");
  }
  return $outcome_dict;
}

sub update_to_final_outcome {
  my ($self, $username) = @_;

  my $new_outcome;
  my $class = ref $self;
  my $is_mqc_library = $class =~ /Library/smx;

  if( $self->is_accepted ) {
    $new_outcome = $ACCEPTED_FINAL;
  } elsif ( $self->is_rejected ) {
    $new_outcome = $REJECTED_FINAL;
  } elsif ( $is_mqc_library && $self->is_undecided ) {
    $new_outcome = $UNDECIDED_FINAL;
  } else {
    croak sprintf 'Unable to update unexpected outcome to final for id_run %i position %i%s.',
      $self->id_run,
      $self->position,
      $is_mqc_library ? ' tag_index ' . ( $self->tag_index ? $self->tag_index : q[undef] ) : q[];
  }

  return $self->update_nonfinal_outcome($new_outcome, $username);
}

sub toggle_final_outcome {
  my ($self, $modified_by, $username) = @_;

  if (!$self->in_storage) {
    croak 'Record is not stored in the database yet';
  }
  if (!$self->has_final_outcome) {
    croak 'Cannot toggle non-final outcome ' . $self->mqc_outcome->short_desc;
  }
  if ($self->is_undecided) {
    croak 'Cannot toggle undecided final outcome';
  }

  my $new_outcome = $self->is_accepted ? $REJECTED_FINAL : $ACCEPTED_FINAL;
  return $self->update_outcome($new_outcome, $modified_by, $username);
}

sub update_nonfinal_outcome {
  my ($self, $outcome, $modified_by, $username) = @_;
  if ($self->in_storage && $self->has_final_outcome) {
    croak('Outcome is already final, cannot update');
  }
  return $self->update_outcome($outcome, $modified_by, $username);
}

sub update_outcome {
  my ($self, $outcome, $modified_by, $username) = @_;

  if( !defined $outcome ) {
    croak q[Mandatory parameter 'outcome' missing in call];
  }

  $username ||= $modified_by;
  $self->validate_username($modified_by);
  my $outcome_dict_obj = $self->find_valid_outcome($outcome);
  my $outcome_id = $outcome_dict_obj->pk_value;

  my $values = {};
  $values->{'id_mqc_outcome'} = $outcome_id;
  $values->{'username'}       = $username;
  $values->{'modified_by'}    = $modified_by;

  if ($self->in_storage) {
    $self->update($values);
  } else {
    while ( my ($column, $value) = each %{$values} ) {
      $self->$column($value);
    }
    $self->insert();
  }

  return;
}

no Moose::Role;

1;

__END__


=head1 NAME

  npg_qc::Schema::Mqc::OutcomeEntity

=head1 SYNOPSIS

  package OutcomeEntity;
  with 'npg_qc::Schema::Mqc::OutcomeEntity';

=head1 DESCRIPTION

  Common functionality for lane and library manual qc outcome entity DBIx objects.

=head1 SUBROUTINES/METHODS

=head2 update

  The default method is extended to create a relevant historic record and set
  correct local time.

=head2 insert

  The default method is extended to create a relevant historic record and set
  correct local time.

=head2 get_time_now

  Returns a localised DateTime object representing time now.

=head2 mqc_lib_limit

  Returns a maximum number of plexes in a lane that can be subject to
  library manula qc.

=head2 data_for_historic

  Looks at the entity columns and the matching historic metadata to
  find those columns which intersect and copies from entity to a new
  hash intersecting values.

=head2 validate_username

  Checks that the username is alphanumeric. Other numeric values are not allowed.

=head2 has_final_outcome

  Returns true if this entry corresponds to a final outcome, otherwise returns false.

=head2 is_accepted

  Returns true if the outcome is accepted (pass), otherwise returns false.

=head2 is_final_accepted

  Returns true if the outcome is accepted (pass) and final, otherwise returns false.

=head2 is_undecided

  Returns true if the outcome is undecided (neither pass nor fail),
  otherwise returns false.

=head2 find_valid_outcome

  Returns a valid current Dictionary object that matches the outcome or
  raises an error.

  my $dict_obj = $obj->find_valid_outcome('Accepted preeliminary');
  my $dict_obj = $obj->find_valid_outcome(1);

=head2 update_to_final_outcome

  Checks the current outcome for this entity and tries to define a corresponding
  final outcome. If there is one, it will delegate the update to update_nonfinal_outcome
  using the final outcome as new outcome for the entity.

  Needs the username of who is requesting the change.

  $obj->update_to_final_outcome($username);

=head2 update_nonfinal_outcome

  Updates the outcome of the entity with values provided. Stores a new row
  if this entity was not yet stored in database.

  If the outcome current outcome of the object is final and it is already
  stored in the database, an error is raised.

  Recommended to be used by the SeqQC application,

  $obj->update_nonfinal_outcome($outcome, $username);
  $obj->update_nonfinal_outcome($outcome, $username, $rt_ticket);

=head2 update_outcome

  Updates the outcome of the entity with values provided. Stores a new row
  if this entity was not yet stored in database.

  $obj->update_outcome($outcome, $username);
  $obj->update_outcome($outcome, $username, $rt_ticket);

=head2 toggle_final_outcome

  Updates the final accepted or rejected outcome to its opposite final outcome,
  i.e. accepted is changed to rejected and rejected to accepted.

  $obj->toggle_final_outcome($username);
  $obj->toggle_final_outcome($username, $rt_ticket);

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item DateTime

=item DateTime::TimeZone

=item Readonly

=item Carp

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

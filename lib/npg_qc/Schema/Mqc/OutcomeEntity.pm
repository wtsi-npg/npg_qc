package npg_qc::Schema::Mqc::OutcomeEntity;

use Moose::Role;
use DateTime;
use DateTime::TimeZone;
use List::MoreUtils qw/any/;
use Carp;
use Readonly;

with 'npg_qc::Schema::Composition';

our $VERSION = '0';

requires qw/ update
             insert /;

Readonly::Scalar my $ACCEPTED_FINAL  => 'Accepted final';
Readonly::Scalar my $REJECTED_FINAL  => 'Rejected final';

sub add_common_ent_methods {
  my $package_name = shift;

  if (ref $package_name) {
    croak 'add_common_ent_methods is a class method, ' .
          'cannot be called on an object instance';
  }

  Readonly::Hash my   %DELEGATION_TO_QC_OUTCOME  => {
    'has_final_outcome' => 'is_final_outcome',
    'is_accepted'       => 'is_accepted',
    'is_final_accepted' => 'is_final_accepted',
    'is_undecided'      => 'is_undecided',
    'is_rejected'       => 'is_rejected',
    'description'       => 'short_desc',
  };
  Readonly::Scalar my $DICT_REL_NAME_METHOD_NAME => 'dict_rel_name';

  my @delegated = keys %DELEGATION_TO_QC_OUTCOME;
  if (any {$package_name->can($_)} (@delegated, $DICT_REL_NAME_METHOD_NAME)) {
    croak 'One of the methods is already defined';
  }

  my ($dict_rel_name) = $package_name =~ /::([[:alpha:]]+qc)(?:Library)?OutcomeEnt\Z/smx;
  if (!$dict_rel_name) {
    croak "Failed to derive dictionary relationship name from $package_name";
  }
  $dict_rel_name = lc $dict_rel_name .'_outcome';
  $package_name->meta->add_method($DICT_REL_NAME_METHOD_NAME,
                                  sub {return $dict_rel_name;});

  foreach my $this_class_method (@delegated ) {
    $package_name->meta->add_method( $this_class_method, sub {
        my $self = shift;
        my $that_class_method = $DELEGATION_TO_QC_OUTCOME{$this_class_method};
        return $self->$dict_rel_name->$that_class_method(@_);
      }
    );
  }

  return;
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
  return $self->update_outcome({'mqc_outcome' => $new_outcome}, $modified_by, $username);
}

sub valid4update {
  my ($self, $new_data) = @_;

  if (!$new_data || ref $new_data ne 'HASH') {
    croak q[Outcome hash is required];
  }
  my $outcome_desc = $new_data->{$self->dict_rel_name()};
  if (!$outcome_desc) {
    croak 'Outcome description is missing';
  }
  if ($self->in_storage) {
    if ($self->description() eq $outcome_desc) {
      return 0;
    } elsif ($self->has_final_outcome()) {
      croak q[Final outcome cannot be updated];
    }
  }

  return 1;
}

sub update_outcome {
  my ($self, $outcome, $modified_by, $username) = @_;

  if (!$outcome || ref $outcome ne 'HASH') {
    croak q[Outcome hash is required];
  }
  if (!$modified_by) {
    croak q[User name required];
  }

  my $dict_rel_name = $self->dict_rel_name();
  my %values = %{$outcome};
  $values{'id_' . $dict_rel_name} =
    $self->_outcome_id(delete $values{$dict_rel_name});
  $values{'username'}    = $username || $modified_by;
  $values{'modified_by'} = $modified_by;

  if ($self->in_storage) {
    $self->update(\%values);
  } else {
    while ( my ($column, $value) = each %values ) {
      $self->$column($value);
    }
    $self->insert();
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

sub _outcome_id {
  my ($self, $outcome) = @_;

  if (!$outcome) {
    croak q[Outcome required];
  }
  my $outcome_dict_obj = $self->result_source
                         ->schema
                         ->resultset($self->_rs_name('Dict'))
                         ->find({'short_desc' => $outcome});
  if (!$outcome_dict_obj || !$outcome_dict_obj->iscurrent) {
    croak qq[Outcome $outcome is invalid];
  }

  return $outcome_dict_obj->pk_value;
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

Common functionality for outcomes entity DBIx objects.

=head1 SUBROUTINES/METHODS

=head2 add_common_ent_methods

Dynamically adds a number of common methods to a class that consumes this role.
Should be called as a class a class method. Can be called once only.
The following methods are added: dict_rel_name, has_final_outcome, is_accepted,
is_final_accepted, is_undecided, is_rejected, description.

  $this_package->add_common_methods();
  __PACKAGE_->add_common_methods();

=head2 composition

A lazy-build attribute of type npg_tracking::glossary::composition.
It is built by inspecting the linked seq_composition row.

=head2 update

The default method is extended to create a relevant historic record and set
correct local time.

=head2 insert

The default method is extended to create a relevant historic record and set
correct local time.

=head2 get_time_now

Returns a localised DateTime object representing time now.

=head2 data_for_historic

Looks at the entity columns and the matching historic metadata to
find those columns which intersect and copies from entity to a new
hash intersecting values.

=head2 valid4update

Returns true if the outcome can be updated, false if it cannot be updated.
Error if the current outcome is final.

=head2 update_outcome

Updates the outcome of the entity with values provided. Stores a new row
if this entity was not yet stored in database. This method has not been yet
extended to updating utility outcomes.

The first argument is a hash reference with key-value pairs for some of
the columns to be updated, the second argument is username of the user who
is performing the action (logged-in user) and the third (optional) argument
is the username of the user who makes the decision or a reference to a source
(for example, RT ticket) that has a record about a decision. The latter
is important when a final decision is changed. 

  $obj->update_outcome({'mqc_outcome' => $outcome}, $username);
  $obj->update_outcome({'mqc_outcome' => $outcome}, $username, $rt_ticket);

=head2 toggle_final_outcome

Updates the final accepted or rejected outcome to its opposite final outcome,
i.e. accepted is changed to rejected and rejected to accepted. This method is
not applicable to utility qc outcomes since there is no concept of final
for this type of outcome.

  $obj->toggle_final_outcome($username);
  $obj->toggle_final_outcome($username, $rt_ticket);

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item DateTime

=item DateTime::TimeZone

=item List::MoreUtils

=item Readonly

=item Carp

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Jaime Tovar <lt>jmtc@sanger.ac.uk<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018 Genome Research Ltd

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

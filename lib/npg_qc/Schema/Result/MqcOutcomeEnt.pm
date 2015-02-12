
package npg_qc::Schema::Result::MqcOutcomeEnt;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

##no critic(RequirePodAtEnd RequirePodLinksIncludeText ProhibitMagicNumbers ProhibitEmptyQuotes)

=head1 NAME

npg_qc::Schema::Result::MqcOutcomeEnt

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=item * L<DBIx::Class::InflateColumn::Serializer>

=back

=cut

__PACKAGE__->load_components('InflateColumn::DateTime', 'InflateColumn::Serializer');

=head1 TABLE: C<mqc_outcome_ent>

=cut

__PACKAGE__->table('mqc_outcome_ent');

=head1 ACCESSORS

=head2 id_mqc_outcome_ent

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 id_run

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 position

  data_type: 'tinyint'
  extra: {unsigned => 1}
  is_nullable: 0

Lane

=head2 id_mqc_outcome

  data_type: 'smallint'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 username

  data_type: 'char'
  is_nullable: 1
  size: 128

=head2 last_modified

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

=head2 reported

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  is_nullable: 1

When was reported to LIMS

=cut

__PACKAGE__->add_columns(
  'id_mqc_outcome_ent',
  {
    data_type => 'bigint',
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  'id_run',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 0 },
  'position',
  { data_type => 'tinyint', extra => { unsigned => 1 }, is_nullable => 0 },
  'id_mqc_outcome',
  {
    data_type => 'smallint',
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  'username',
  { data_type => 'char', is_nullable => 1, size => 128 },
  'last_modified',
  {
    data_type => 'timestamp',
    datetime_undef_if_invalid => 1,
    default_value => \'current_timestamp',
    is_nullable => 0,
  },
  'reported',
  {
    data_type => 'timestamp',
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_mqc_outcome_ent>

=back

=cut

__PACKAGE__->set_primary_key('id_mqc_outcome_ent');

=head1 UNIQUE CONSTRAINTS

=head2 C<id_run_UNIQUE>

=over 4

=item * L</id_run>

=item * L</position>

=back

=cut

__PACKAGE__->add_unique_constraint('id_run_UNIQUE', ['id_run', 'position']);

=head1 RELATIONS


=head2 mqc_outcome

Type: belongs_to

Related object: L<npg_qc::Schema::Result::MqcOutcomeDict>

=cut

__PACKAGE__->belongs_to(
  'mqc_outcome',
  'npg_qc::Schema::Result::MqcOutcomeDict',
  { id_mqc_outcome => 'id_mqc_outcome' },
  { is_deferrable => 1, on_delete => 'NO ACTION', on_update => 'NO ACTION' },
);


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2015-02-09 11:21:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:7UWlCHPyTLNXd2cG6VlR0w

our $VERSION = '0';

use MooseX::Params::Validate;
use Carp;

#Create and saver historic from the entity current data.
sub _create_historic {
  my $self = shift;
  my $rs = $self->result_source->schema->resultset('MqcOutcomeHist');
  my $historic = $rs->create({id_run => $self->id_run,
    position => $self->position,
    id_mqc_outcome => $self->id_mqc_outcome,
    username => $self->username,
    last_modified => $self->last_modified});

  return 1;
}

#Updates and inserts an historic
around 'update' => sub {
  my $orig = shift;
  my $self = shift;
  my $return_super = $self->$orig(@_);

  $self->_create_historic();
  return $return_super;
};

#Inserts and inserts an historic
around 'insert' => sub {
  my $orig = shift;
  my $self = shift;
  my $return_super = $self->$orig(@_);

  $self->_create_historic();
  return $return_super;
};

sub update_outcome {
  my @parameters = @_;

  my ( $self, %params ) = validated_hash(
    \@parameters,
    'outcome'  => {is_a => 'Int'},
    'username' => {is_a => 'Str'}
  );

  if($self->_is_valid_outcome('outcome' => $params{'outcome'})) { # The new outcome is a valid one
    #There is a row that matches the id_run and position
    if ($self->in_storage) {
      #Check if previous outcome is not final
      if($self->mqc_outcome->is_final_outcome) {
        #Trying an invalid transition, throw exception
        croak('Error while trying to update a final outcome.');
      } else { #Update
        $self->update({'id_mqc_outcome' => $params{'outcome'}, 'username' => $params{'username'}});
      }
    } else { #Is a new row just insert.      
      $self->id_mqc_outcome($params{outcome});
      $self->user($params{username});
      $self->insert();
    }
  } else {
    croak('Error while trying to transit to a non-existing outcome.');
  }
  return 1;
}

#As a proxy to the dictionary method
sub has_final_outcome {
  my $self = shift;

  if(!$self->mqc_outcome->is_final_outcome) {
    return 0;
  }
  return 1;
}

#Check if an outcome actually exists in the database.
sub _is_valid_outcome {
  my @parameters = @_;

  my ( $self, %params ) = validated_hash(
    \@parameters,
    'outcome'  => {is_a => 'Int'}
  );

  my $outcome_dict = $self->result_source->schema->resultset('MqcOutcomeDict')->find($params{outcome});
  return defined $outcome_dict;
}

__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 SYNOPSIS

=head1 DESCRIPTION

Catalog for manual MQC statuses.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 SUBROUTINES/METHODS

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item Moose

=item MooseX::NonMoose

=item MooseX::MarkAsMethods

=item DBIx::Class::Core

=item DBIx::Class::InflateColumn::DateTime

=item DBIx::Class::InflateColumn::Serializer

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Jaime Tovar <lt>jmtc@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 GRL, by Jaime Tovar

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


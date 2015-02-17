
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


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2015-02-13 15:54:50
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:IeVPqo19e5AiSNHxD0cTTQ

our $VERSION = '0';

use Carp;
use DateTime;
use DateTime::TimeZone;

sub _get_time_now {
  return DateTime->now(time_zone=> DateTime::TimeZone->new(name => q[local]));
}

around 'update' => sub {
  my $orig = shift;
  my $self = shift;
  $self->last_modified($self->_get_time_now);
  my $return_super = $self->$orig(@_);

  $self->_create_historic();
  return $return_super;
};

around 'insert' => sub {
  my $orig = shift;
  my $self = shift;
  $self->last_modified($self->_get_time_now);
  my $return_super = $self->$orig(@_);

  $self->_create_historic();
  return $return_super;
};

sub update_outcome {
  my $self = shift;
  my $outcome = shift;
  my $username = shift;
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
        croak(sprintf 'Error while trying to update a final outcome for id_run %i position %i',
              $self->id_run, $self->position);
      } else { #Update
        $self->update({'id_mqc_outcome' => $outcome_id, 'username' => $username});
      }
    } else { #Is a new row just insert.      
      $self->id_mqc_outcome($outcome_id);
      $self->user($username);
      $self->insert();
    }
  } else {
    croak(sprintf 'Error while trying to transit id_run %i position %i to a non-existing outcome "%s".',
          $self->id_run, $self->position, $outcome);
  }
  return 1;
}

sub has_final_outcome {
  my $self = shift;
  return $self->mqc_outcome->is_final_outcome;
}

#Create and save historic from the entity current data.
sub _create_historic {
  my $self = shift;
  my $rs = $self->result_source->schema->resultset('MqcOutcomeHist');
  my $historic = $rs->create({
    id_run         => $self->id_run,
    position       => $self->position,
    id_mqc_outcome => $self->id_mqc_outcome,
    username       => $self->username,
    last_modified  => $self->last_modified});

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

sub update_reported {
  my $self = shift;
  my $username = $ENV{'USER'} || 'mqc_reporter'; #Cron username or default username for the application.
  return $self->update({'reported' => $self->_get_time_now, 'username'=>$username});
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

=head2 update_outcome

  Updates the outcome of the entity with values provided.

  $obj->($outcome, $username)

=head2 has_final_outcome

  Returns true id this entry corresponds to a final outcome, otherwise returns false.

=head2 update_reported

  Updates the value of reported to the current timestamp.

=head2 update

  Default DBIx update method extended to create an entry in the table corresponding to 
  the MqcOutcomeHist class

=head2 insert

  Default DBIx insert method extended to create an entry in the table corresponding to 
  the MqcOutcomeHist class

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


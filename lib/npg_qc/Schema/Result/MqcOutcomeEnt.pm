
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

=head1 ADDITIONAL CLASSES USED

=over 4

=item * L<namespace::autoclean>

=back

=cut

use namespace::autoclean;

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=back

=cut

__PACKAGE__->load_components('InflateColumn::DateTime');

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

Web interface username

=head2 last_modified

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

=head2 modified_by

  data_type: 'char'
  is_nullable: 1
  size: 128

Last user to modify the row

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
  'modified_by',
  { data_type => 'char', is_nullable => 1, size => 128 },
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


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2015-06-30 16:51:56
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Ifqd4uXLKB/KQXtKle8Tnw

use Carp;

our $VERSION = '0';

use Array::Compare;
use npg_qc::Schema::MQCEntRole qw[$MQC_LIBRARY_ENT $MQC_LANE_HIST $MQC_LIB_LIMIT];

with qw/npg_qc::Schema::MQCEntRole/;

sub historic_resultset {
  my $self = shift;
  return $MQC_LANE_HIST;
}

sub update_reported {
  my $self = shift;
  my $username = $ENV{'USER'} || 'mqc_reporter'; #Cron username or default username for the application.
  if(!$self->has_final_outcome) {
    croak(sprintf 'Error while trying to update_reported non-final outcome id_run %i position %i".',
          $self->id_run, $self->position);
  }
  #It does not check if the reported is null just in case we need to update a reported one.
  return $self->update({'reported' => $self->get_time_now, 'modified_by' => $username}); #Only update the modified_by field.
}

sub short_desc {
  my $self = shift;
  my $s = sprintf 'id_run %s position %s', $self->id_run, $self->position;
  return $s;
}

sub validate_outcome_of_libraries {
  my ($self, $outcome_dict_obj, $tag_indexes_in_lims, $library_outcome_ents) = @_;

  if($outcome_dict_obj->is_accepted) {
    #all plexes with qc
    if(scalar @{ $tag_indexes_in_lims } == $library_outcome_ents->count ) {
      my $tag_indexes_in_qc = [];
      while(my $library = $library_outcome_ents->next) {
        if ($library->is_undecided) {
          croak('Error: All libraries need to have a pass or fail outcome.');
        }
        push @{$tag_indexes_in_qc}, $library->tag_index;
      }

      my $comp = Array::Compare->new;
      if (!$comp->perm($tag_indexes_in_lims, $tag_indexes_in_qc)) {
        croak('Error: Libraries in LIMS and libraries in QC does not match.');
      }
    } else {
      croak('Error: All libraries need to have an outcome.');
    }
  } else {
    #All plexes with undecided
    while(my $library = $library_outcome_ents->next) {
      if (!$library->is_undecided) {
        croak('Error: All libraries need to have undecided outcome.');
      }
    }
  }
  return 1;
}

sub update_outcome_with_libraries {
  my ($self, $outcome, $username, $tag_indexes_in_lims) = @_;

  my $outcome_dict_object = $self->find_valid_outcome($outcome);
  if( $outcome_dict_object->is_final_outcome
        && scalar @{$tag_indexes_in_lims} <= $MQC_LIB_LIMIT ) {
    my $rs_library_ent = $self->result_source->schema->resultset($MQC_LIBRARY_ENT);
    my $outcomes_libraries = $rs_library_ent->fetch_mqc_library_outcomes($self->id_run, $self->position);
    $self->validate_outcome_of_libraries($outcome_dict_object, $tag_indexes_in_lims, $outcomes_libraries);
    $rs_library_ent->batch_update_libraries( $self, $tag_indexes_in_lims, $username );
  }

  $self->update_outcome($outcome, $username);
  return 1;
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 SYNOPSIS

=head1 DESCRIPTION

Entity for lane MQC outcome.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 SUBROUTINES/METHODS

=head2 update_reported

  Updates the value of reported to the current timestamp. Thorws exception if the
  associated L<npg_qc::Schema::Result::MqcOutcomeDict> is not final.

=head2 update

  With around on DBIx update method to create an entry in the table corresponding to 
  the MqcOutcomeHist class

=head2 insert

  With around on DBIx insert method to create an entry in the table corresponding to 
  the MqcOutcomeHist class

=head2 data_for_historic

  Returns a hash with elements for the historic representation of the entity, a 
  subset of values of the instance.

=head2 historic_resultset

  Returns the name of the historic resultset associated with this entity

=head2 short_desc

  Returns minimal info of entity (run, lane, tag_index) for error messaging

=head2 validate_outcome_of_libraries

  Validates if overall state for the lane and the libraries allows for a final
  outcome in the lane.

=head2 update_outcome_with_libraries

  Updates children library mqc outcomes then updates outcome of lane mqc entity
  passed as parameter.

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item Moose

=item namespace::autoclean

=item MooseX::NonMoose

=item MooseX::MarkAsMethods

=item DBIx::Class::Core

=item Carp

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


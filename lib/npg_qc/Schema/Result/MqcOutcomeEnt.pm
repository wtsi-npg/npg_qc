
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
use Array::Compare;

with qw/npg_qc::Schema::Mqc::OutcomeEntity/;

our $VERSION = '0';

sub update_reported {
  my $self = shift;
  my $username = $ENV{'USER'} || croak 'Failed to get username';
  if(!$self->has_final_outcome) {
    croak(sprintf 'Outcome for id_run %i position %i is not final, cannot update".',
          $self->id_run, $self->position);
  }
  return $self->update({'reported' => $self->get_time_now, 'modified_by' => $username});
}

sub validate_outcome_of_libraries {
  my ($self, $outcome_dict_obj, $tag_indexes_in_lims, $library_outcome_ents) = @_;

  if($outcome_dict_obj->is_accepted) {
    #all plexes with qc
    if(scalar @{ $tag_indexes_in_lims } == $library_outcome_ents->count ) {
      my $tag_indexes_in_qc = [];
      while(my $library = $library_outcome_ents->next) {
        if ($library->is_undecided) {
          croak('All plex libraries should either pass or fail.');
        }
        push @{$tag_indexes_in_qc}, $library->tag_index;
      }

      my $comp = Array::Compare->new();
      if (!$comp->perm($tag_indexes_in_lims, $tag_indexes_in_qc)) {
        croak('Tag indexes in LIMs and QC do not match.');
      }
    } else {
      croak('All plex libraries have to be QC-ed.');
    }
  } else {
    #All plexes with undecided
    while(my $library = $library_outcome_ents->next) {
      if (!$library->is_undecided) {
        croak('All plex libraries should have undecided QC outcome.');
      }
    }
  }
  return 1;
}

sub update_outcome_with_libraries {
  my ($self, $outcome, $username, $tag_indexes_in_lims) = @_;
  my $outcome_dict_object = $self->find_valid_outcome($outcome);

  $tag_indexes_in_lims ||= [];
  my $num_tags = scalar @{$tag_indexes_in_lims};
  if( $num_tags && $outcome_dict_object->is_final_outcome
        && ($num_tags <= $self->mqc_lib_limit) ) {
    my $rs_library_ent = $self->result_source
                              ->schema
                              ->resultset( q[MqcLibraryOutcomeEnt] );
    my $outcomes_libraries = $rs_library_ent->fetch_mqc_library_outcomes(
      $self->id_run,
      $self->position
    );
    $self->validate_outcome_of_libraries(
      $outcome_dict_object,
      $tag_indexes_in_lims,
      $outcomes_libraries
    );
    $outcomes_libraries->reset;

    my $outcome_lib_hash = {};
    my $undefined_placeholder = q[undefined];
    while ( my $library = $outcomes_libraries->next ){
      my $key = defined $library->tag_index ? $library->tag_index
                                            : $undefined_placeholder;
      $outcome_lib_hash->{$key} = $library;
    }

    my $in_transaction = sub {
      $self->validate_username($username);
      my $rs_library_dict = $self->result_source
                                 ->schema
                                 ->resultset( q[MqcLibraryOutcomeDict] );
      my $library_dict_obj = $rs_library_dict->search(
        {'short_desc' => q[Undecided final]}
      )->first;
      my $new_outcome_id = $library_dict_obj->pk_value;

      foreach my $tag_index (@{$tag_indexes_in_lims}) {
        my $key = defined $tag_index ? $tag_index
                                     : $undefined_placeholder;
        my $library_ent;
        if ( exists $outcome_lib_hash->{$key} ) {
          $library_ent = $outcome_lib_hash->{$key};
          $library_ent->update_to_final_outcome($username);
        } else {
          my $values = {};
          $values->{'id_run'}         = $self->id_run;
          $values->{'position'}       = $self->position;
          $values->{'tag_index'}      = $tag_index;
          $values->{'username'}       = $username;
          $values->{'modified_by'}    = $username;
          $values->{'id_mqc_outcome'} = $new_outcome_id;
          $library_ent = $rs_library_ent->create($values);
        }
      }
    };

    $self->result_source->schema->txn_do($in_transaction);
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

=head2 update

  Default DBIx update method extended to create an entry in the table corresponding to
  the MqcOutcomeHist class

=head2 insert

  Default DBIx insert method extended to create an entry in the table corresponding to
  the MqcOutcomeHist class

=head2 update_reported

  Updates the value of reported to the current timestamp. Thorws exception if the
  associated L<npg_qc::Schema::Result::MqcOutcomeDict> is not final.

=head2 validate_outcome_of_libraries

  Validates if overall state for the lane and the libraries allows for a final
  outcome in the lane.

=head2 update_outcome_with_libraries

  Updates children library mqc outcomes then updates outcome of lane mqc entity
  passed as parameter. It expects a MqcOutcomeEnt object, a username for the
  operation and an arrary of plexes to update.

  $obj->update_outcome_with_libraries($new_outcome, $username, $tag_indexes_in_lims);

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


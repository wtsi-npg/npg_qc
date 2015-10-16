
package npg_qc::Schema::Result::MqcLibraryOutcomeEnt;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

##no critic(RequirePodAtEnd RequirePodLinksIncludeText ProhibitMagicNumbers ProhibitEmptyQuotes)

=head1 NAME

npg_qc::Schema::Result::MqcLibraryOutcomeEnt - Entity table for library manual qc

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

=head1 TABLE: C<mqc_library_outcome_ent>

=cut

__PACKAGE__->table('mqc_library_outcome_ent');

=head1 ACCESSORS

=head2 id_mqc_library_outcome_ent

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

=head2 tag_index

  data_type: 'bigint'
  default_value: -1
  is_nullable: 0

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
  'id_mqc_library_outcome_ent',
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
  'tag_index',
  { data_type => 'bigint', default_value => -1, is_nullable => 0 },
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

=item * L</id_mqc_library_outcome_ent>

=back

=cut

__PACKAGE__->set_primary_key('id_mqc_library_outcome_ent');

=head1 UNIQUE CONSTRAINTS

=head2 C<id_run_UNIQUE>

=over 4

=item * L</id_run>

=item * L</position>

=item * L</tag_index>

=back

=cut

__PACKAGE__->add_unique_constraint('id_run_UNIQUE', ['id_run', 'position', 'tag_index']);

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


# Created by DBIx::Class::Schema::Loader v0.07043 @ 2015-09-18 14:34:46
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:enQroYzqNS2pZjTzOQye9A

# You can replace this text with custom code or comments, and it will be preserved on regeneration
our $VERSION = '0';

with qw/npg_qc::Schema::Flators
        npg_qc::Schema::MQCEntRole/;

__PACKAGE__->set_inflator4scalar('tag_index');

sub historic_resultset {
  return q[MqcLibraryOutcomeHist];
}

sub short_desc {
  my $self = shift;
  my $s = sprintf 'id_run %s position %s tag_index %s', $self->id_run, $self->position, $self->tag_index;
  return $s;
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 SYNOPSIS

=head1 DESCRIPTION

Entity for library MQC outcome.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 SUBROUTINES/METHODS

=head2 short_desc

  Returns minimal info of entity (run, lane, tag_index) for error messaging

=head2 update

  Default DBIx update method extended to create an entry in the table corresponding to 
  the MqcLibraryOutcomeHist class

=head2 insert

  Default DBIx insert method extended to create an entry in the table corresponding to 
  the MqcLibraryOutcomeHist class

=head2 data_for_historic

  Returns a hash with elements for the historic representation of the entity, a 
  subset of values of the instance.

=head2 historic_resultset

  Returns the name of the historic resultset associated with this entity

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

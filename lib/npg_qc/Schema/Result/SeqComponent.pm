
package npg_qc::Schema::Result::SeqComponent;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

##no critic(RequirePodAtEnd RequirePodLinksIncludeText ProhibitMagicNumbers ProhibitEmptyQuotes)

=head1 NAME

npg_qc::Schema::Result::SeqComponent

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

=head1 TABLE: C<seq_component>

=cut

__PACKAGE__->table('seq_component');

=head1 ACCESSORS

=head2 id_seq_component

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

Auto-generated primary key

=head2 id_run

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 0

Numeric run id

=head2 position

  data_type: 'tinyint'
  extra: {unsigned => 1}
  is_nullable: 0

Numeric position (lane number)

=head2 tag_index

  data_type: 'mediumint'
  extra: {unsigned => 1}
  is_nullable: 1

An optional numeric tag index

=head2 subset

  data_type: 'varchar'
  is_nullable: 1
  size: 10

An optional sequence subset

=head2 digest

  data_type: 'char'
  is_nullable: 0
  size: 64

A SHA256 hex digest of the component JSON representation as defined in npg_tracking::glossary::composition::component

=cut

__PACKAGE__->add_columns(
  'id_seq_component',
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
  { data_type => 'mediumint', extra => { unsigned => 1 }, is_nullable => 1 },
  'subset',
  { data_type => 'varchar', is_nullable => 1, size => 10 },
  'digest',
  { data_type => 'char', is_nullable => 0, size => 64 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_seq_component>

=back

=cut

__PACKAGE__->set_primary_key('id_seq_component');

=head1 UNIQUE CONSTRAINTS

=head2 C<unq_seq_compon_d>

=over 4

=item * L</digest>

=back

=cut

__PACKAGE__->add_unique_constraint('unq_seq_compon_d', ['digest']);

=head2 C<unq_seq_component_runpostagsubset>

=over 4

=item * L</id_run>

=item * L</position>

=item * L</tag_index>

=item * L</subset>

=back

=cut

__PACKAGE__->add_unique_constraint(
  'unq_seq_component_runpostagsubset',
  ['id_run', 'position', 'tag_index', 'subset'],
);

=head1 RELATIONS

=head2 seq_component_compositions

Type: has_many

Related object: L<npg_qc::Schema::Result::SeqComponentComposition>

=cut

__PACKAGE__->has_many(
  'seq_component_compositions',
  'npg_qc::Schema::Result::SeqComponentComposition',
  { 'foreign.id_seq_component' => 'self.id_seq_component' },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07047 @ 2017-07-27 14:12:47
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:908hb0NvwuwmDvP63rM53Q


# You can replace this text with custom code or comments, and it will be preserved on regeneration

our $VERSION = '0';

use Carp;
use npg_tracking::glossary::composition::component::illumina;

# Have serialization to JSON and rtp done for us
with 'npg_tracking::glossary::composition::serializable' => {
  -excludes => [qw/digest compute_digest thaw/]
};

=head2 unpack

Implementation of a method required by the
npg_tracking::glossary::composition::serializable role.

=cut

sub unpack { ## no critic(Subroutines::ProhibitBuiltinHomonyms)
  croak 'Unpacking is not implemented';
}

=head2 pack

Implementation of a method required by the
npg_tracking::glossary::composition::serializable role.

Returns a hash with main attributes of the object and their values.

=cut

sub pack { ## no critic(Subroutines::ProhibitBuiltinHomonyms)
  my $self = shift;
  my $h = {};
  for my $column (qw/id_run position tag_index subset/) {
    $h->{$column} = $self->$column;
  }
  return $h;
}

=head2 create_component

Returns a component object npg_tracking::glossary::composition::component::illumina
corresponding to this row.

 my $illumina_component = $self->create_component();

=cut

sub create_component {
  my $self = shift;
  return npg_tracking::glossary::composition::component::illumina->thaw($self->freeze());
}

__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 SYNOPSIS

=head1 DESCRIPTION

Result class definition in DBIx binding for npg-qc database.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 SUBROUTINES/METHODS

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item Moose

=item namespace::autoclean

=item MooseX::NonMoose

=item MooseX::MarkAsMethods

=item DBIx::Class::Core

=item DBIx::Class::InflateColumn::DateTime

=item DBIx::Class::InflateColumn::Serializer

=item npg_tracking::glossary::composition::component::illumina

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2017 GRL

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

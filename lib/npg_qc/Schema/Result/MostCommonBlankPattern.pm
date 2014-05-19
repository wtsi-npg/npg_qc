
package npg_qc::Schema::Result::MostCommonBlankPattern;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

##no critic(RequirePodAtEnd RequirePodLinksIncludeText ProhibitMagicNumbers ProhibitEmptyQuotes)

=head1 NAME

npg_qc::Schema::Result::MostCommonBlankPattern - N=any non-blank character

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

=head1 TABLE: C<most_common_blank_pattern>

=cut

__PACKAGE__->table('most_common_blank_pattern');

=head1 ACCESSORS

=head2 id_most_common_blank_pattern

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 id_run_tile

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 rank

  data_type: 'tinyint'
  default_value: 1
  extra: {unsigned => 1}
  is_nullable: 0

=head2 occurrence

  data_type: 'mediumint'
  default_value: 1
  extra: {unsigned => 1}
  is_nullable: 0

=head2 pattern

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 number_of_sequences

  data_type: 'mediumint'
  default_value: 1
  extra: {unsigned => 1}
  is_nullable: 0

Should include all sequence at this rank, if multiple pattern entries

=head2 rescore

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  'id_most_common_blank_pattern',
  {
    data_type => 'bigint',
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  'id_run_tile',
  {
    data_type => 'bigint',
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  'rank',
  {
    data_type => 'tinyint',
    default_value => 1,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'occurrence',
  {
    data_type => 'mediumint',
    default_value => 1,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'pattern',
  { data_type => 'varchar', is_nullable => 1, size => 255 },
  'number_of_sequences',
  {
    data_type => 'mediumint',
    default_value => 1,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'rescore',
  { data_type => 'tinyint', default_value => 0, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_most_common_blank_pattern>

=back

=cut

__PACKAGE__->set_primary_key('id_most_common_blank_pattern');

=head1 RELATIONS

=head2 id_run_tile

Type: belongs_to

Related object: L<npg_qc::Schema::Result::RunTile>

=cut

__PACKAGE__->belongs_to(
  'id_run_tile',
  'npg_qc::Schema::Result::RunTile',
  { id_run_tile => 'id_run_tile' },
  { is_deferrable => 1, on_delete => 'RESTRICT', on_update => 'RESTRICT' },
);


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2014-02-23 17:42:06
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:RFYEg52LxU5P3F511k7h8A

our $VERSION = '0';

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

=item MooseX::NonMoose

=item MooseX::MarkAsMethods

=item DBIx::Class::Core

=item DBIx::Class::InflateColumn::DateTime

=item DBIx::Class::InflateColumn::Serializer

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014 GRL, by Marina Gourtovaia

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


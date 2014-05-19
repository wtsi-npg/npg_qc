
package npg_qc::Schema::Result::Fastqcheck;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

##no critic(RequirePodAtEnd RequirePodLinksIncludeText ProhibitMagicNumbers ProhibitEmptyQuotes)

=head1 NAME

npg_qc::Schema::Result::Fastqcheck

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

=head1 TABLE: C<fastqcheck>

=cut

__PACKAGE__->table('fastqcheck');

=head1 ACCESSORS

=head2 id_fastqcheck

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 id_run

  data_type: 'mediumint'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 position

  data_type: 'tinyint'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 tag_index

  data_type: 'mediumint'
  default_value: -1
  is_nullable: 0

=head2 section

  data_type: 'varchar'
  is_nullable: 0
  size: 10

=head2 split

  data_type: 'varchar'
  default_value: 'none'
  is_nullable: 0
  size: 10

=head2 file_name

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 file_content

  data_type: 'mediumtext'
  is_nullable: 1

=head2 file_content_compressed

  data_type: 'blob'
  is_nullable: 1

=head2 twenty

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 twentyfive

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 thirty

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 thirtyfive

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 forty

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  'id_fastqcheck',
  {
    data_type => 'bigint',
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  'id_run',
  { data_type => 'mediumint', extra => { unsigned => 1 }, is_nullable => 0 },
  'position',
  { data_type => 'tinyint', extra => { unsigned => 1 }, is_nullable => 0 },
  'tag_index',
  { data_type => 'mediumint', default_value => -1, is_nullable => 0 },
  'section',
  { data_type => 'varchar', is_nullable => 0, size => 10 },
  'split',
  {
    data_type => 'varchar',
    default_value => 'none',
    is_nullable => 0,
    size => 10,
  },
  'file_name',
  { data_type => 'varchar', is_nullable => 0, size => 255 },
  'file_content',
  { data_type => 'mediumtext', is_nullable => 1 },
  'file_content_compressed',
  { data_type => 'blob', is_nullable => 1 },
  'twenty',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'twentyfive',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'thirty',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'thirtyfive',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'forty',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_fastqcheck>

=back

=cut

__PACKAGE__->set_primary_key('id_fastqcheck');

=head1 UNIQUE CONSTRAINTS

=head2 C<unique_ind_file_ids_fastqcheck>

=over 4

=item * L</id_run>

=item * L</position>

=item * L</tag_index>

=item * L</section>

=item * L</split>

=back

=cut

__PACKAGE__->add_unique_constraint(
  'unique_ind_file_ids_fastqcheck',
  ['id_run', 'position', 'tag_index', 'section', 'split'],
);

=head2 C<unique_ind_file_name_fastqcheck>

=over 4

=item * L</file_name>

=back

=cut

__PACKAGE__->add_unique_constraint('unique_ind_file_name_fastqcheck', ['file_name']);

=head1 L<Moose> ROLES APPLIED

=over 4

=item * L<npg_qc::Schema::Flators>

=back

=cut


with 'npg_qc::Schema::Flators';


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2014-03-17 09:44:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:KVViSLyO3aqQg+uUZatunQ

__PACKAGE__->set_inflator4scalar('tag_index');
__PACKAGE__->set_inflator4scalar('split', 'is_string');


our $VERSION = '0';

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 VERSION

$Revision: 18256 $

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


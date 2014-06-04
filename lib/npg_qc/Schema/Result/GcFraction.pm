
package npg_qc::Schema::Result::GcFraction;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

##no critic(RequirePodAtEnd RequirePodLinksIncludeText ProhibitMagicNumbers ProhibitEmptyQuotes)

=head1 NAME

npg_qc::Schema::Result::GcFraction

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

=head1 TABLE: C<gc_fraction>

=cut

__PACKAGE__->table('gc_fraction');

=head1 ACCESSORS

=head2 id_gc_fraction

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

=head2 path

  data_type: 'varchar'
  is_nullable: 1
  size: 256

=head2 forward_read_filename

  data_type: 'varchar'
  is_nullable: 1
  size: 256

=head2 reverse_read_filename

  data_type: 'varchar'
  is_nullable: 1
  size: 256

=head2 forward_read_gc_percent

  data_type: 'float'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 reverse_read_gc_percent

  data_type: 'float'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 ref_gc_percent

  data_type: 'float'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 threshold_difference

  data_type: 'tinyint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 ref_count_path

  data_type: 'varchar'
  is_nullable: 1
  size: 256

=head2 pass

  data_type: 'tinyint'
  is_nullable: 1

=head2 comments

  data_type: 'text'
  is_nullable: 1

=head2 info

  data_type: 'text'
  is_nullable: 1

=head2 tag_index

  data_type: 'bigint'
  default_value: -1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  'id_gc_fraction',
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
  'path',
  { data_type => 'varchar', is_nullable => 1, size => 256 },
  'forward_read_filename',
  { data_type => 'varchar', is_nullable => 1, size => 256 },
  'reverse_read_filename',
  { data_type => 'varchar', is_nullable => 1, size => 256 },
  'forward_read_gc_percent',
  { data_type => 'float', extra => { unsigned => 1 }, is_nullable => 1 },
  'reverse_read_gc_percent',
  { data_type => 'float', extra => { unsigned => 1 }, is_nullable => 1 },
  'ref_gc_percent',
  { data_type => 'float', extra => { unsigned => 1 }, is_nullable => 1 },
  'threshold_difference',
  { data_type => 'tinyint', extra => { unsigned => 1 }, is_nullable => 1 },
  'ref_count_path',
  { data_type => 'varchar', is_nullable => 1, size => 256 },
  'pass',
  { data_type => 'tinyint', is_nullable => 1 },
  'comments',
  { data_type => 'text', is_nullable => 1 },
  'info',
  { data_type => 'text', is_nullable => 1 },
  'tag_index',
  { data_type => 'bigint', default_value => -1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_gc_fraction>

=back

=cut

__PACKAGE__->set_primary_key('id_gc_fraction');

=head1 UNIQUE CONSTRAINTS

=head2 C<unq_run_lane_gc_fraction>

=over 4

=item * L</id_run>

=item * L</position>

=item * L</tag_index>

=back

=cut

__PACKAGE__->add_unique_constraint(
  'unq_run_lane_gc_fraction',
  ['id_run', 'position', 'tag_index'],
);

=head1 L<Moose> ROLES APPLIED

=over 4

=item * L<npg_qc::Schema::Flators>

=item * L<npg_qc::autoqc::role::gc_fraction>

=back

=cut


with 'npg_qc::Schema::Flators', 'npg_qc::autoqc::role::gc_fraction';


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2014-03-17 09:54:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:wbDwlebLNRlH9OypM0iKcw

__PACKAGE__->set_flators4non_scalar(qw( info ));
__PACKAGE__->set_inflator4scalar('tag_index');


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


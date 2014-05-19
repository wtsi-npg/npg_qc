
package npg_qc::Schema::Result::ClusterDensity;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

##no critic(RequirePodAtEnd RequirePodLinksIncludeText ProhibitMagicNumbers ProhibitEmptyQuotes)

=head1 NAME

npg_qc::Schema::Result::ClusterDensity

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

=head1 TABLE: C<cluster_density>

=cut

__PACKAGE__->table('cluster_density');

=head1 ACCESSORS

=head2 id_cluster_density

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

=head2 is_pf

  data_type: 'tinyint'
  is_nullable: 0

=head2 min

  data_type: 'double precision'
  extra: {unsigned => 1}
  is_nullable: 1
  size: [12,3]

=head2 max

  data_type: 'double precision'
  extra: {unsigned => 1}
  is_nullable: 1
  size: [12,3]

=head2 p50

  data_type: 'double precision'
  extra: {unsigned => 1}
  is_nullable: 1
  size: [12,3]

=cut

__PACKAGE__->add_columns(
  'id_cluster_density',
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
  'is_pf',
  { data_type => 'tinyint', is_nullable => 0 },
  'min',
  {
    data_type => 'double precision',
    extra => { unsigned => 1 },
    is_nullable => 1,
    size => [12, 3],
  },
  'max',
  {
    data_type => 'double precision',
    extra => { unsigned => 1 },
    is_nullable => 1,
    size => [12, 3],
  },
  'p50',
  {
    data_type => 'double precision',
    extra => { unsigned => 1 },
    is_nullable => 1,
    size => [12, 3],
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_cluster_density>

=back

=cut

__PACKAGE__->set_primary_key('id_cluster_density');

=head1 UNIQUE CONSTRAINTS

=head2 C<unq_idx_cluster_density>

=over 4

=item * L</id_run>

=item * L</position>

=item * L</is_pf>

=back

=cut

__PACKAGE__->add_unique_constraint('unq_idx_cluster_density', ['id_run', 'position', 'is_pf']);


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2014-02-23 17:42:06
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:sWgH80l5cUoBcRy4OiaUaQ

our $VERSION = '0';

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 VERSION

$Revision: 18173 $

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


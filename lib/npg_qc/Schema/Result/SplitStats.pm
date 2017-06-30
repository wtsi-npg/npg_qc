
package npg_qc::Schema::Result::SplitStats;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

##no critic(RequirePodAtEnd RequirePodLinksIncludeText ProhibitMagicNumbers ProhibitEmptyQuotes)

=head1 NAME

npg_qc::Schema::Result::SplitStats

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

=item * L<DBIx::Class::InflateColumn::Serializer>

=back

=cut

__PACKAGE__->load_components('InflateColumn::DateTime', 'InflateColumn::Serializer');

=head1 TABLE: C<split_stats>

=cut

__PACKAGE__->table('split_stats');

=head1 ACCESSORS

=head2 id_split_stats

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 id_seq_composition

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 1

A foreign key referencing the id_seq_composition column of the seq_composition table

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

=head2 filename1

  data_type: 'varchar'
  is_nullable: 1
  size: 256

=head2 filename2

  data_type: 'varchar'
  is_nullable: 1
  size: 256

=head2 ref_name

  data_type: 'varchar'
  is_nullable: 0
  size: 50

=head2 reference

  data_type: 'varchar'
  is_nullable: 0
  size: 256

=head2 num_aligned1

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 num_not_aligned1

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 alignment_depth1

  data_type: 'text'
  is_nullable: 1

=head2 num_aligned2

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 num_not_aligned2

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 alignment_depth2

  data_type: 'text'
  is_nullable: 1

=head2 num_aligned_merge

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 num_not_aligned_merge

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

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
  'id_split_stats',
  {
    data_type => 'bigint',
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  'id_seq_composition',
  {
    data_type => 'bigint',
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 1,
  },
  'id_run',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 0 },
  'position',
  { data_type => 'tinyint', extra => { unsigned => 1 }, is_nullable => 0 },
  'path',
  { data_type => 'varchar', is_nullable => 1, size => 256 },
  'filename1',
  { data_type => 'varchar', is_nullable => 1, size => 256 },
  'filename2',
  { data_type => 'varchar', is_nullable => 1, size => 256 },
  'ref_name',
  { data_type => 'varchar', is_nullable => 0, size => 50 },
  'reference',
  { data_type => 'varchar', is_nullable => 0, size => 256 },
  'num_aligned1',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'num_not_aligned1',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'alignment_depth1',
  { data_type => 'text', is_nullable => 1 },
  'num_aligned2',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'num_not_aligned2',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'alignment_depth2',
  { data_type => 'text', is_nullable => 1 },
  'num_aligned_merge',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'num_not_aligned_merge',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
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

=item * L</id_split_stats>

=back

=cut

__PACKAGE__->set_primary_key('id_split_stats');

=head1 UNIQUE CONSTRAINTS

=head2 C<unq_run_lane_split_stats>

=over 4

=item * L</id_run>

=item * L</position>

=item * L</tag_index>

=item * L</ref_name>

=back

=cut

__PACKAGE__->add_unique_constraint(
  'unq_run_lane_split_stats',
  ['id_run', 'position', 'tag_index', 'ref_name'],
);

=head1 RELATIONS

=head2 seq_composition

Type: belongs_to

Related object: L<npg_qc::Schema::Result::SeqComposition>

=cut

__PACKAGE__->belongs_to(
  'seq_composition',
  'npg_qc::Schema::Result::SeqComposition',
  { id_seq_composition => 'id_seq_composition' },
  {
    is_deferrable => 1,
    join_type     => 'LEFT',
    on_delete     => 'NO ACTION',
    on_update     => 'NO ACTION',
  },
);

=head2 split_stats_coverages

Type: has_many

Related object: L<npg_qc::Schema::Result::SplitStatsCoverage>

=cut

__PACKAGE__->has_many(
  'split_stats_coverages',
  'npg_qc::Schema::Result::SplitStatsCoverage',
  { 'foreign.id_split_stats' => 'self.id_split_stats' },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head1 L<Moose> ROLES APPLIED

=over 4

=item * L<npg_qc::Schema::Flators>

=item * L<npg_qc::autoqc::role::result>

=back

=cut


with 'npg_qc::Schema::Flators', 'npg_qc::autoqc::role::result';


# Created by DBIx::Class::Schema::Loader v0.07046 @ 2017-06-30 16:29:06
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:+MMN7I1t59ka02lJNeXXlg

__PACKAGE__->set_flators4non_scalar(qw( alignment_depth1 alignment_depth2 info ));
__PACKAGE__->set_inflator4scalar('tag_index');


our $VERSION = '0';
use MooseX::Aliases;

alias subset => 'ref_name';

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 SYNOPSIS

=head1 DESCRIPTION

Result class definition in DBIx binding for npg-qc database.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 SUBROUTINES/METHODS

=head2 subset

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item Moose

=item MooseX::Aliases

=item namespace::autoclean

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

Copyright (C) 2016 GRL

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


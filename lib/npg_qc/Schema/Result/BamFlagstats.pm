
package npg_qc::Schema::Result::BamFlagstats;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

##no critic(RequirePodAtEnd RequirePodLinksIncludeText ProhibitMagicNumbers ProhibitEmptyQuotes)

=head1 NAME

npg_qc::Schema::Result::BamFlagstats

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

=head1 TABLE: C<bam_flagstats>

=cut

__PACKAGE__->table('bam_flagstats');

=head1 ACCESSORS

=head2 id_bam_flagstats

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

=head2 tag_index

  data_type: 'bigint'
  default_value: -1
  is_nullable: 0

=head2 path

  data_type: 'varchar'
  is_nullable: 1
  size: 256

=head2 human_split

  data_type: 'varchar'
  default_value: 'all'
  is_nullable: 1
  size: 10

=head2 library

  data_type: 'varchar'
  is_nullable: 1
  size: 256

=head2 unpaired_mapped_reads

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 paired_mapped_reads

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 unmapped_reads

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 unpaired_read_duplicates

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 paired_read_duplicates

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 read_pair_optical_duplicates

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 percent_duplicate

  data_type: 'float'
  is_nullable: 1
  size: [5,2]

=head2 library_size

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 histogram

  data_type: 'text'
  is_nullable: 1

=head2 proper_mapped_pair

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 mate_mapped_defferent_chr

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 mate_mapped_defferent_chr_5

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

=head2 num_total_reads

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 read_pairs_examined

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  'id_bam_flagstats',
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
  'path',
  { data_type => 'varchar', is_nullable => 1, size => 256 },
  'human_split',
  {
    data_type => 'varchar',
    default_value => 'all',
    is_nullable => 1,
    size => 10,
  },
  'library',
  { data_type => 'varchar', is_nullable => 1, size => 256 },
  'unpaired_mapped_reads',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'paired_mapped_reads',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'unmapped_reads',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'unpaired_read_duplicates',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'paired_read_duplicates',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'read_pair_optical_duplicates',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'percent_duplicate',
  { data_type => 'float', is_nullable => 1, size => [5, 2] },
  'library_size',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'histogram',
  { data_type => 'text', is_nullable => 1 },
  'proper_mapped_pair',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'mate_mapped_defferent_chr',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'mate_mapped_defferent_chr_5',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'pass',
  { data_type => 'tinyint', is_nullable => 1 },
  'comments',
  { data_type => 'text', is_nullable => 1 },
  'info',
  { data_type => 'text', is_nullable => 1 },
  'num_total_reads',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'read_pairs_examined',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_bam_flagstats>

=back

=cut

__PACKAGE__->set_primary_key('id_bam_flagstats');

=head1 UNIQUE CONSTRAINTS

=head2 C<unq_run_lane_index_sp_flag>

=over 4

=item * L</id_run>

=item * L</position>

=item * L</human_split>

=item * L</tag_index>

=back

=cut

__PACKAGE__->add_unique_constraint(
  'unq_run_lane_index_sp_flag',
  ['id_run', 'position', 'human_split', 'tag_index'],
);

=head1 L<Moose> ROLES APPLIED

=over 4

=item * L<npg_qc::Schema::Flators>

=item * L<npg_qc::autoqc::role::bam_flagstats>

=back

=cut


with 'npg_qc::Schema::Flators', 'npg_qc::autoqc::role::bam_flagstats';


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2014-03-17 09:54:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Akbsa4fpuqqLiyybLfO9bg

__PACKAGE__->set_flators4non_scalar(qw( histogram info ));
__PACKAGE__->set_inflator4scalar('tag_index');
__PACKAGE__->set_inflator4scalar('human_split', 'is_string');


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


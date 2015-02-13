
package npg_qc::Schema::Result::Genotype;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

##no critic(RequirePodAtEnd RequirePodLinksIncludeText ProhibitMagicNumbers ProhibitEmptyQuotes)

=head1 NAME

npg_qc::Schema::Result::Genotype

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

=head1 TABLE: C<genotype>

=cut

__PACKAGE__->table('genotype');

=head1 ACCESSORS

=head2 id_genotype

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

=head2 expected_sample_name

  data_type: 'varchar'
  is_nullable: 1
  size: 64

=head2 search_parameters

  data_type: 'text'
  is_nullable: 1

=head2 sample_name_match

  data_type: 'text'
  is_nullable: 1

=head2 sample_name_relaxed_match

  data_type: 'text'
  is_nullable: 1

=head2 alternate_matches

  data_type: 'text'
  is_nullable: 1

=head2 alternate_match_count

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 alternate_relaxed_matches

  data_type: 'text'
  is_nullable: 1

=head2 alternate_relaxed_match_count

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

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

=head2 snp_call_set

  data_type: 'varchar'
  default_value: 'UNSPECIFIED'
  is_nullable: 0
  size: 32

=head2 genotype_data_set

  data_type: 'varchar'
  is_nullable: 1
  size: 64

=head2 bam_file

  data_type: 'varchar'
  is_nullable: 1
  size: 64

=head2 bam_file_md5

  data_type: 'varchar'
  is_nullable: 1
  size: 64

=head2 reference

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=head2 bam_call_count

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 bam_call_string

  data_type: 'varchar'
  is_nullable: 1
  size: 256

=head2 bam_gt_depths_string

  data_type: 'varchar'
  is_nullable: 1
  size: 512

=head2 bam_gt_likelihood_string

  data_type: 'varchar'
  is_nullable: 1
  size: 2048

=cut

__PACKAGE__->add_columns(
  'id_genotype',
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
  'expected_sample_name',
  { data_type => 'varchar', is_nullable => 1, size => 64 },
  'search_parameters',
  { data_type => 'text', is_nullable => 1 },
  'sample_name_match',
  { data_type => 'text', is_nullable => 1 },
  'sample_name_relaxed_match',
  { data_type => 'text', is_nullable => 1 },
  'alternate_matches',
  { data_type => 'text', is_nullable => 1 },
  'alternate_match_count',
  { data_type => 'integer', default_value => 0, is_nullable => 0 },
  'alternate_relaxed_matches',
  { data_type => 'text', is_nullable => 1 },
  'alternate_relaxed_match_count',
  { data_type => 'integer', default_value => 0, is_nullable => 0 },
  'pass',
  { data_type => 'tinyint', is_nullable => 1 },
  'comments',
  { data_type => 'text', is_nullable => 1 },
  'info',
  { data_type => 'text', is_nullable => 1 },
  'tag_index',
  { data_type => 'bigint', default_value => -1, is_nullable => 0 },
  'snp_call_set',
  {
    data_type => 'varchar',
    default_value => 'UNSPECIFIED',
    is_nullable => 0,
    size => 32,
  },
  'genotype_data_set',
  { data_type => 'varchar', is_nullable => 1, size => 64 },
  'bam_file',
  { data_type => 'varchar', is_nullable => 1, size => 64 },
  'bam_file_md5',
  { data_type => 'varchar', is_nullable => 1, size => 64 },
  'reference',
  { data_type => 'varchar', is_nullable => 1, size => 128 },
  'bam_call_count',
  { data_type => 'integer', default_value => 0, is_nullable => 0 },
  'bam_call_string',
  { data_type => 'varchar', is_nullable => 1, size => 256 },
  'bam_gt_depths_string',
  { data_type => 'varchar', is_nullable => 1, size => 512 },
  'bam_gt_likelihood_string',
  { data_type => 'varchar', is_nullable => 1, size => 2048 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_genotype>

=back

=cut

__PACKAGE__->set_primary_key('id_genotype');

=head1 UNIQUE CONSTRAINTS

=head2 C<unq_run_lane_genotype>

=over 4

=item * L</id_run>

=item * L</position>

=item * L</tag_index>

=item * L</snp_call_set>

=back

=cut

__PACKAGE__->add_unique_constraint(
  'unq_run_lane_genotype',
  ['id_run', 'position', 'tag_index', 'snp_call_set'],
);

=head1 L<Moose> ROLES APPLIED

=over 4

=item * L<npg_qc::Schema::Flators>

=item * L<npg_qc::autoqc::role::genotype>

=back

=cut


with 'npg_qc::Schema::Flators', 'npg_qc::autoqc::role::genotype';


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2015-02-13 15:21:35
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:rnjxqXkxeljiQ5vROUgQhQ

__PACKAGE__->set_flators4non_scalar(qw( alternate_matches alternate_relaxed_matches sample_name_match sample_name_relaxed_match search_parameters info ));
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



package npg_qc::Schema::Result::TagMetrics;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

##no critic(RequirePodAtEnd RequirePodLinksIncludeText ProhibitMagicNumbers ProhibitEmptyQuotes)

=head1 NAME

npg_qc::Schema::Result::TagMetrics

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

=head1 TABLE: C<tag_metrics>

=cut

__PACKAGE__->table('tag_metrics');

=head1 ACCESSORS

=head2 id_tag_metrics

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 id_seq_composition

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

A foreign key referencing the id_seq_composition column of the seq_composition table

=head2 id_run

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 position

  data_type: 'tinyint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 path

  data_type: 'varchar'
  is_nullable: 1
  size: 256

=head2 metrics_file

  data_type: 'varchar'
  is_nullable: 1
  size: 256

=head2 barcode_tag_name

  data_type: 'varchar'
  is_nullable: 1
  size: 8

=head2 tags

  data_type: 'text'
  is_nullable: 1

=head2 reads_count

  data_type: 'text'
  is_nullable: 1

=head2 reads_pf_count

  data_type: 'text'
  is_nullable: 1

=head2 perfect_matches_count

  data_type: 'text'
  is_nullable: 1

=head2 perfect_matches_pf_count

  data_type: 'text'
  is_nullable: 1

=head2 one_mismatch_matches_count

  data_type: 'text'
  is_nullable: 1

=head2 one_mismatch_matches_pf_count

  data_type: 'text'
  is_nullable: 1

=head2 matches_percent

  data_type: 'text'
  is_nullable: 1

=head2 matches_pf_percent

  data_type: 'text'
  is_nullable: 1

=head2 spiked_control_index

  data_type: 'bigint'
  is_nullable: 1

=head2 max_mismatches_param

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 min_mismatch_delta_param

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 max_no_calls_param

  data_type: 'integer'
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

=head2 tag_hops_percent

  data_type: 'float'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 tag_hops_power

  data_type: 'float'
  extra: {unsigned => 1}
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  'id_tag_metrics',
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
    is_nullable => 0,
  },
  'id_run',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'position',
  { data_type => 'tinyint', extra => { unsigned => 1 }, is_nullable => 1 },
  'path',
  { data_type => 'varchar', is_nullable => 1, size => 256 },
  'metrics_file',
  { data_type => 'varchar', is_nullable => 1, size => 256 },
  'barcode_tag_name',
  { data_type => 'varchar', is_nullable => 1, size => 8 },
  'tags',
  { data_type => 'text', is_nullable => 1 },
  'reads_count',
  { data_type => 'text', is_nullable => 1 },
  'reads_pf_count',
  { data_type => 'text', is_nullable => 1 },
  'perfect_matches_count',
  { data_type => 'text', is_nullable => 1 },
  'perfect_matches_pf_count',
  { data_type => 'text', is_nullable => 1 },
  'one_mismatch_matches_count',
  { data_type => 'text', is_nullable => 1 },
  'one_mismatch_matches_pf_count',
  { data_type => 'text', is_nullable => 1 },
  'matches_percent',
  { data_type => 'text', is_nullable => 1 },
  'matches_pf_percent',
  { data_type => 'text', is_nullable => 1 },
  'spiked_control_index',
  { data_type => 'bigint', is_nullable => 1 },
  'max_mismatches_param',
  { data_type => 'integer', extra => { unsigned => 1 }, is_nullable => 1 },
  'min_mismatch_delta_param',
  { data_type => 'integer', extra => { unsigned => 1 }, is_nullable => 1 },
  'max_no_calls_param',
  { data_type => 'integer', extra => { unsigned => 1 }, is_nullable => 1 },
  'pass',
  { data_type => 'tinyint', is_nullable => 1 },
  'comments',
  { data_type => 'text', is_nullable => 1 },
  'info',
  { data_type => 'text', is_nullable => 1 },
  'tag_hops_percent',
  { data_type => 'float', extra => { unsigned => 1 }, is_nullable => 1 },
  'tag_hops_power',
  { data_type => 'float', extra => { unsigned => 1 }, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_tag_metrics>

=back

=cut

__PACKAGE__->set_primary_key('id_tag_metrics');

=head1 UNIQUE CONSTRAINTS

=head2 C<tag_metrics_compos_ind_unique>

=over 4

=item * L</id_seq_composition>

=back

=cut

__PACKAGE__->add_unique_constraint('tag_metrics_compos_ind_unique', ['id_seq_composition']);

=head1 RELATIONS

=head2 seq_composition

Type: belongs_to

Related object: L<npg_qc::Schema::Result::SeqComposition>

=cut

__PACKAGE__->belongs_to(
  'seq_composition',
  'npg_qc::Schema::Result::SeqComposition',
  { id_seq_composition => 'id_seq_composition' },
  { is_deferrable => 1, on_delete => 'NO ACTION', on_update => 'NO ACTION' },
);

=head1 L<Moose> ROLES APPLIED

=over 4

=item * L<npg_qc::Schema::Composition>

=item * L<npg_qc::Schema::Flators>

=item * L<npg_qc::autoqc::role::result>

=item * L<npg_qc::autoqc::role::tag_metrics>

=back

=cut


with 'npg_qc::Schema::Composition', 'npg_qc::Schema::Flators', 'npg_qc::autoqc::role::result', 'npg_qc::autoqc::role::tag_metrics';


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2021-08-19 13:25:57
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:X85s6Sx84dZtx0r2CpnPQA

our $VERSION = '0';

__PACKAGE__->set_flators4non_scalar(
  qw( tags reads_count reads_pf_count perfect_matches_count perfect_matches_pf_count
      one_mismatch_matches_count one_mismatch_matches_pf_count matches_percent
      matches_pf_percent info ));

__PACKAGE__->has_many(
  'seq_component_compositions',
  'npg_qc::Schema::Result::SeqComponentComposition',
  { 'foreign.id_seq_composition' => 'self.id_seq_composition' },
  { cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 SYNOPSIS

=head1 DESCRIPTION

Result class definition in DBIx binding for npg-qc database.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 SUBROUTINES/METHODS

=head2 composition

Attribute of type npg_tracking::glossary::composition.

=head2 seq_component_compositions

Type: has_many

Related object: L<npg_qc::Schema::Result::SeqComponentComposition>

To simplify queries, skip SeqComposition and link directly to the linking table.

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


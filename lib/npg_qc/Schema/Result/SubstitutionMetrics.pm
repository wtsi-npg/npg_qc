
package npg_qc::Schema::Result::SubstitutionMetrics;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

##no critic(RequirePodAtEnd RequirePodLinksIncludeText ProhibitMagicNumbers ProhibitEmptyQuotes)

=head1 NAME

npg_qc::Schema::Result::SubstitutionMetrics

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

=head1 TABLE: C<substitution_metrics>

=cut

__PACKAGE__->table('substitution_metrics');

=head1 ACCESSORS

=head2 id_substitution_metrics

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

Auto-generated primary key

=head2 id_seq_composition

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

A foreign key referencing the id_seq_composition column of the seq_composition table

=head2 path

  data_type: 'varchar'
  is_nullable: 1
  size: 256

=head2 titv_class

  data_type: 'float'
  extra: {unsigned => 1}
  is_nullable: 1

The ratio of transition substitution counts to transvertion

=head2 titv_mean_ca

  data_type: 'float'
  extra: {unsigned => 1}
  is_nullable: 1

TiTv where count of CA+GT is taken as if it were mean across other transversions

=head2 frac_sub_hq

  data_type: 'float'
  extra: {unsigned => 1}
  is_nullable: 1

Fraction of substitutions which are high quality (>=Q30)

=head2 oxog_bias

  data_type: 'float'
  extra: {unsigned => 1}
  is_nullable: 1

How similar CA to GT counts are within each read (high quality >=Q30 substitutions only) in order to detect OxoG oxidative artifacts

=head2 sym_gt_ca

  data_type: 'float'
  extra: {unsigned => 1}
  is_nullable: 1

How symmetrical CA and GT counts are within each read

=head2 sym_ct_ga

  data_type: 'float'
  extra: {unsigned => 1}
  is_nullable: 1

How symmetrical CT and GA counts are within each read

=head2 sym_ag_tc

  data_type: 'float'
  extra: {unsigned => 1}
  is_nullable: 1

How symmetrical AG and TC counts are within each read

=head2 cv_ti

  data_type: 'float'
  extra: {unsigned => 1}
  is_nullable: 1

Coefficient of variation across all Ti substitutions = std(Ti)/mean(Ti)

=head2 gt_ti

  data_type: 'float'
  extra: {unsigned => 1}
  is_nullable: 1

Computed as a maximum between (i) ratio of GT counts to TC and (ii) ratio CA to GA

=head2 gt_mean_ti

  data_type: 'float'
  extra: {unsigned => 1}
  is_nullable: 1

Computed as a maximum between (i) ratio of GT counts to mean(Ti) and (ii) ratio CA to mean(Ti)

=head2 ctoa_oxh

  data_type: 'float'
  extra: {unsigned => 1}
  is_nullable: 1

This metric is used to compute the likelihood of C2A and its predicted level

=head2 ctoa_art_predicted_level

  data_type: 'tinyint'
  extra: {unsigned => 1}
  is_nullable: 1

C2A predicted level - 0 = not present, 1 = low, 2 = medium and 3 = high

=head2 comments

  data_type: 'text'
  is_nullable: 1

Run-time comments and warnings

=head2 info

  data_type: 'text'
  is_nullable: 1

JSON document with information on how the data were produced

=cut

__PACKAGE__->add_columns(
  'id_substitution_metrics',
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
  'path',
  { data_type => 'varchar', is_nullable => 1, size => 256 },
  'titv_class',
  { data_type => 'float', extra => { unsigned => 1 }, is_nullable => 1 },
  'titv_mean_ca',
  { data_type => 'float', extra => { unsigned => 1 }, is_nullable => 1 },
  'frac_sub_hq',
  { data_type => 'float', extra => { unsigned => 1 }, is_nullable => 1 },
  'oxog_bias',
  { data_type => 'float', extra => { unsigned => 1 }, is_nullable => 1 },
  'sym_gt_ca',
  { data_type => 'float', extra => { unsigned => 1 }, is_nullable => 1 },
  'sym_ct_ga',
  { data_type => 'float', extra => { unsigned => 1 }, is_nullable => 1 },
  'sym_ag_tc',
  { data_type => 'float', extra => { unsigned => 1 }, is_nullable => 1 },
  'cv_ti',
  { data_type => 'float', extra => { unsigned => 1 }, is_nullable => 1 },
  'gt_ti',
  { data_type => 'float', extra => { unsigned => 1 }, is_nullable => 1 },
  'gt_mean_ti',
  { data_type => 'float', extra => { unsigned => 1 }, is_nullable => 1 },
  'ctoa_oxh',
  { data_type => 'float', extra => { unsigned => 1 }, is_nullable => 1 },
  'ctoa_art_predicted_level',
  { data_type => 'tinyint', extra => { unsigned => 1 }, is_nullable => 1 },
  'comments',
  { data_type => 'text', is_nullable => 1 },
  'info',
  { data_type => 'text', is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_substitution_metrics>

=back

=cut

__PACKAGE__->set_primary_key('id_substitution_metrics');

=head1 UNIQUE CONSTRAINTS

=head2 C<submetrics_compos_ind_unique>

=over 4

=item * L</id_seq_composition>

=back

=cut

__PACKAGE__->add_unique_constraint('submetrics_compos_ind_unique', ['id_seq_composition']);

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

=back

=cut


with 'npg_qc::Schema::Composition', 'npg_qc::Schema::Flators', 'npg_qc::autoqc::role::result';


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-06-13 22:43:13
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ZOL2iYj4stZnrInK/eUXAw

our $VERSION = '0';

__PACKAGE__->set_flators4non_scalar(qw( info ));

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

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2022 GRL

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


package npg_qc::Schema::Result::RnaSeqc;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

##no critic(RequirePodAtEnd RequirePodLinksIncludeText ProhibitMagicNumbers ProhibitEmptyQuotes)

=head1 NAME

npg_qc::Schema::Result::RnaSeqc

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

=head1 TABLE: C<rna_seqc>

=cut

__PACKAGE__->table('rna_seqc');

=head1 ACCESSORS

=head2 id_rna_seqc

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

=head2 info

  data_type: 'text'
  is_nullable: 1

=head2 rrna

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 rrna_rate

  data_type: 'float'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 exonic_rate

  data_type: 'float'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 expression_profiling_efficiency

  data_type: 'float'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 genes_detected

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 end_1_sense

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 end_1_antisense

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 end_2_sense

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 end_2_antisense

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 end_1_pct_sense

  data_type: 'float'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 end_2_pct_sense

  data_type: 'float'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 mean_per_base_cov

  data_type: 'float'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 mean_cv

  data_type: 'float'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 end_5_norm

  data_type: 'float'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 end_3_norm

  data_type: 'float'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 other_metrics

  data_type: 'text'
  is_nullable: 1

=head2 globin_pct_tpm

  data_type: 'float'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 mt_pct_tpm

  data_type: 'float'
  extra: {unsigned => 1}
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  'id_rna_seqc',
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
  'info',
  { data_type => 'text', is_nullable => 1 },
  'rrna',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'rrna_rate',
  { data_type => 'float', extra => { unsigned => 1 }, is_nullable => 1 },
  'exonic_rate',
  { data_type => 'float', extra => { unsigned => 1 }, is_nullable => 1 },
  'expression_profiling_efficiency',
  { data_type => 'float', extra => { unsigned => 1 }, is_nullable => 1 },
  'genes_detected',
  { data_type => 'integer', extra => { unsigned => 1 }, is_nullable => 1 },
  'end_1_sense',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'end_1_antisense',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'end_2_sense',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'end_2_antisense',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'end_1_pct_sense',
  { data_type => 'float', extra => { unsigned => 1 }, is_nullable => 1 },
  'end_2_pct_sense',
  { data_type => 'float', extra => { unsigned => 1 }, is_nullable => 1 },
  'mean_per_base_cov',
  { data_type => 'float', extra => { unsigned => 1 }, is_nullable => 1 },
  'mean_cv',
  { data_type => 'float', extra => { unsigned => 1 }, is_nullable => 1 },
  'end_5_norm',
  { data_type => 'float', extra => { unsigned => 1 }, is_nullable => 1 },
  'end_3_norm',
  { data_type => 'float', extra => { unsigned => 1 }, is_nullable => 1 },
  'other_metrics',
  { data_type => 'text', is_nullable => 1 },
  'globin_pct_tpm',
  { data_type => 'float', extra => { unsigned => 1 }, is_nullable => 1 },
  'mt_pct_tpm',
  { data_type => 'float', extra => { unsigned => 1 }, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_rna_seqc>

=back

=cut

__PACKAGE__->set_primary_key('id_rna_seqc');

=head1 UNIQUE CONSTRAINTS

=head2 C<rna_seqc_id_compos_unq>

=over 4

=item * L</id_seq_composition>

=back

=cut

__PACKAGE__->add_unique_constraint('rna_seqc_id_compos_unq', ['id_seq_composition']);

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

=item * L<npg_qc::autoqc::role::rna_seqc>

=back

=cut


with 'npg_qc::Schema::Composition', 'npg_qc::Schema::Flators', 'npg_qc::autoqc::role::result', 'npg_qc::autoqc::role::rna_seqc';


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2018-07-06 12:07:45
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:8C911G1+zdbgJPjsF1GPrg

# You can replace this text with custom code or comments, and it will be preserved on regeneration

our $VERSION = '0';

__PACKAGE__->set_flators4non_scalar(qw( other_metrics info ));

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

An lazy-build attribut of type npg_tracking::glossary::composition.

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

Ruben Bautista E<lt>rb11@sanger.ac.ukE<gt>

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


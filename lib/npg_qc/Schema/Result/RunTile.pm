
package npg_qc::Schema::Result::RunTile;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

##no critic(RequirePodAtEnd RequirePodLinksIncludeText ProhibitMagicNumbers ProhibitEmptyQuotes)

=head1 NAME

npg_qc::Schema::Result::RunTile - table linking a tile to a run and lane position

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

=back

=cut

__PACKAGE__->load_components('InflateColumn::DateTime');

=head1 TABLE: C<run_tile>

=cut

__PACKAGE__->table('run_tile');

=head1 ACCESSORS

=head2 id_run_tile

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 id_run

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 tile

  data_type: 'smallint'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 position

  data_type: 'tinyint'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 end

  data_type: 'char'
  is_nullable: 0
  size: 1

=head2 row

  data_type: 'smallint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 col

  data_type: 'tinyint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 avg_newz

  data_type: 'float'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  'id_run_tile',
  {
    data_type => 'bigint',
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  'id_run',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 0 },
  'tile',
  { data_type => 'smallint', extra => { unsigned => 1 }, is_nullable => 0 },
  'position',
  { data_type => 'tinyint', extra => { unsigned => 1 }, is_nullable => 0 },
  'end',
  { data_type => 'char', is_nullable => 0, size => 1 },
  'row',
  { data_type => 'smallint', extra => { unsigned => 1 }, is_nullable => 1 },
  'col',
  { data_type => 'tinyint', extra => { unsigned => 1 }, is_nullable => 1 },
  'avg_newz',
  { data_type => 'float', is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_run_tile>

=back

=cut

__PACKAGE__->set_primary_key('id_run_tile');

=head1 UNIQUE CONSTRAINTS

=head2 C<unq_idx_rt_idrun_end_position_tile>

=over 4

=item * L</id_run>

=item * L</end>

=item * L</position>

=item * L</tile>

=back

=cut

__PACKAGE__->add_unique_constraint(
  'unq_idx_rt_idrun_end_position_tile',
  ['id_run', 'end', 'position', 'tile'],
);

=head1 RELATIONS

=head2 cumulative_errors_by_cycle

Type: has_many

Related object: L<npg_qc::Schema::Result::CumulativeErrorsByCycle>

=cut

__PACKAGE__->has_many(
  'cumulative_errors_by_cycle',
  'npg_qc::Schema::Result::CumulativeErrorsByCycle',
  { 'foreign.id_run_tile' => 'self.id_run_tile' },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 error_rate_reference_including_blanks

Type: has_many

Related object: L<npg_qc::Schema::Result::ErrorRateReferenceIncludingBlank>

=cut

__PACKAGE__->has_many(
  'error_rate_reference_including_blanks',
  'npg_qc::Schema::Result::ErrorRateReferenceIncludingBlank',
  { 'foreign.id_run_tile' => 'self.id_run_tile' },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 error_rate_reference_no_blanks

Type: has_many

Related object: L<npg_qc::Schema::Result::ErrorRateReferenceNoBlank>

=cut

__PACKAGE__->has_many(
  'error_rate_reference_no_blanks',
  'npg_qc::Schema::Result::ErrorRateReferenceNoBlank',
  { 'foreign.id_run_tile' => 'self.id_run_tile' },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 error_rate_relative_reference_cycle_nucleotides

Type: has_many

Related object: L<npg_qc::Schema::Result::ErrorRateRelativeReferenceCycleNucleotide>

=cut

__PACKAGE__->has_many(
  'error_rate_relative_reference_cycle_nucleotides',
  'npg_qc::Schema::Result::ErrorRateRelativeReferenceCycleNucleotide',
  { 'foreign.id_run_tile' => 'self.id_run_tile' },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 error_rate_relative_sequence_bases

Type: has_many

Related object: L<npg_qc::Schema::Result::ErrorRateRelativeSequenceBase>

=cut

__PACKAGE__->has_many(
  'error_rate_relative_sequence_bases',
  'npg_qc::Schema::Result::ErrorRateRelativeSequenceBase',
  { 'foreign.id_run_tile' => 'self.id_run_tile' },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 errors_by_cycle

Type: has_many

Related object: L<npg_qc::Schema::Result::ErrorsByCycle>

=cut

__PACKAGE__->has_many(
  'errors_by_cycle',
  'npg_qc::Schema::Result::ErrorsByCycle',
  { 'foreign.id_run_tile' => 'self.id_run_tile' },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 errors_by_cycles_and_nucleotide

Type: has_many

Related object: L<npg_qc::Schema::Result::ErrorsByCycleAndNucleotide>

=cut

__PACKAGE__->has_many(
  'errors_by_cycles_and_nucleotide',
  'npg_qc::Schema::Result::ErrorsByCycleAndNucleotide',
  { 'foreign.id_run_tile' => 'self.id_run_tile' },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 errors_by_nucleotide

Type: has_many

Related object: L<npg_qc::Schema::Result::ErrorsByNucleotide>

=cut

__PACKAGE__->has_many(
  'errors_by_nucleotide',
  'npg_qc::Schema::Result::ErrorsByNucleotide',
  { 'foreign.id_run_tile' => 'self.id_run_tile' },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 information_contents_by_cycle

Type: has_many

Related object: L<npg_qc::Schema::Result::InformationContentByCycle>

=cut

__PACKAGE__->has_many(
  'information_contents_by_cycle',
  'npg_qc::Schema::Result::InformationContentByCycle',
  { 'foreign.id_run_tile' => 'self.id_run_tile' },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 lane_qcs

Type: has_many

Related object: L<npg_qc::Schema::Result::LaneQc>

=cut

__PACKAGE__->has_many(
  'lane_qcs',
  'npg_qc::Schema::Result::LaneQc',
  { 'foreign.id_run_tile' => 'self.id_run_tile' },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 log_likelihoods

Type: has_many

Related object: L<npg_qc::Schema::Result::LogLikelihood>

=cut

__PACKAGE__->has_many(
  'log_likelihoods',
  'npg_qc::Schema::Result::LogLikelihood',
  { 'foreign.id_run_tile' => 'self.id_run_tile' },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 most_common_blank_patterns

Type: has_many

Related object: L<npg_qc::Schema::Result::MostCommonBlankPattern>

=cut

__PACKAGE__->has_many(
  'most_common_blank_patterns',
  'npg_qc::Schema::Result::MostCommonBlankPattern',
  { 'foreign.id_run_tile' => 'self.id_run_tile' },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 most_common_words

Type: has_many

Related object: L<npg_qc::Schema::Result::MostCommonWord>

=cut

__PACKAGE__->has_many(
  'most_common_words',
  'npg_qc::Schema::Result::MostCommonWord',
  { 'foreign.id_run_tile' => 'self.id_run_tile' },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 moves_z

Type: has_many

Related object: L<npg_qc::Schema::Result::MoveZ>

=cut

__PACKAGE__->has_many(
  'moves_z',
  'npg_qc::Schema::Result::MoveZ',
  { 'foreign.id_run_tile' => 'self.id_run_tile' },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 tile_scores

Type: has_many

Related object: L<npg_qc::Schema::Result::TileScore>

=cut

__PACKAGE__->has_many(
  'tile_scores',
  'npg_qc::Schema::Result::TileScore',
  { 'foreign.id_run_tile' => 'self.id_run_tile' },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2015-06-30 16:51:56
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:KVyH1zZgDKvY5FrAKXcGhQ

our $VERSION = '0';

no Moose;
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


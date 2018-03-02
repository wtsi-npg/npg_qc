
package npg_qc::Schema::Result::AnalysisLane;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

##no critic(RequirePodAtEnd RequirePodLinksIncludeText ProhibitMagicNumbers ProhibitEmptyQuotes)

=head1 NAME

npg_qc::Schema::Result::AnalysisLane

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

=head1 TABLE: C<analysis_lane>

=cut

__PACKAGE__->table('analysis_lane');

=head1 ACCESSORS

=head2 id_analysis_lane

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 id_analysis

  data_type: 'bigint'
  default_value: 0
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 id_run

  data_type: 'bigint'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 end

  data_type: 'char'
  is_nullable: 0
  size: 1

=head2 position

  data_type: 'tinyint'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 tile_count

  data_type: 'bigint'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 align_score_pf

  data_type: 'float'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 align_score_pf_err

  data_type: 'float'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 clusters_pf

  data_type: 'float'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 clusters_pf_err

  data_type: 'float'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 clusters_raw

  data_type: 'float'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 clusters_raw_err

  data_type: 'float'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 clusters_tilemean_raw

  data_type: 'float'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 cycle1_int_pf

  data_type: 'float'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 cycle1_int_pf_err

  data_type: 'float'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 cycle20_perc_int

  data_type: 'float'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 cycle20_perc_int_err

  data_type: 'float'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 cycle_10_20_av_perc_loss_pf

  data_type: 'float'
  default_value: 0
  is_nullable: 0

=head2 cycle_10_20_av_perc_loss_pf_err

  data_type: 'float'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 cycle_2_10_av_perc_loss_pf

  data_type: 'float'
  default_value: 0
  is_nullable: 0

=head2 cycle_2_10_av_perc_loss_pf_err

  data_type: 'float'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 cycle_2_4_av_int_pf

  data_type: 'float'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 cycle_2_4_av_int_pf_err

  data_type: 'float'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 equiv_perfect_clusters_pf

  data_type: 'float'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 equiv_perfect_clusters_raw

  data_type: 'float'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 error_rate_pf

  data_type: 'float'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 error_rate_pf_err

  data_type: 'float'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 lane_yield

  data_type: 'float'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 perc_align_pf

  data_type: 'float'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 perc_align_pf2

  data_type: 'float'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 perc_align_pf_err

  data_type: 'float'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 perc_clusters_pf

  data_type: 'float'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 perc_clusters_pf_err

  data_type: 'float'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 perc_error_rate_pf

  data_type: 'float'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 perc_error_rate_raw

  data_type: 'float'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 perc_phasing

  data_type: 'float'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 perc_prephasing

  data_type: 'float'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 perc_retained

  data_type: 'float'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  'id_analysis_lane',
  {
    data_type => 'bigint',
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  'id_analysis',
  {
    data_type => 'bigint',
    default_value => 0,
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  'id_run',
  {
    data_type => 'bigint',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'end',
  { data_type => 'char', is_nullable => 0, size => 1 },
  'position',
  {
    data_type => 'tinyint',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'tile_count',
  {
    data_type => 'bigint',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'align_score_pf',
  {
    data_type => 'float',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'align_score_pf_err',
  {
    data_type => 'float',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'clusters_pf',
  {
    data_type => 'float',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'clusters_pf_err',
  {
    data_type => 'float',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'clusters_raw',
  {
    data_type => 'float',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'clusters_raw_err',
  {
    data_type => 'float',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'clusters_tilemean_raw',
  {
    data_type => 'float',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'cycle1_int_pf',
  {
    data_type => 'float',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'cycle1_int_pf_err',
  {
    data_type => 'float',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'cycle20_perc_int',
  {
    data_type => 'float',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'cycle20_perc_int_err',
  {
    data_type => 'float',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'cycle_10_20_av_perc_loss_pf',
  { data_type => 'float', default_value => 0, is_nullable => 0 },
  'cycle_10_20_av_perc_loss_pf_err',
  {
    data_type => 'float',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'cycle_2_10_av_perc_loss_pf',
  { data_type => 'float', default_value => 0, is_nullable => 0 },
  'cycle_2_10_av_perc_loss_pf_err',
  {
    data_type => 'float',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'cycle_2_4_av_int_pf',
  {
    data_type => 'float',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'cycle_2_4_av_int_pf_err',
  {
    data_type => 'float',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'equiv_perfect_clusters_pf',
  {
    data_type => 'float',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'equiv_perfect_clusters_raw',
  {
    data_type => 'float',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'error_rate_pf',
  {
    data_type => 'float',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'error_rate_pf_err',
  {
    data_type => 'float',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'lane_yield',
  {
    data_type => 'float',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'perc_align_pf',
  {
    data_type => 'float',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'perc_align_pf2',
  {
    data_type => 'float',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'perc_align_pf_err',
  {
    data_type => 'float',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'perc_clusters_pf',
  {
    data_type => 'float',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'perc_clusters_pf_err',
  {
    data_type => 'float',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'perc_error_rate_pf',
  {
    data_type => 'float',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'perc_error_rate_raw',
  {
    data_type => 'float',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'perc_phasing',
  {
    data_type => 'float',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'perc_prephasing',
  {
    data_type => 'float',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'perc_retained',
  {
    data_type => 'float',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_analysis_lane>

=back

=cut

__PACKAGE__->set_primary_key('id_analysis_lane');

=head1 UNIQUE CONSTRAINTS

=head2 C<unq_al_lane>

=over 4

=item * L</id_analysis>

=item * L</position>

=back

=cut

__PACKAGE__->add_unique_constraint('unq_al_lane', ['id_analysis', 'position']);

=head1 RELATIONS

=head2 analysis

Type: belongs_to

Related object: L<npg_qc::Schema::Result::Analysis>

=cut

__PACKAGE__->belongs_to(
  'analysis',
  'npg_qc::Schema::Result::Analysis',
  { id_analysis => 'id_analysis' },
  { is_deferrable => 1, on_delete => 'NO ACTION', on_update => 'NO ACTION' },
);


# Created by DBIx::Class::Schema::Loader v0.07047 @ 2017-11-28 18:47:11
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:zLPPeYv9mkcHumgdmyGTOA

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


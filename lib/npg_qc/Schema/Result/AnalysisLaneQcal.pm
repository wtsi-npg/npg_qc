
package npg_qc::Schema::Result::AnalysisLaneQcal;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

##no critic(RequirePodAtEnd RequirePodLinksIncludeText ProhibitMagicNumbers ProhibitEmptyQuotes)

=head1 NAME

npg_qc::Schema::Result::AnalysisLaneQcal

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

=head1 TABLE: C<analysis_lane_qcal>

=cut

__PACKAGE__->table('analysis_lane_qcal');

=head1 ACCESSORS

=head2 id_analysis_lane_qcal

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 id_analysis_lane

  data_type: 'bigint'
  default_value: 0
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 chastity

  data_type: 'float'
  is_nullable: 1

=head2 qv

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 cum_error

  data_type: 'bigint'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

cumulative error >= qv

=head2 cum_bases

  data_type: 'bigint'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

cumulative bases >= qv

=head2 cum_perc_error

  data_type: 'float'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

cumulative percentage error >=qv

=head2 cum_perc_total

  data_type: 'float'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

cumulative percentage total >= qv

=head2 error

  data_type: 'bigint'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 bases

  data_type: 'bigint'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 perc_error

  data_type: 'float'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 perc_total

  data_type: 'float'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 exp_perc_error

  data_type: 'float'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

expected percentage error

=cut

__PACKAGE__->add_columns(
  'id_analysis_lane_qcal',
  {
    data_type => 'bigint',
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  'id_analysis_lane',
  {
    data_type => 'bigint',
    default_value => 0,
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  'chastity',
  { data_type => 'float', is_nullable => 1 },
  'qv',
  { data_type => 'integer', default_value => 0, is_nullable => 0 },
  'cum_error',
  {
    data_type => 'bigint',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'cum_bases',
  {
    data_type => 'bigint',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'cum_perc_error',
  {
    data_type => 'float',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'cum_perc_total',
  {
    data_type => 'float',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'error',
  {
    data_type => 'bigint',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'bases',
  {
    data_type => 'bigint',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'perc_error',
  {
    data_type => 'float',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'perc_total',
  {
    data_type => 'float',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  'exp_perc_error',
  {
    data_type => 'float',
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_analysis_lane_qcal>

=back

=cut

__PACKAGE__->set_primary_key('id_analysis_lane_qcal');

=head1 RELATIONS

=head2 id_analysis_lane

Type: belongs_to

Related object: L<npg_qc::Schema::Result::AnalysisLane>

=cut

__PACKAGE__->belongs_to(
  'id_analysis_lane',
  'npg_qc::Schema::Result::AnalysisLane',
  { id_analysis_lane => 'id_analysis_lane' },
  { is_deferrable => 1, on_delete => 'NO ACTION', on_update => 'NO ACTION' },
);


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2014-02-23 17:42:06
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:9o+fRMKYiTq6L9wt7zUlHA

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


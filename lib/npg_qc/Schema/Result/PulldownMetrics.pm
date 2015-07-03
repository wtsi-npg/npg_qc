
package npg_qc::Schema::Result::PulldownMetrics;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

##no critic(RequirePodAtEnd RequirePodLinksIncludeText ProhibitMagicNumbers ProhibitEmptyQuotes)

=head1 NAME

npg_qc::Schema::Result::PulldownMetrics

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

=head1 TABLE: C<pulldown_metrics>

=cut

__PACKAGE__->table('pulldown_metrics');

=head1 ACCESSORS

=head2 id_pulldown_metrics

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

=head2 comments

  data_type: 'text'
  is_nullable: 1

=head2 info

  data_type: 'text'
  is_nullable: 1

=head2 pass

  data_type: 'tinyint'
  is_nullable: 1

=head2 interval_files_identical

  data_type: 'tinyint'
  is_nullable: 1

=head2 bait_path

  data_type: 'varchar'
  is_nullable: 1
  size: 256

=head2 bait_territory

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 target_territory

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 total_reads_num

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 unique_reads_num

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 unique_reads_aligned_num

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 unique_bases_aligned_num

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 on_bait_bases_num

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 near_bait_bases_num

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 off_bait_bases_num

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 on_target_bases_num

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 library_size

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 mean_bait_coverage

  data_type: 'float'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 mean_target_coverage

  data_type: 'float'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 fold_enrichment

  data_type: 'float'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 zero_coverage_targets_fraction

  data_type: 'float'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 other_metrics

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  'id_pulldown_metrics',
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
  'comments',
  { data_type => 'text', is_nullable => 1 },
  'info',
  { data_type => 'text', is_nullable => 1 },
  'pass',
  { data_type => 'tinyint', is_nullable => 1 },
  'interval_files_identical',
  { data_type => 'tinyint', is_nullable => 1 },
  'bait_path',
  { data_type => 'varchar', is_nullable => 1, size => 256 },
  'bait_territory',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'target_territory',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'total_reads_num',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'unique_reads_num',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'unique_reads_aligned_num',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'unique_bases_aligned_num',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'on_bait_bases_num',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'near_bait_bases_num',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'off_bait_bases_num',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'on_target_bases_num',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'library_size',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'mean_bait_coverage',
  { data_type => 'float', extra => { unsigned => 1 }, is_nullable => 1 },
  'mean_target_coverage',
  { data_type => 'float', extra => { unsigned => 1 }, is_nullable => 1 },
  'fold_enrichment',
  { data_type => 'float', extra => { unsigned => 1 }, is_nullable => 1 },
  'zero_coverage_targets_fraction',
  { data_type => 'float', extra => { unsigned => 1 }, is_nullable => 1 },
  'other_metrics',
  { data_type => 'text', is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_pulldown_metrics>

=back

=cut

__PACKAGE__->set_primary_key('id_pulldown_metrics');

=head1 UNIQUE CONSTRAINTS

=head2 C<unq_run_lane_pdmetrics>

=over 4

=item * L</id_run>

=item * L</position>

=item * L</tag_index>

=back

=cut

__PACKAGE__->add_unique_constraint('unq_run_lane_pdmetrics', ['id_run', 'position', 'tag_index']);

=head1 L<Moose> ROLES APPLIED

=over 4

=item * L<npg_qc::Schema::Flators>

=item * L<npg_qc::autoqc::role::pulldown_metrics>

=back

=cut


with 'npg_qc::Schema::Flators', 'npg_qc::autoqc::role::pulldown_metrics';


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2015-06-30 16:51:56
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ld9NKEeQd+6Jv8k0fM4vbQ

__PACKAGE__->set_flators4non_scalar(qw( other_metrics info ));
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


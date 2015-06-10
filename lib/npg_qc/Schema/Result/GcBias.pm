
package npg_qc::Schema::Result::GcBias;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

##no critic(RequirePodAtEnd RequirePodLinksIncludeText ProhibitMagicNumbers ProhibitEmptyQuotes)

=head1 NAME

npg_qc::Schema::Result::GcBias

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

=head1 TABLE: C<gc_bias>

=cut

__PACKAGE__->table('gc_bias');

=head1 ACCESSORS

=head2 id_gc_bias

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

=head2 pass

  data_type: 'tinyint'
  is_nullable: 1

=head2 comments

  data_type: 'text'
  is_nullable: 1

=head2 info

  data_type: 'text'
  is_nullable: 1

=head2 max_y

  data_type: 'float'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 window_count

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 window_size

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 bin_count

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 actual_quantile_x

  data_type: 'text'
  is_nullable: 1

=head2 actual_quantile_y

  data_type: 'text'
  is_nullable: 1

=head2 gc_lines

  data_type: 'text'
  is_nullable: 1

=head2 plot_x

  data_type: 'text'
  is_nullable: 1

=head2 plot_y

  data_type: 'text'
  is_nullable: 1

=head2 ideal_lower_quantile

  data_type: 'text'
  is_nullable: 1

=head2 ideal_upper_quantile

  data_type: 'text'
  is_nullable: 1

=head2 cached_plot

  data_type: 'text'
  is_nullable: 1

=head2 tag_index

  data_type: 'bigint'
  default_value: -1
  is_nullable: 0

=head2 gcpercent

  data_type: 'text'
  is_nullable: 1

=head2 pc_us

  data_type: 'text'
  is_nullable: 1

=head2 pc_10

  data_type: 'text'
  is_nullable: 1

=head2 pc_25

  data_type: 'text'
  is_nullable: 1

=head2 pc_50

  data_type: 'text'
  is_nullable: 1

=head2 pc_75

  data_type: 'text'
  is_nullable: 1

=head2 pc_90

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  'id_gc_bias',
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
  'pass',
  { data_type => 'tinyint', is_nullable => 1 },
  'comments',
  { data_type => 'text', is_nullable => 1 },
  'info',
  { data_type => 'text', is_nullable => 1 },
  'max_y',
  { data_type => 'float', extra => { unsigned => 1 }, is_nullable => 1 },
  'window_count',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'window_size',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'bin_count',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 1 },
  'actual_quantile_x',
  { data_type => 'text', is_nullable => 1 },
  'actual_quantile_y',
  { data_type => 'text', is_nullable => 1 },
  'gc_lines',
  { data_type => 'text', is_nullable => 1 },
  'plot_x',
  { data_type => 'text', is_nullable => 1 },
  'plot_y',
  { data_type => 'text', is_nullable => 1 },
  'ideal_lower_quantile',
  { data_type => 'text', is_nullable => 1 },
  'ideal_upper_quantile',
  { data_type => 'text', is_nullable => 1 },
  'cached_plot',
  { data_type => 'text', is_nullable => 1 },
  'tag_index',
  { data_type => 'bigint', default_value => -1, is_nullable => 0 },
  'gcpercent',
  { data_type => 'text', is_nullable => 1 },
  'pc_us',
  { data_type => 'text', is_nullable => 1 },
  'pc_10',
  { data_type => 'text', is_nullable => 1 },
  'pc_25',
  { data_type => 'text', is_nullable => 1 },
  'pc_50',
  { data_type => 'text', is_nullable => 1 },
  'pc_75',
  { data_type => 'text', is_nullable => 1 },
  'pc_90',
  { data_type => 'text', is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_gc_bias>

=back

=cut

__PACKAGE__->set_primary_key('id_gc_bias');

=head1 UNIQUE CONSTRAINTS

=head2 C<unq_run_lane_gc_bias>

=over 4

=item * L</id_run>

=item * L</position>

=item * L</tag_index>

=back

=cut

__PACKAGE__->add_unique_constraint('unq_run_lane_gc_bias', ['id_run', 'position', 'tag_index']);

=head1 L<Moose> ROLES APPLIED

=over 4

=item * L<npg_qc::Schema::Flators>

=item * L<npg_qc::autoqc::role::gc_bias>

=back

=cut


with 'npg_qc::Schema::Flators', 'npg_qc::autoqc::role::gc_bias';


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2015-06-09 11:27:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:l//bpOrgEV7nqFxLm5VoPg

__PACKAGE__->set_flators4non_scalar(qw( actual_quantile_x actual_quantile_y gc_lines plot_x plot_y ideal_lower_quantile ideal_upper_quantile info gcpercent pc_us pc_10 pc_25 pc_50 pc_75 pc_90));
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


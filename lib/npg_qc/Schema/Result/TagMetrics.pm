
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

=head2 tag_index

  data_type: 'bigint'
  default_value: -1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  'id_tag_metrics',
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
  'tag_index',
  { data_type => 'bigint', default_value => -1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_tag_metrics>

=back

=cut

__PACKAGE__->set_primary_key('id_tag_metrics');

=head1 UNIQUE CONSTRAINTS

=head2 C<unq_run_lane_tagmetrics>

=over 4

=item * L</id_run>

=item * L</position>

=item * L</tag_index>

=back

=cut

__PACKAGE__->add_unique_constraint(
  'unq_run_lane_tagmetrics',
  ['id_run', 'position', 'tag_index'],
);

=head1 L<Moose> ROLES APPLIED

=over 4

=item * L<npg_qc::Schema::Flators>

=item * L<npg_qc::autoqc::role::tag_metrics>

=back

=cut


with 'npg_qc::Schema::Flators', 'npg_qc::autoqc::role::tag_metrics';


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2014-03-17 09:54:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:xyUHkxwNSWD8mnLk1zYWXQ

__PACKAGE__->set_flators4non_scalar(qw( tags reads_count reads_pf_count perfect_matches_count perfect_matches_pf_count one_mismatch_matches_count one_mismatch_matches_pf_count matches_percent matches_pf_percent info ));
__PACKAGE__->set_inflator4scalar('tag_index');


our $VERSION   = do { my ($r) = q$Revision$ =~ /(\d+)/mxs; $r; };

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 VERSION

$Revision$

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


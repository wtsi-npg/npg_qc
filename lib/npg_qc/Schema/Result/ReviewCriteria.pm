
package npg_qc::Schema::Result::ReviewCriteria;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

##no critic(RequirePodAtEnd RequirePodLinksIncludeText ProhibitMagicNumbers ProhibitEmptyQuotes)

=head1 NAME

npg_qc::Schema::Result::ReviewCriteria

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

=head1 TABLE: C<review_criteria>

=cut

__PACKAGE__->table('review_criteria');

=head1 ACCESSORS

=head2 id_review_criteria

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

Auto-generated primary key

=head2 checksum

  data_type: 'char'
  is_nullable: 0
  size: 32

=head2 library_type

  data_type: 'varchar'
  is_nullable: 0
  size: 100

=head2 created_on

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

=head2 criteria

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  'id_review_criteria',
  {
    data_type => 'bigint',
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  'checksum',
  { data_type => 'char', is_nullable => 0, size => 32 },
  'library_type',
  { data_type => 'varchar', is_nullable => 0, size => 100 },
  'created_on',
  {
    data_type => 'timestamp',
    datetime_undef_if_invalid => 1,
    default_value => \'current_timestamp',
    is_nullable => 0,
  },
  'criteria',
  { data_type => 'text', is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_review_criteria>

=back

=cut

__PACKAGE__->set_primary_key('id_review_criteria');

=head1 UNIQUE CONSTRAINTS

=head2 C<review_criteria_uniq>

=over 4

=item * L</checksum>

=item * L</library_type>

=back

=cut

__PACKAGE__->add_unique_constraint('review_criteria_uniq', ['checksum', 'library_type']);

=head1 RELATIONS

=head2 reviews

Type: has_many

Related object: L<npg_qc::Schema::Result::Review>

=cut

__PACKAGE__->has_many(
  'reviews',
  'npg_qc::Schema::Result::Review',
  { 'foreign.id_review_criteria' => 'self.id_review_criteria' },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2019-06-11 10:16:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ZQoV/Q9acCDVr6ZP0Hd+eA


# You can replace this text with custom code or comments, and it will be preserved on regeneration

our $VERSION = '0';

with 'npg_qc::Schema::Flators';

__PACKAGE__->load_components('InflateColumn::Serializer');

# Set inflation and deflation for non-scalar data.
__PACKAGE__->set_flators4non_scalar( qw/ criteria /);

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 SYNOPSIS

=head1 DESCRIPTION

DBIx class for the review database table.

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

Copyright (C) 2019 GRL

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

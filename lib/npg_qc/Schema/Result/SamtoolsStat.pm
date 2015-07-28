
package npg_qc::Schema::Result::SamtoolsStat;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

##no critic(RequirePodAtEnd RequirePodLinksIncludeText ProhibitMagicNumbers ProhibitEmptyQuotes)

=head1 NAME

npg_qc::Schema::Result::SamtoolsStat

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

=head1 TABLE: C<samtools_stats>

=cut

__PACKAGE__->table('samtools_stats');

=head1 ACCESSORS

=head2 id_samtools_stats

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 id_bam_flagstats

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 filter

  data_type: 'varchar'
  is_nullable: 0
  size: 8

=head2 file_content

  data_type: 'blob'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  'id_samtools_stats',
  {
    data_type => 'bigint',
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  'id_bam_flagstats',
  {
    data_type => 'bigint',
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  'filter',
  { data_type => 'varchar', is_nullable => 0, size => 8 },
  'file_content',
  { data_type => 'blob', is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_samtools_stats>

=back

=cut

__PACKAGE__->set_primary_key('id_samtools_stats');

=head1 UNIQUE CONSTRAINTS

=head2 C<unq_sequence_stats>

=over 4

=item * L</id_bam_flagstats>

=item * L</filter>

=back

=cut

__PACKAGE__->add_unique_constraint('unq_sequence_stats', ['id_bam_flagstats', 'filter']);

=head1 RELATIONS

=head2 bam_flagstat

Type: belongs_to

Related object: L<npg_qc::Schema::Result::BamFlagstats>

=cut

__PACKAGE__->belongs_to(
  'bam_flagstat',
  'npg_qc::Schema::Result::BamFlagstats',
  { id_bam_flagstats => 'id_bam_flagstats' },
  { is_deferrable => 1, on_delete => 'CASCADE', on_update => 'NO ACTION' },
);


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2015-07-28 13:13:47
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:GyHE08dFy8u8jo2WAyn12Q


# You can replace this text with custom code or comments, and it will be preserved on regeneration

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

Copyright (C) 2015 GRL

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

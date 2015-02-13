
package npg_qc::Schema::Result::RefSnpInfo;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

##no critic(RequirePodAtEnd RequirePodLinksIncludeText ProhibitMagicNumbers ProhibitEmptyQuotes)

=head1 NAME

npg_qc::Schema::Result::RefSnpInfo

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

=back

=cut

__PACKAGE__->load_components('InflateColumn::DateTime');

=head1 TABLE: C<ref_snp_info>

=cut

__PACKAGE__->table('ref_snp_info');

=head1 ACCESSORS

=head2 id_ref_snp_info

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 reference

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=head2 snp_name

  data_type: 'varchar'
  is_nullable: 0
  size: 32

=head2 chr

  data_type: 'varchar'
  is_nullable: 0
  size: 16

=head2 pos

  data_type: 'integer'
  is_nullable: 0

=head2 ref_allele

  data_type: 'varchar'
  is_nullable: 0
  size: 64

=head2 alt_allele

  data_type: 'varchar'
  is_nullable: 0
  size: 64

=head2 sequenom_plex_name

  data_type: 'varchar'
  is_nullable: 0
  size: 32

=cut

__PACKAGE__->add_columns(
  'id_ref_snp_info',
  {
    data_type => 'bigint',
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  'reference',
  { data_type => 'varchar', is_nullable => 1, size => 128 },
  'snp_name',
  { data_type => 'varchar', is_nullable => 0, size => 32 },
  'chr',
  { data_type => 'varchar', is_nullable => 0, size => 16 },
  'pos',
  { data_type => 'integer', is_nullable => 0 },
  'ref_allele',
  { data_type => 'varchar', is_nullable => 0, size => 64 },
  'alt_allele',
  { data_type => 'varchar', is_nullable => 0, size => 64 },
  'sequenom_plex_name',
  { data_type => 'varchar', is_nullable => 0, size => 32 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_ref_snp_info>

=back

=cut

__PACKAGE__->set_primary_key('id_ref_snp_info');

=head1 UNIQUE CONSTRAINTS

=head2 C<unq_ref_chr_pos>

=over 4

=item * L</reference>

=item * L</chr>

=item * L</pos>

=back

=cut

__PACKAGE__->add_unique_constraint('unq_ref_chr_pos', ['reference', 'chr', 'pos']);


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2015-02-13 15:21:35
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:BgKeXz8HjI1cQ+0m56A5Pw

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


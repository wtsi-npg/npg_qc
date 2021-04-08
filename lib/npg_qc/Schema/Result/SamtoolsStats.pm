
package npg_qc::Schema::Result::SamtoolsStats;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

##no critic(RequirePodAtEnd RequirePodLinksIncludeText ProhibitMagicNumbers ProhibitEmptyQuotes)

=head1 NAME

npg_qc::Schema::Result::SamtoolsStats

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

=head1 TABLE: C<samtools_stats>

=cut

__PACKAGE__->table('samtools_stats');

=head1 ACCESSORS

=head2 id_samtools_stats

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

=head2 filter

  data_type: 'varchar'
  is_nullable: 0
  size: 30

=head2 stats

  data_type: 'longblob'
  is_nullable: 0

Compressed samtools stats file content

=cut

__PACKAGE__->add_columns(
  'id_samtools_stats',
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
  'filter',
  { data_type => 'varchar', is_nullable => 0, size => 30 },
  'stats',
  { data_type => 'longblob', is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_samtools_stats>

=back

=cut

__PACKAGE__->set_primary_key('id_samtools_stats');

=head1 UNIQUE CONSTRAINTS

=head2 C<unq_seqstats>

=over 4

=item * L</id_seq_composition>

=item * L</filter>

=back

=cut

__PACKAGE__->add_unique_constraint('unq_seqstats', ['id_seq_composition', 'filter']);

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

=item * L<npg_qc::autoqc::role::samtools_stats>

=back

=cut


with 'npg_qc::Schema::Composition', 'npg_qc::Schema::Flators', 'npg_qc::autoqc::role::result', 'npg_qc::autoqc::role::samtools_stats';


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2021-03-22 11:40:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:CHtNIASw5kdMTguj8RfNcw


# You can replace this text with custom code or comments, and it will be preserved on regeneration

our $VERSION = '0';

=head2 seq_component_compositions

Type: has_many

Related object: L<npg_qc::Schema::Result::SeqComponentComposition>

To simplify queries, skip SeqComposition and link directly to the linking table.

=cut

__PACKAGE__->has_many(
  'seq_component_compositions',
  'npg_qc::Schema::Result::SeqComponentComposition',
  { 'foreign.id_seq_composition' => 'self.id_seq_composition' },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head1 SYNOPSIS

=head1 DESCRIPTION

DBIx ORM result class definition for samtools_stats table in NPG QC database.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 SUBROUTINES/METHODS

=cut

=head2 set_inflated_columns

Extends set_inflated_columns method of L<DBIx::Class::Row>
to deflate (xz compress) a scalar value that goes into
the stats column.

=cut

around 'set_inflated_columns' => sub {
  my $orig = shift;
  my $self = shift;
  my $upd  = shift;
  if (exists $upd->{'stats'}) {
    $upd->{'stats'} = __PACKAGE__->compress_xz($upd->{'stats'});
  }
  return $self->$orig($upd);
};

__PACKAGE__->set_inflator4xz_compressed_scalar(qw(stats));

=head2 composition

Attribute of type npg_tracking::glossary::composition.

=cut

__PACKAGE__->meta->make_immutable;
1;
__END__

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

Copyright (C) 2015,2016,2017,2018,2019,2021 Genome Research Ltd.

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


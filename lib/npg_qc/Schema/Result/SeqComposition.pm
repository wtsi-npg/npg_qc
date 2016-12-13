
package npg_qc::Schema::Result::SeqComposition;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

##no critic(RequirePodAtEnd RequirePodLinksIncludeText ProhibitMagicNumbers ProhibitEmptyQuotes)

=head1 NAME

npg_qc::Schema::Result::SeqComposition

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

=head1 TABLE: C<seq_composition>

=cut

__PACKAGE__->table('seq_composition');

=head1 ACCESSORS

=head2 id_seq_composition

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

Auto-generated primary key

=head2 digest

  data_type: 'char'
  is_nullable: 0
  size: 64

A SHA256 hex digest of the JSON representation of the composition as defined in npg_tracking::glossary::composition

=head2 size

  data_type: 'tinyint'
  extra: {unsigned => 1}
  is_nullable: 0

Total number of components in a composition

=cut

__PACKAGE__->add_columns(
  'id_seq_composition',
  {
    data_type => 'bigint',
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  'digest',
  { data_type => 'char', is_nullable => 0, size => 64 },
  'size',
  { data_type => 'tinyint', extra => { unsigned => 1 }, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_seq_composition>

=back

=cut

__PACKAGE__->set_primary_key('id_seq_composition');

=head1 UNIQUE CONSTRAINTS

=head2 C<unq_seq_compos_d>

=over 4

=item * L</digest>

=back

=cut

__PACKAGE__->add_unique_constraint('unq_seq_compos_d', ['digest']);

=head2 C<unq_seq_compos_ps>

=over 4

=item * L</id_seq_composition>

=item * L</size>

=back

=cut

__PACKAGE__->add_unique_constraint('unq_seq_compos_ps', ['id_seq_composition', 'size']);

=head1 RELATIONS

=head2 samtools_stats

Type: has_many

Related object: L<npg_qc::Schema::Result::SamtoolsStats>

=cut

__PACKAGE__->has_many(
  'samtools_stats',
  'npg_qc::Schema::Result::SamtoolsStats',
  { 'foreign.id_seq_composition' => 'self.id_seq_composition' },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 seq_component_compositions

Type: has_many

Related object: L<npg_qc::Schema::Result::SeqComponentComposition>

=cut

__PACKAGE__->has_many(
  'seq_component_compositions',
  'npg_qc::Schema::Result::SeqComponentComposition',
  {
    'foreign.id_seq_composition' => 'self.id_seq_composition',
    'foreign.size' => 'self.size',
  },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 sequence_summaries

Type: has_many

Related object: L<npg_qc::Schema::Result::SequenceSummary>

=cut

__PACKAGE__->has_many(
  'sequence_summaries',
  'npg_qc::Schema::Result::SequenceSummary',
  { 'foreign.id_seq_composition' => 'self.id_seq_composition' },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07043 @ 2015-09-09 17:35:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:zzx4SOq+Lh95G58mYLuWWw


# You can replace this text with custom code or comments, and it will be preserved on regeneration

use npg_tracking::glossary::composition::factory;

our $VERSION = '0';

=head2 create_composition

A factory method returning a composition of illumina components. 

=cut

sub create_composition {
  my $self = shift;
  my $factory = npg_tracking::glossary::composition::factory->new();
  my $clinks = $self->seq_component_compositions();
  while (my $clink = $clinks->next()) {
    $factory->add_component($clink->seq_component()->create_component());
  }
  return $factory->create_composition();
}

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

Copyright (C) 2016 GRL

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


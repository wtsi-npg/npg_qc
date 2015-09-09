
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
  { 'foreign.id_seq_composition' => 'self.id_seq_composition' },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07043 @ 2015-09-09 16:38:07
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:cgTVxFpy8hxjjJHY1YLF0Q


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;

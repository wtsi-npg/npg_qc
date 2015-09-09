
package npg_qc::Schema::Result::SeqComponentComposition;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

##no critic(RequirePodAtEnd RequirePodLinksIncludeText ProhibitMagicNumbers ProhibitEmptyQuotes)

=head1 NAME

npg_qc::Schema::Result::SeqComponentComposition

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

=head1 TABLE: C<seq_component_composition>

=cut

__PACKAGE__->table('seq_component_composition');

=head1 ACCESSORS

=head2 id_seq_comcom

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

Auto-generated primary key

=head2 id_seq_component

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

A foreign key referencing the id_seq_component column of the seq_component table

=head2 id_seq_composition

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

A foreign key referencing the id_seq_composition column of the seq_composition table

=head2 size

  data_type: 'tinyint'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

Total number of components in a composition

=cut

__PACKAGE__->add_columns(
  'id_seq_comcom',
  {
    data_type => 'bigint',
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  'id_seq_component',
  {
    data_type => 'bigint',
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  'id_seq_composition',
  {
    data_type => 'bigint',
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  'size',
  {
    data_type => 'tinyint',
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_seq_comcom>

=back

=cut

__PACKAGE__->set_primary_key('id_seq_comcom');

=head1 UNIQUE CONSTRAINTS

=head2 C<unq_seq_comcom>

=over 4

=item * L</id_seq_component>

=item * L</id_seq_composition>

=item * L</size>

=back

=cut

__PACKAGE__->add_unique_constraint(
  'unq_seq_comcom',
  ['id_seq_component', 'id_seq_composition', 'size'],
);

=head1 RELATIONS

=head2 seq_component

Type: belongs_to

Related object: L<npg_qc::Schema::Result::SeqComponent>

=cut

__PACKAGE__->belongs_to(
  'seq_component',
  'npg_qc::Schema::Result::SeqComponent',
  { id_seq_component => 'id_seq_component' },
  { is_deferrable => 1, on_delete => 'NO ACTION', on_update => 'NO ACTION' },
);

=head2 seq_composition

Type: belongs_to

Related object: L<npg_qc::Schema::Result::SeqComposition>

=cut

__PACKAGE__->belongs_to(
  'seq_composition',
  'npg_qc::Schema::Result::SeqComposition',
  { id_seq_composition => 'id_seq_composition', size => 'size' },
  { is_deferrable => 1, on_delete => 'NO ACTION', on_update => 'NO ACTION' },
);


# Created by DBIx::Class::Schema::Loader v0.07043 @ 2015-09-09 17:35:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:YBtIODeL5JKL68rbUTrwFg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;

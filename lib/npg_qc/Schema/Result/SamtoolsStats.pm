
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
  size: 8

Filter used to produce the stats file

=head2 stats

  data_type: 'blob'
  is_nullable: 0

Compressed (gzip) samtools stats file content

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
  { data_type => 'varchar', is_nullable => 0, size => 8 },
  'stats',
  { data_type => 'blob', is_nullable => 0 },
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


# Created by DBIx::Class::Schema::Loader v0.07043 @ 2015-09-09 16:20:06
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:oJUD09t4wZx/K+H2FVaL3Q


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;

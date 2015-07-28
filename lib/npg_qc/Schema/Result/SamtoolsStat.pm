
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
__PACKAGE__->meta->make_immutable;
1;

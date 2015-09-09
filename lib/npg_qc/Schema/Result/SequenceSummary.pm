
package npg_qc::Schema::Result::SequenceSummary;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

##no critic(RequirePodAtEnd RequirePodLinksIncludeText ProhibitMagicNumbers ProhibitEmptyQuotes)

=head1 NAME

npg_qc::Schema::Result::SequenceSummary

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

=head1 TABLE: C<sequence_summary>

=cut

__PACKAGE__->table('sequence_summary');

=head1 ACCESSORS

=head2 id_sequence_summary

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

=head2 sequence_format

  data_type: 'varchar'
  is_nullable: 0
  size: 6

Sequencing file format, e.g. SAM, BAM

=head2 header

  data_type: 'text'
  is_nullable: 0

File header, excluding SQ lines, the field is searchable

=head2 seqchksum

  data_type: 'text'
  is_nullable: 0

Alignment and header independent sequence file digest, see bamseqchksum in https://github.com/wtsi-npg/biobambam, default checksum

=head2 seqchksum_sha512

  data_type: 'text'
  is_nullable: 0

Alignment and header independent sequence file digest, see bamseqchksum in https://github.com/wtsi-npg/biobambam, sha512primesums512 checksum

=head2 md5

  data_type: 'char'
  is_nullable: 0
  size: 32

md5 of the sequence file

=head2 date

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

Date the record was created

=head2 iscurrent

  data_type: 'tinyint'
  default_value: 1
  extra: {unsigned => 1}
  is_nullable: 0

Boolean flag to indicate that the record is current, defaults to 1

=cut

__PACKAGE__->add_columns(
  'id_sequence_summary',
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
  'sequence_format',
  { data_type => 'varchar', is_nullable => 0, size => 6 },
  'header',
  { data_type => 'text', is_nullable => 0 },
  'seqchksum',
  { data_type => 'text', is_nullable => 0 },
  'seqchksum_sha512',
  { data_type => 'text', is_nullable => 0 },
  'md5',
  { data_type => 'char', is_nullable => 0, size => 32 },
  'date',
  {
    data_type => 'timestamp',
    datetime_undef_if_invalid => 1,
    default_value => \'current_timestamp',
    is_nullable => 0,
  },
  'iscurrent',
  {
    data_type => 'tinyint',
    default_value => 1,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_sequence_summary>

=back

=cut

__PACKAGE__->set_primary_key('id_sequence_summary');

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
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:MrpEnQA+MJNLP6UhtZH4oA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;


package npg_qc::Schema::Result::MqcLibraryOutcomeDict;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

##no critic(RequirePodAtEnd RequirePodLinksIncludeText ProhibitMagicNumbers ProhibitEmptyQuotes)

=head1 NAME

npg_qc::Schema::Result::MqcLibraryOutcomeDict - Dictionary table for library manual qc

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

=head1 TABLE: C<mqc_library_outcome_dict>

=cut

__PACKAGE__->table('mqc_library_outcome_dict');

=head1 ACCESSORS

=head2 id_mqc_library_outcome

  data_type: 'smallint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 short_desc

  data_type: 'varchar'
  is_nullable: 0
  size: 50

=head2 long_desc

  data_type: 'varchar'
  is_nullable: 1
  size: 150

=head2 iscurrent

  data_type: 'tinyint'
  is_nullable: 1

Catalog value still in use.

=head2 isvisible

  data_type: 'tinyint'
  is_nullable: 1

Is it visible in UI

=cut

__PACKAGE__->add_columns(
  'id_mqc_library_outcome',
  {
    data_type => 'smallint',
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  'short_desc',
  { data_type => 'varchar', is_nullable => 0, size => 50 },
  'long_desc',
  { data_type => 'varchar', is_nullable => 1, size => 150 },
  'iscurrent',
  { data_type => 'tinyint', is_nullable => 1 },
  'isvisible',
  { data_type => 'tinyint', is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_mqc_library_outcome>

=back

=cut

__PACKAGE__->set_primary_key('id_mqc_library_outcome');

=head1 RELATIONS

=head2 mqc_library_outcome_ents

Type: has_many

Related object: L<npg_qc::Schema::Result::MqcLibraryOutcomeEnt>

=cut

__PACKAGE__->has_many(
  'mqc_library_outcome_ents',
  'npg_qc::Schema::Result::MqcLibraryOutcomeEnt',
  {
    'foreign.id_mqc_library_outcome' => 'self.id_mqc_library_outcome',
  },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 mqc_library_outcome_hists

Type: has_many

Related object: L<npg_qc::Schema::Result::MqcLibraryOutcomeHist>

=cut

__PACKAGE__->has_many(
  'mqc_library_outcome_hists',
  'npg_qc::Schema::Result::MqcLibraryOutcomeHist',
  {
    'foreign.id_mqc_library_outcome' => 'self.id_mqc_library_outcome',
  },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07043 @ 2015-10-13 12:18:54
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:yqpekS7GDlTP/xbmO95j5g


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;

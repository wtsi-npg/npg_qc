
package npg_qc::Schema::Result::MqcLibraryOutcomeHist;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

##no critic(RequirePodAtEnd RequirePodLinksIncludeText ProhibitMagicNumbers ProhibitEmptyQuotes)

=head1 NAME

npg_qc::Schema::Result::MqcLibraryOutcomeHist

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

=head1 TABLE: C<mqc_library_outcome_hist>

=cut

__PACKAGE__->table('mqc_library_outcome_hist');

=head1 ACCESSORS

=head2 id_mqc_library_outcome_hist

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 id_run

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 position

  data_type: 'tinyint'
  extra: {unsigned => 1}
  is_nullable: 0

Lane

=head2 tag_index

  data_type: 'bigint'
  is_nullable: 0

=head2 id_mqc_outcome

  data_type: 'smallint'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 username

  data_type: 'char'
  is_nullable: 1
  size: 128

Web interface username

=head2 last_modified

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

=head2 modified_by

  data_type: 'char'
  is_nullable: 1
  size: 128

Last user to modify the row

=cut

__PACKAGE__->add_columns(
  'id_mqc_library_outcome_hist',
  {
    data_type => 'bigint',
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  'id_run',
  { data_type => 'bigint', extra => { unsigned => 1 }, is_nullable => 0 },
  'position',
  { data_type => 'tinyint', extra => { unsigned => 1 }, is_nullable => 0 },
  'tag_index',
  { data_type => 'bigint', is_nullable => 0 },
  'id_mqc_outcome',
  { data_type => 'smallint', extra => { unsigned => 1 }, is_nullable => 0 },
  'username',
  { data_type => 'char', is_nullable => 1, size => 128 },
  'last_modified',
  {
    data_type => 'timestamp',
    datetime_undef_if_invalid => 1,
    default_value => \'current_timestamp',
    is_nullable => 0,
  },
  'modified_by',
  { data_type => 'char', is_nullable => 1, size => 128 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_mqc_library_outcome_hist>

=back

=cut

__PACKAGE__->set_primary_key('id_mqc_library_outcome_hist');


# Created by DBIx::Class::Schema::Loader v0.07043 @ 2015-08-21 18:34:16
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:uTrXz9lS+rqAJNgq34Q5Kg

our $VERSION = '0';

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;

1;

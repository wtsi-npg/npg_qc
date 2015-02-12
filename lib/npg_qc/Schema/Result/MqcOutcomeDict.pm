
package npg_qc::Schema::Result::MqcOutcomeDict;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

##no critic(RequirePodAtEnd RequirePodLinksIncludeText ProhibitMagicNumbers ProhibitEmptyQuotes)

=head1 NAME

npg_qc::Schema::Result::MqcOutcomeDict

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

=item * L<DBIx::Class::InflateColumn::Serializer>

=back

=cut

__PACKAGE__->load_components('InflateColumn::DateTime', 'InflateColumn::Serializer');

=head1 TABLE: C<mqc_outcome_dict>

=cut

__PACKAGE__->table('mqc_outcome_dict');

=head1 ACCESSORS

=head2 id_mqc_outcome

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
  'id_mqc_outcome',
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

=item * L</id_mqc_outcome>

=back

=cut

__PACKAGE__->set_primary_key('id_mqc_outcome');

=head1 RELATIONS

=head2 mqc_outcome_ents

Type: has_many

Related object: L<npg_qc::Schema::Result::MqcOutcomeEnt>

=cut

__PACKAGE__->has_many(
  'mqc_outcome_ents',
  'npg_qc::Schema::Result::MqcOutcomeEnt',
  { 'foreign.id_mqc_outcome' => 'self.id_mqc_outcome' },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 mqc_outcome_hists

Type: has_many

Related object: L<npg_qc::Schema::Result::MqcOutcomeHist>

=cut

__PACKAGE__->has_many(
  'mqc_outcome_hists',
  'npg_qc::Schema::Result::MqcOutcomeHist',
  { 'foreign.id_mqc_outcome' => 'self.id_mqc_outcome' },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2015-02-05 17:00:22
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:sEw0vDs0wFvwtoByLd4huA

our $VERSION = '0';

=head1 Methods

=head2 is_final_outcome Utility method to check if the outcome is considered final.

=cut

sub is_final_outcome {
  my $self = shift;
  if($self->short_desc =~ m{final}ism) { #The short description includes the word final.
    return 1;
  } else {
    return 0;
  }
}

__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 SYNOPSIS

=head1 DESCRIPTION

Catalog for manual MQC statuses.

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

Jaime Tovar <lt>jmtc@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 GRL, by Jaime Tovar

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

package npg_qc::Schema::Result::UqcOutcomeDict;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

##no critic(RequirePodAtEnd RequirePodLinksIncludeText ProhibitMagicNumbers ProhibitEmptyQuotes)

=head1 NAME

npg_qc::Schema::Result::UqcOutcomeDict - Dictionary table for utility qc outcomes

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

=head1 TABLE: C<uqc_outcome_dict>

=cut

__PACKAGE__->table('uqc_outcome_dict');

=head1 ACCESSORS

=head2 id_uqc_outcome

  data_type: 'smallint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 short_desc

  data_type: 'varchar'
  is_nullable: 0
  size: 50

Short description of the uqc_outcome

=head2 long_desc

  data_type: 'varchar'
  is_nullable: 1
  size: 150

Long description of the uqc_outcome

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
  'id_uqc_outcome',
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

=item * L</id_uqc_outcome>

=back

=cut

__PACKAGE__->set_primary_key('id_uqc_outcome');

=head1 UNIQUE CONSTRAINTS

=head2 C<unique_uqc_outcome_desc>

=over 4

=item * L</short_desc>

=back

=cut

__PACKAGE__->add_unique_constraint('unique_uqc_outcome_desc', ['short_desc']);

=head1 RELATIONS

=head2 uqc_outcome_ents

Type: has_many

Related object: L<npg_qc::Schema::Result::UqcOutcomeEnt>

=cut

__PACKAGE__->has_many(
  'uqc_outcome_ents',
  'npg_qc::Schema::Result::UqcOutcomeEnt',
  { 'foreign.id_uqc_outcome' => 'self.id_uqc_outcome' },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 uqc_outcome_hists

Type: has_many

Related object: L<npg_qc::Schema::Result::UqcOutcomeHist>

=cut

__PACKAGE__->has_many(
  'uqc_outcome_hists',
  'npg_qc::Schema::Result::UqcOutcomeHist',
  { 'foreign.id_uqc_outcome' => 'self.id_uqc_outcome' },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07047 @ 2017-10-10 16:47:36
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:iP98lfhdUgugcrUNXjX1xQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
with qw/npg_qc::Schema::Mqc::OutcomeDict/ => { -excludes => 'matching_final_short_desc' };


our $VERSION = '0';

__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 SYNOPSIS

=head1 DESCRIPTION

Catalog for users UQC statuses.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 SUBROUTINES/METHODS

=cut

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item Moose

=item namespace::autoclean

=item MooseX::NonMoose

=item MooseX::MarkAsMethods

=item DBIx::Class::Core

=item npg_qc::Schema::Mqc::OutcomeDict

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Manuel Carbajo <lt>mc23@sanger.ac.ukE<gt>
Jaime Tovar <lt>jmtc@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2017 GRL Genome Research Limited

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



package npg_qc::Schema::Result::Review;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

##no critic(RequirePodAtEnd RequirePodLinksIncludeText ProhibitMagicNumbers ProhibitEmptyQuotes)

=head1 NAME

npg_qc::Schema::Result::Review

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

=item * L<DBIx::Class::InflateColumn::Serializer>

=back

=cut

__PACKAGE__->load_components('InflateColumn::DateTime', 'InflateColumn::Serializer');

=head1 TABLE: C<review>

=cut

__PACKAGE__->table('review');

=head1 ACCESSORS

=head2 id_review

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

=head2 library_type

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 evaluation_results

  data_type: 'text'
  is_nullable: 1

=head2 criteria

  data_type: 'text'
  is_nullable: 1

=head2 criteria_md5

  data_type: 'char'
  is_nullable: 1
  size: 32

=head2 qc_outcome

  data_type: 'varchar'
  is_nullable: 1
  size: 256

=head2 pass

  data_type: 'tinyint'
  is_nullable: 1

=head2 path

  data_type: 'varchar'
  is_nullable: 1
  size: 256

=head2 comments

  data_type: 'text'
  is_nullable: 1

=head2 info

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  'id_review',
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
  'library_type',
  { data_type => 'varchar', is_nullable => 1, size => 100 },
  'evaluation_results',
  { data_type => 'text', is_nullable => 1 },
  'criteria',
  { data_type => 'text', is_nullable => 1 },
  'criteria_md5',
  { data_type => 'char', is_nullable => 1, size => 32 },
  'qc_outcome',
  { data_type => 'varchar', is_nullable => 1, size => 256 },
  'pass',
  { data_type => 'tinyint', is_nullable => 1 },
  'path',
  { data_type => 'varchar', is_nullable => 1, size => 256 },
  'comments',
  { data_type => 'text', is_nullable => 1 },
  'info',
  { data_type => 'text', is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_review>

=back

=cut

__PACKAGE__->set_primary_key('id_review');

=head1 UNIQUE CONSTRAINTS

=head2 C<review_id_compos_uniq>

=over 4

=item * L</id_seq_composition>

=back

=cut

__PACKAGE__->add_unique_constraint('review_id_compos_uniq', ['id_seq_composition']);

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

=head1 L<Moose> ROLES APPLIED

=over 4

=item * L<npg_qc::Schema::Composition>

=item * L<npg_qc::Schema::Flators>

=item * L<npg_qc::autoqc::role::result>

=back

=cut


with 'npg_qc::Schema::Composition', 'npg_qc::Schema::Flators', 'npg_qc::autoqc::role::result';


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2019-06-04 14:47:17
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:DeTa7xq61g7m5KPDAyzGyQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration

use Carp;
use Try::Tiny;
use WTSI::DNAP::Utilities::Timestamp qw/parse_timestamp/;

our $VERSION = '0';

# Set inflation and deflation for non-scalar result object fields.
__PACKAGE__->set_flators4non_scalar( qw/ evaluation_results
                                         criteria qc_outcome
                                         info / );

=head1 SYNOPSIS

=head1 DESCRIPTION

DBIx class for the review database table.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 RELATIONS

=head2 mqc_outcome_ent

Note that relationship's attributes starting with 'cascade_'
are explicitly disabled. By default, DBIx::Class cascades updates
across has_one and might_have. See documentation in
L<DBIx::Class::Relationship::Base>.

Type: might_have
Related object: L<npg_qc::Schema::Result::MqcLibraryOutcomeEnt>

=cut

__PACKAGE__->might_have (
  'mqc_outcome_ent',
  'npg_qc::Schema::Result::MqcLibraryOutcomeEnt',
  { 'foreign.id_seq_composition' => 'self.id_seq_composition' },
  {
    is_deferrable => 1,
    join_type     => 'LEFT',
    on_delete     => 'NO ACTION',
    on_update     => 'NO ACTION',
    cascade_copy   => 0,
    cascade_update => 0,
    cascade_delete => 0,
  },
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

=head1 SUBROUTINES/METHODS

=head2 insert

=head2 update

Both update and insert methods are modified.

If the qc outcome attribute is defined we will try saving this
outcome as a library mqc outcome.

If a final library mqc outcome already exists for this product
and we are trying to save a different final qc outcome, neither
the review nor the mqc records are created and an error is raised.

Saving a review result with a preliminary outcome should always
create or update a review row, but a library mqc outcome for the
product will only be updated if there is no existing final mqc
outcome.

=cut

around [qw/update insert/] => sub {
  my $orig     = shift;
  my $self     = shift;
  my $new_data = shift;

  #####
  # Where are the values we are going to save to the database?
  # In case of an insert they are already assigned to $self,
  # in case of an update they are passed as an argument hash.
  my $data = {};
  foreach my $name (qw/evaluation_results
                       library_type
                       criteria
                       qc_outcome/) {
    $data->{$name} = $new_data ? $new_data->{$name} : $self->$name;
  }

  ##### 
  # Do not accept half-baked results, ie if we have evaluation
  # results, we should also have library type and criteria.
  if ($data->{'evaluation_results'} and keys %{$data->{'evaluation_results'}}) {
    foreach my $name (qw/library_type criteria/) {
      my $value = $data->{$name};
      my $m = "Evaluation results present, but $name absent";
      $value or croak $m;
      ((not ref $value) or keys %{$value}) or croak $m;
    }
  }

  #####
  # If appropriate, create a new mqc outcome or update an existing one.
  # We do not consider an absent mqc outcome to be an error.
  my %qc_outcome = %{$data->{'qc_outcome'} || {}};
  if (keys %qc_outcome) {
    $self->_save_qc_outcome(\%qc_outcome);
  }

  #####
  # To avoid discrepancies between criteria hash and its signature string,
  # recompute and reset criteria_md5.
  my $md5 = $self->generate_checksum4data($data->{'criteria'});
  if ($new_data) {
    $new_data->{'criteria_md5'} = $md5;
  } else {
    $self->set_column('criteria_md5', $md5);
  }

  # Perform the original action.
  return $self->$orig($new_data, @_);
};

sub _save_qc_outcome {
  my ($self, $qc_outcome) = @_;
  #####
  # Find an existing mqc outcome in the outcomes table or
  # create a new object. 
  my $mqc_row = $self->find_or_new_related('mqc_outcome_ent',
    {'id_seq_composition' => $self->id_seq_composition});

  my $update_or_create = 1;
  try {
    $update_or_create = $mqc_row->valid4update($qc_outcome);
  } catch {
    my $err = $_;
    #####
    # If the outcome is preliminary and a final one already exists,
    # no mqc update and no error. We might be archiving post-manual QC.
    if (($err =~ /Final\ outcome\ cannot\ be\ updated/xms) and
        (not $mqc_row->mqc_outcome
         ->is_final_outcome_description($qc_outcome->{'mqc_outcome'}))) {
      $update_or_create = 0;
    } else {
      croak "Not saving review result. $err for " . $mqc_row->composition->freeze();
    }
  };

  if ($update_or_create) {
    my $app = delete $qc_outcome->{'username'};
    $qc_outcome->{'last_modified'} =
      parse_timestamp(delete $qc_outcome->{'timestamp'});
    my $user = $ENV{'USER'};
    $user ||= $app;
    $mqc_row->update_outcome($qc_outcome, $user, $app);
  }

  return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

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

=item Carp

=item Try::Tiny

=item WTSI::DNAP::Utilities::Timestamp

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2019,2020 Genome Research Ltd.

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

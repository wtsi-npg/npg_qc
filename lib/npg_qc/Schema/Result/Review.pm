
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

=head2 id_review_criteria

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 1

An optional foreign key referencing the id_review_criteria column of the review_criteria table

=head2 evaluation_results

  data_type: 'text'
  is_nullable: 1

A serialized hash mapping individual expressions to their evaluation results

=head2 qc_outcome

  data_type: 'varchar'
  is_nullable: 1
  size: 256

A serialized hash representing the manual QC outcome

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
  'id_review_criteria',
  {
    data_type => 'bigint',
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 1,
  },
  'evaluation_results',
  { data_type => 'text', is_nullable => 1 },
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

=head2 review_criteria

Type: belongs_to

Related object: L<npg_qc::Schema::Result::ReviewCriteria>

=cut

__PACKAGE__->belongs_to(
  'review_criteria',
  'npg_qc::Schema::Result::ReviewCriteria',
  { id_review_criteria => 'id_review_criteria' },
  {
    is_deferrable => 1,
    join_type     => 'LEFT',
    on_delete     => 'NO ACTION',
    on_update     => 'NO ACTION',
  },
);

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


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2019-06-11 10:16:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:rdI71zn+2PzK31y4AgsBXg


# You can replace this text with custom code or comments, and it will be preserved on regeneration

use Carp;
use Try::Tiny;
use Readonly;
use List::MoreUtils qw/any/;
use Digest::MD5 qw/md5_hex/;
use JSON::XS;

use WTSI::DNAP::Utilities::Timestamp qw/parse_timestamp/;

our $VERSION = '0';

Readonly::Array my @CRITERIA_DICT_COLUMNS => qw/library_type criteria/;

# Set inflation and deflation for non-scalar result object fields.
__PACKAGE__->set_flators4non_scalar( qw/ evaluation_results
                                         qc_outcome
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

=head2 BUILDARGS

This method runs before the default constructor. We use this hook
to address a mismatch between the columns of this table and the 
attributes of the npg_qc::autoqc::results::review class. The
white-listed attributes that do not have corresponding columns
are deleted from the data passed to teh constructor and are
temporarily saved as additional keys in the info attribute/column.

The original Moose method is run at the end of this method.

=cut

around BUILDARGS => sub {
  my $orig  = shift;
  my $class = shift;
  my $data  = shift; #the data passed to the constructor

  for my $attr (@CRITERIA_DICT_COLUMNS) {
    $data->{'info'}->{$attr} = delete $data->{$attr};
  }

  return $class->$orig($data);
};

=head2 library_type

=head2 criteria

=cut

#####
# library_type and criteria accessors are available in 
# npg_qc::autoqc::results::review class, so we'll create them
# here as well.
foreach my $name (@CRITERIA_DICT_COLUMNS) {
  __PACKAGE__->meta()->add_method(
    $name => sub {
      my $self = shift;
      my $result;
      try {
        $result = $self->review_criteria()->$name;
      };
      return $result;
    }
  );
}

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

The evaluation criteria are saved to a separate dictionary-like
table. If the result has evaluation outcomes, it is also expected to
have the library type and evaluation criteria defined; their absence
causes an error. If, however, the autoqc result object has hardly
any attributes defined, which would be the case when the can_run
method of the review check object returns false, it can be saved.
This is done in order to avoid errors when batch-saving autoqc
results.

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

    my $remapped = any { $_ eq $name} @CRITERIA_DICT_COLUMNS;
    my $value;
    if ( $new_data) {
      $value = $remapped? delete $new_data->{$name} : $new_data->{$name};
    } else {
      $value = $remapped? delete $self->info->{$name} : $self->$name;
    }
    $data->{$name} = $value;
  }

  ##### 
  # Do not accept half-baked results, ie if we have evaluation
  # results, we should also have library type and criteria.
  my $eval_done = (defined $data->{'evaluation_results'}) &&
                  (scalar keys %{$data->{'evaluation_results'}});
  if ($eval_done) {
    foreach my $name (@CRITERIA_DICT_COLUMNS) {
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
    # If this errors, no records are created, which is what we want.
    $self->_save_qc_outcome(\%qc_outcome);
  }

  #####
  # If evaluation has been performed, we have to record the criteria.
  # Create a new entry for the criteria or map the result's criteria to
  # an existing criteria record.
  if ($eval_done) {
    my $ch = {};
    foreach my $name (@CRITERIA_DICT_COLUMNS) {
      $ch->{$name} = delete $data->{$name};
    }
    $ch->{'checksum'} = md5_hex(JSON::XS->new()->canonical(1)->encode($ch->{'criteria'}));
    my $fk_column_name = 'id_review_criteria';
    # Whether a related object exists is irrelevant since we might need
    # to assign a different one.
    my $criteria_row = $self->result_source()->schema()
                            ->resultset('ReviewCriteria')
                            ->find_or_new($ch);
    if (!$criteria_row ->in_storage) {
      $criteria_row->set_inflated_columns($ch)->insert();
    }
    my $fk_value = $criteria_row->$fk_column_name;
    if ($new_data) {
      # May be overwrite the criteria foreign key.
      $new_data->{$fk_column_name} = $fk_value;
    } else {
      # Set it for the new record.
      $self->set_column($fk_column_name, $fk_value);
    }
  }

  #####
  # Perform the original action, ie create the review record.
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

=item Readonly

=item List::MoreUtils

=item Digest::MD5

=item JSON::XS

=item WTSI::DNAP::Utilities::Timestamp

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2019 GRL

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

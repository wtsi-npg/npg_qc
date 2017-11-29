package npg_qc::mqc::outcomes;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use Readonly;
use List::MoreUtils qw/ any none uniq /;
use Carp;
use Try::Tiny;

use npg_qc::mqc::outcomes::keys qw/$LIB_OUTCOMES
                                   $SEQ_OUTCOMES
                                   $QC_OUTCOME
                                   $UQC_OUTCOMES
                                   $UQC_OUTCOME/;

use npg_tracking::glossary::composition::factory::rpt_list;

our $VERSION = '0';

Readonly::Scalar my $SEQ_RS_NAME   => 'MqcOutcomeEnt';
Readonly::Scalar my $LIB_RS_NAME   => 'MqcLibraryOutcomeEnt';
Readonly::Scalar my $UQC_RS_NAME   => 'UqcOutcomeEnt';
Readonly::Array  my @OUTCOME_TYPES => ($LIB_OUTCOMES, $SEQ_OUTCOMES, $UQC_OUTCOMES);

has 'qc_schema' => (
  isa        => 'npg_qc::Schema',
  is         => 'ro',
  required   => 1,
);

sub get {
  my ($self, $qlist) = @_;

  if (!$qlist || (ref $qlist ne 'ARRAY')) {
    croak q[Input is missing or is not an array];
  }

  my @lib_outcomes = ();
  my @seq_outcomes = ();
  my @uqc_outcomes = ();

  my @mcompcompositions = ();
  my $single_components = {};

  foreach my $rpt_list ( uniq @{$qlist} ) {
    my $composition = _rpt_list2composition($rpt_list);
    if ($composition->num_components == 1) {
      my $c = $composition->get_component(0);
      $single_components->{$c->id_run()}->{$c->position()} = 1;
    } else {
      push @mcompcompositions, $composition;
    }
  }

  # Get outcomes for single-component compositions
  foreach my $id_run (keys %{$single_components}) {
    my $q = {'id_run'   => $id_run,
             'position' => [keys %{$single_components->{$id_run}}]};
    push @lib_outcomes, $self->_create_query($LIB_RS_NAME, $QC_OUTCOME,  $q)->all();
    push @seq_outcomes, $self->_create_query($SEQ_RS_NAME, $QC_OUTCOME,  $q)->all();
    push @uqc_outcomes, $self->_create_query($UQC_RS_NAME, $UQC_OUTCOME, $q)->all();
  }

  # Get outcomes for multi-component compositions
  if (@mcompcompositions) {
    push @lib_outcomes, $self->_create_query4compositions(
                               $LIB_RS_NAME, $QC_OUTCOME,  \@mcompcompositions)->all();
    push @seq_outcomes, $self->_create_query4compositions(
                               $SEQ_RS_NAME, $QC_OUTCOME,  \@mcompcompositions)->all();
    push @uqc_outcomes, $self->_create_query4compositions(
                               $UQC_RS_NAME, $UQC_OUTCOME, \@mcompcompositions)->all();
  }

  my $h = {};
  $h->{$LIB_OUTCOMES} = _map_outcomes($QC_OUTCOME,  \@lib_outcomes);
  $h->{$SEQ_OUTCOMES} = _map_outcomes($QC_OUTCOME,  \@seq_outcomes);
  $h->{$UQC_OUTCOMES} = _map_outcomes($UQC_OUTCOME, \@uqc_outcomes);

  return $h;
}

sub save {
  my ($self, $outcomes, $username, $lane_info) = @_;

  if (!$outcomes || (ref $outcomes ne 'HASH')) {
    croak q[Outcomes hash is required];
  }
  if (!$username) {
    croak q[Username is required];
  }
  if ($outcomes->{$UQC_OUTCOMES}) {
    croak 'Saving uqc outcomes is not yet implemented';
  }
  if ($outcomes->{$SEQ_OUTCOMES} && !$lane_info) {
    croak q[Tag indices for lanes are required];
  }
  if ($lane_info && (ref $lane_info ne 'HASH')) {
    croak q[Tag indices for lanes should be a hash ref];
  }

  my @outcome_types = keys %{$outcomes};
  if (!@outcome_types) {
    croak 'No data to save',
  }
  if (any { my $temp = $_; none {$temp eq $_} @OUTCOME_TYPES } @outcome_types) {
    croak 'One of outcome types is unknown';
  }

  $self->_save_outcomes($outcomes, $username, $lane_info);

  return $self->get( [map {keys %{$_}} values %{$outcomes}] );
}

sub _map_outcomes {
  my ($rel_name, $outcomes) = @_;
  my $map = {};
  foreach my $o (@{$outcomes}) {
    $map->{$o->composition()->freeze2rpt()} =
      { $rel_name => $o->description() };
  }
  return $map;
}

sub _save_outcomes {
  my ($self, $outcomes, $username, $lane_info) = @_;

  my $actions = sub {
    foreach my $outcome_type ( @OUTCOME_TYPES ) {
      my $outcomes4type = $outcomes->{$outcome_type} || {};
      if (ref $outcomes4type ne 'HASH') {
        croak qq[Outcome for $outcome_type is not a hash ref];
      }
      foreach my $key ( keys %{$outcomes4type} ) {
        my $o =  $outcomes4type->{$key};
        if (ref $o ne 'HASH') {
          croak q[Outcome is not defined or is not a hash ref];
        }
        my $outcome_description = $o->{$QC_OUTCOME};
        if (!$outcome_description) {
          croak qq[Outcome description is missing for $key];
        }

        try {
          my $composition_obj = _rpt_list2composition($key);
          if ($composition_obj->num_components > 1) {
            croak 'Saving outcomes for multi-component compositions is not yet implemented';
          }
          my $outcome_ent = $self->_find_or_new_outcome($outcome_type, $composition_obj);
          if ($self->_valid4update($outcome_ent, $outcome_description)) {
            $outcome_ent->update_outcome($outcome_description, $username);
            if ($outcome_type eq $SEQ_OUTCOMES && $outcome_ent->has_final_outcome) {
              my $component = $composition_obj->get_component(0);
              my @lib_outcomes = $self->_create_query(
                $LIB_RS_NAME, $QC_OUTCOME,
                {'id_run' => $component->id_run, 'position' => $component->position}
                                                     )->all();
              $self->_validate_library_outcomes($outcome_ent, \@lib_outcomes, $lane_info->{$key});
              $self->_finalise_library_outcomes(\@lib_outcomes, $username);
            }
          }
        } catch {
          croak qq[Error saving '$outcome_description' for $key - $_];
        };
      }
    }
  };

  $self->qc_schema->txn_do($actions);
  return;
}

sub _create_query {
  my ($self, $rsname, $dict_rel_name, $query) = @_;
  my $db_query = $self->qc_schema()->resultset($rsname)
                                   ->search({}, {'join' => $dict_rel_name})
                                   ->search_autoqc($query, 1);
  return $db_query;
}

sub _create_query4compositions {
  my ($self, $rsname, $dict_rel_name, $compositions) = @_;
  my $db_query = $self->qc_schema()->resultset($rsname)
                                   ->search({}, {'join' => $dict_rel_name})
                                   ->search_via_composition($compositions);
  return $db_query;
}

sub _find_or_new_outcome {
  my ($self, $outcome_type, $composition_obj) = @_;

  if (!$outcome_type || !$composition_obj) {
    croak q[Two arguments required: outcome entity type string and composition object];
  }
  if ( none {$_ eq $outcome_type} @OUTCOME_TYPES ) {
    croak qq[Unknown outcome entity type '$outcome_type'];
  }

  my $rs_name = $outcome_type eq $LIB_OUTCOMES ? $LIB_RS_NAME : $SEQ_RS_NAME;
  my $rs = $self->qc_schema()->resultset($rs_name);

  my $seq_composition = $rs->find_or_create_seq_composition($composition_obj);
  my $q = {'id_seq_composition' => $seq_composition->id_seq_composition()};
  my $rs_found = $rs->search_autoqc($q);
  my $result = $rs_found->next;
  if (!$result) {
    # Create result object in memory.
    if ($composition_obj->num_components() == 1) {
      my %columns = map { $_ => 1 } $rs->result_source()->columns();
      if (exists $columns{'id_run'}) {
        my $component = $composition_obj->get_component(0);
        $q->{'id_run'}   = $component->id_run();
        $q->{'position'} = $component->position();
        if (defined $component->tag_index()) {
          if (exists $columns{'tag_index'}) {
            $q->{'tag_index'} = $component->tag_index();
          } else {
            croak qq[Defined tag index value is incompatible with outcome type $outcome_type];
          }
        }
      }
    }
    $result=$rs->new_result($q);
  }

  return $result;
}

sub _valid4update {
  my ($self, $row, $outcome_desc) = @_;
  if ($row->in_storage) {
    if ($row->description() eq $outcome_desc) {
      return 0;
    } elsif ($row->has_final_outcome()) {
      croak q[Final outcome cannot be updated];
    }
  }
  return 1;
}

sub _rpt_list2composition {
  my $rpt_list = shift;
  return npg_tracking::glossary::composition::factory::rpt_list
         ->new(rpt_list => $rpt_list)->create_composition();
}

sub _finalise_library_outcomes {
  my ($self, $rows, $username) = @_;

  foreach my $row (@{$rows}) {
    my $new_outcome = $row->mqc_outcome->matching_final_short_desc();
    if (!$new_outcome) { # Unlikely to happen
      croak 'No matching final outcome returned';
    }
    if ($self->_valid4update($row, $new_outcome)) {
      $row->update_outcome($new_outcome, $username);
    }
  }

  return;
}

sub _validate_library_outcomes {
  my ($self, $seq_outcome_ent, $lib_outcomes, $tag_list) = @_;

  if (!$tag_list) {
    croak q[List of known tag indexes is required for validation];
  }
  my %tag_counts = map { $_ => 1 } @{$tag_list};

  my $num_undecided = 0;
  for my $lo (@{$lib_outcomes}) {
    if ($lo->is_undecided) {
      $num_undecided++;
    }
    if (defined $lo->tag_index) {
      $tag_counts{$lo->tag_index}++;
    }
  }

  if ($seq_outcome_ent->has_final_outcome && any { $_ == 1 } values %tag_counts) {
    croak q[Mismatch between known tag indices and available library outcomes];
  }
  if ($seq_outcome_ent->is_accepted && $num_undecided) {
    croak q[Sequencing passed, cannot have undecided lib outcomes];
  } elsif ($seq_outcome_ent->is_rejected &&
           $num_undecided != scalar @{$lib_outcomes}) {
    croak q[Sequencing failed, all library outcomes should be undecided];
  }

  return;
}

__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

npg_qc::mqc::outcomes

=head1 SYNOPSIS

  my $o = npg_qc::mqc::outcomes->new(qc_schema  => $qc_schema);
  $o->get($data_array);
  $o->save($data_array, $username, $lane_info);

=head1 DESCRIPTION

Helper object for operations on QC outcomes (retrieval and saving).

=head1 SUBROUTINES/METHODS

=head2 qc_schema

DBIx npg qc schema object, required attribute.

=head2 get

Takes an array of rpt list strings as an argument.

Returns simple representations of rows hashed first on three type of
outcomes: 'lib' for library outcomes, 'seq' for sequencing outcomes
and 'uqc' for the user utility outcomes check, and then on rpt list string keys.

  use Data::Dumper;

  print Dumper $obj->get([qw(5:3:7)]);
  $VAR1 = {
    'lib' => {'5:3:7' => {'mqc_outcome' => 'Undecided final'}},
    'seq' => {'5:3'   => {'mqc_outcome' => 'Accepted final'}}
    'uqc' => {'5:3:7' => {'mqc_outcome' => 'Rejected'}}
          };

  print Dumper $obj->get([qw(5:3)]);
  $VAR1 = {
    'lib' => {'5:3:7' => {'mqc_outcome' => 'Undecided final'}},
    'seq' => {'5:3'   => {'mqc_outcome' => 'Accepted final'}}
    'uqc' => {'5:3:7' => {'mqc_outcome' => 'Rejected'}}
          };

If an rpt list represents a single-component composition, all level outcomes
are returned, whether the query was for a lane or plex-level result. 

If an rpt list represents a multi-component composition, the result returned
is exactly for the entity represented by this composition.

=head2 save

First argument - a data structure identical to the one returned by the get method.
Either top level lib or seq or both entries should be defined. The information in the
datastructure is used to create/update qc outcomes tables.

Second argument - username. No validation is performed.

Third argument - a hash reference where lane-level rpt keys are mapped to arrays of
tag indexes for a lane. The array can be empty. The arrays of tag indexes are used
for validating library qc outcomes when a fanal outcome for a lane is saved.
Library outcomes for all tag indexes present in the array should be available. Outcomes
for any other tag indexes should not be present.

All arguments are required.

The method returns the data identical to the return value of the get method for the
entities specifies in the first argument.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item namespace::autoclean

=item Readonly

=item List::MoreUtils

=item Carp

=item Try::Tiny

=item npg_tracking::glossary::composition::factory::rpt_list

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2017 GRL

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

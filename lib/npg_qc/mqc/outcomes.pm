package npg_qc::mqc::outcomes;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use Readonly;
use List::MoreUtils qw/ any none /;
use Carp;
use Try::Tiny;

use npg_qc::mqc::outcomes::keys qw/$LIB_OUTCOMES $SEQ_OUTCOMES $QC_OUTCOME/;
use npg_tracking::glossary::rpt;
use npg_tracking::glossary::composition::factory::rpt_list;

our $VERSION = '0';

Readonly::Scalar my $SEQ_RS_NAME => 'MqcOutcomeEnt';
Readonly::Scalar my $LIB_RS_NAME => 'MqcLibraryOutcomeEnt';
Readonly::Scalar my $IDRK        => 'id_run';
Readonly::Scalar my $PK          => 'position';
Readonly::Scalar my $TIK         => 'tag_index';
Readonly::Array  my @OUTCOME_TYPES => ($LIB_OUTCOMES, $SEQ_OUTCOMES);

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

  my $hashed_queries = {};
  foreach my $q ( @{$qlist} ) {
    if (!defined $q->{$IDRK} || !defined $q->{$PK}) {
      croak qq[Both '$IDRK' and '$PK' keys should be defined];
    }
    push @{$hashed_queries->{$q->{$IDRK}}->{$q->{$PK}}},
      defined $q->{$TIK} ? $q->{$TIK} : undef;
  }

  my @lib_outcomes = ();
  my @seq_outcomes = ();

  foreach my $id_run ( keys %{$hashed_queries} ) {

    my @positions = keys %{$hashed_queries->{$id_run}};

    foreach my $p ( @positions ) {
      my @tags = @{$hashed_queries->{$id_run}->{$p}};
      my $query = {$IDRK => $id_run, $PK => $p};
      # Either get lib outcomes for a selection of tag indices or
      # all lib outcomes for a lane.
      if ( none { !defined } @tags ) {
        $query->{$TIK} = \@tags;
      }
      push @lib_outcomes, $self->_create_query($LIB_RS_NAME, $query)->all();
    }

    # Get seq outcomes for a lane.
    my $q = {$IDRK => $id_run, $PK => \@positions};
    push @seq_outcomes, $self->_create_query($SEQ_RS_NAME, $q)->all();
  }

  my $h = {};
  $h->{$LIB_OUTCOMES} = _map_outcomes(\@lib_outcomes);
  $h->{$SEQ_OUTCOMES} = _map_outcomes(\@seq_outcomes);

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
  if ($outcomes->{$SEQ_OUTCOMES} && !$lane_info) {
    croak q[Tag indices for lanes are required];
  }
  if ($lane_info && (ref $lane_info ne 'HASH')) {
    croak q[Tag indices for lanes should be a hash ref];
  }

  if (scalar(map { keys %{$outcomes->{$_}} }
      grep { ref $outcomes->{$_} eq 'HASH'} @OUTCOME_TYPES) == 0) {
    croak q[No data to save];
  }

  my $queries = $self->_save_outcomes($outcomes, $username, $lane_info);
  return $self->get($queries);
}

sub _map_outcomes {
  my $outcomes = shift;
  my $map = {};
  foreach my $o (@{$outcomes}) {
    $map->{$o->composition()->freeze2rpt()} =
      { 'mqc_outcome' => $o->mqc_outcome()->short_desc };
  }
  return $map;
}

sub _save_outcomes {
  my ($self, $outcomes, $username, $lane_info) = @_;

  my $actions = sub {
    my @queries = ();
    foreach my $outcome_type ( @OUTCOME_TYPES ) {
      my $outcomes4type = $outcomes->{$outcome_type} || {};
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
          my $query = npg_tracking::glossary::rpt->inflate_rpt($key);
          push @queries, $query;
          my $outcome_ent = $self->_find_or_new_outcome($outcome_type, $query);
          if ($self->_valid4update($outcome_ent,  $outcome_description)) {
            if (!$outcome_ent->in_storage) {
              _link2composition($outcome_ent, $key);
            }
            $outcome_ent->update_outcome($outcome_description, $username);
            if ($outcome_type eq 'seq' && $outcome_ent->has_final_outcome) {
              my @lib_outcomes = $self->_create_query($LIB_RS_NAME, $query)->all();
              $self->_validate_library_outcomes(
                      $outcome_ent, \@lib_outcomes, $lane_info->{$key});
              $self->_finalise_library_outcomes(\@lib_outcomes, $username);
            }
          }
        } catch {
          croak qq[Error saving '$outcome_description' for $key - $_];
        };
      }
    }
    return \@queries;
  };

  return $self->qc_schema->txn_do($actions);
}

sub _create_query {
  my ($self, $rsname, $query) = @_;
  my $db_query = $self->qc_schema()->resultset($rsname)
                                   ->search({}, {'join' => $QC_OUTCOME})
                                   ->search_autoqc($query);
  return $db_query;
}

sub _find_or_new_outcome {
  my ($self, $outcome_type, $query) = @_;

  if (!$outcome_type || !$query) {
    croak q[Two arguments required: outcome entity type string and query];
  }
  if ( none {$_ eq $outcome_type} @OUTCOME_TYPES ) {
    croak qq[Unknown outcome entity type '$outcome_type'];
  }

  my $q = { %{$query} };
  my $rs_name = $outcome_type eq $LIB_OUTCOMES ? $LIB_RS_NAME : $SEQ_RS_NAME;
  my $rs = $self->qc_schema()->resultset($rs_name);
  my $rs_found = $rs->search_autoqc($q);
  my $result = $rs_found->next;
  if (!$result) {
    # Create result object in memory.
    # Foreign key constraints are not checked at this point.
    $rs->deflate_unique_key_components($q); # Changes $q hash
    $result=$rs->new_result($q);
  } else { # Existing database record is found.
    if ($rs_found->next) {
      croak q[Multiple qc outcomes where one is expected];
    }
  }

  return $result;
}

sub _valid4update {
  my ($self, $row, $outcome_desc) = @_;
  if ($row->in_storage) {
    if ($row->mqc_outcome->short_desc eq $outcome_desc) {
      return 0;
    } elsif ($row->has_final_outcome) {
      croak q[Final outcome cannot be updated];
    }
  }
  return 1;
}

sub _link2composition {
  my ($outcome_ent, $rpt_key) = @_;
  my $composition_obj = npg_tracking::glossary::composition::factory::rpt_list
                          ->new(rpt_list => $rpt_key)
                          ->create_composition();
  my $rs = $outcome_ent->result_source()->resultset();
  my $seq_composition = $rs->find_or_create_seq_composition($composition_obj);
  my $fk_column_name  = $rs->composition_fk_column_name();
  $outcome_ent->$fk_column_name($seq_composition->$fk_column_name);
  return;
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

Takes an array of queries. Each query hash should contain at least the 'id_run'
and 'position' keys and can also contain the 'tag_index' key.
 
Returns simple representations of rows hashed first on the type of
the outcome 'lib' for library outcomes and 'seq' for sequencing outcomes
and then on rpt keys.

  use Data::Dumper;
  print Dumper $obj->get([{id_run=>5,position=>3,tag_index=>7});

  $VAR1 = {
          'lib' => {
                     '5:3:7' => {
                                  'tag_index' => 7,
                                  'mqc_outcome' => 'Undecided final',
                                  'position' => 3,
                                  'id_run' => 5
                                }
                   },
          'seq' => {
                     '5:3' => {
                                'mqc_outcome' => 'Accepted final',
                                'position' => 3,
                                'id_run' => 5
                              }
                   }
          };

For a query with id_run and position the sequencing lane outcome and all known
library outcomes for this position are be returned. For a query with id_run,
position and tag_index both the sequencing lane outcome and library outcome are
returned. 

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

The method returns the data identical for to return value of the get method for the
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

=item npg_tracking::glossary::rpt

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

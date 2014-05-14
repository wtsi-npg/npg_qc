#########
# Author:        ajb
# Maintainer:    $Author$
# Created:       2008-06-10
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

package npg_qc::model::run_tile;
use strict;
use warnings;
use base qw(npg_qc::model);
use English qw(-no_match_vars);
use Carp;
use npg_qc::model::tile_score;
use npg_qc::model::cumulative_errors_by_cycle;
use npg_qc::model::error_rate_reference_including_blanks;
use npg_qc::model::error_rate_reference_no_blanks;
use npg_qc::model::error_rate_relative_reference_cycle_nucleotide;
use npg_qc::model::error_rate_relative_sequence_base;
use npg_qc::model::errors_by_cycle;
use npg_qc::model::errors_by_cycle_and_nucleotide;
use npg_qc::model::errors_by_nucleotide;
use npg_qc::model::information_content_by_cycle;
use npg_qc::model::log_likelihood;
use npg_qc::model::most_common_blank_pattern;
use npg_qc::model::most_common_word;
use npg_qc::model::lane_qc;
use npg_qc::model::move_z;

our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/mxs; $r; };

__PACKAGE__->mk_accessors(__PACKAGE__->fields());

sub fields {
  return qw(
            id_run_tile
            id_run
            position
            tile
            end
            row
            col
            avg_newz
          );
}

sub init {
  my $self = shift;

  if($self->{id_run} &&
     $self->{position} &&
     $self->{tile} &&
     $self->{end} &&
     !$self->{'id_run_tile'}) {

    my $query = q(SELECT id_run_tile
                  FROM   run_tile
                  WHERE  id_run = ?
                  AND    position = ?
                  AND    tile = ?
                  AND    end = ?);

    my $ref   = [];

    eval {
      $ref = $self->util->dbh->selectall_arrayref($query, {}, $self->id_run(), $self->position(), $self->tile(), $self->end());
      1;
    } or do {
      carp $EVAL_ERROR;
      return;
    };

    if(@{$ref}) {
      $self->{'id_run_tile'} = $ref->[0]->[0];
    }

  }

  if($self->{id_run} &&
     $self->{position} &&
     $self->{tile} &&
     !$self->{'id_run_tile'} &&
     !$self->{end}
     ) {

    my $query = q(SELECT id_run_tile
                  FROM   run_tile
                  WHERE  id_run = ?
                  AND    position = ?
                  AND    tile = ?
                  AND    end = 1);

    my $ref   = [];

    eval {
      $ref = $self->util->dbh->selectall_arrayref($query, {}, $self->id_run(), $self->position(), $self->tile());
      1;
    } or do {
      carp $EVAL_ERROR;
      return;
    };

    if(@{$ref}) {
      $self->{'id_run_tile'} = $ref->[0]->[0];
    }

  }

  return 1;
}

sub runpair {
  my ($self, $runpair) = @_;
  if ($runpair) {
    $self->{runpair} = $runpair;
  }
  return $self->{runpair} || 0;
}

sub requested_id_run {
  my ($self, $requested_id_run) = @_;
  if ($requested_id_run) {
    $self->{requested_id_run} = $requested_id_run;
  }
  return $self->{requested_id_run};
}

sub other_end_tile {
  my $self = shift;

  my $pkg  = ref$self;

  my $other_end;

  if ($self->end() == 1) {

    $other_end = $pkg->new({
      util => $self->util(),
      id_run => $self->id_run(),
      position => $self->position(),
      tile => $self->tile(),
      end => 2,
    });

  } else {

    $other_end = $pkg->new({
      util => $self->util(),
      id_run => $self->id_run(),
      position => $self->position(),
      tile => $self->tile(),
      end => 1,
    });

  }

  if ($other_end->id_run_tile()) {
    return $other_end;
  }

  return;
}

sub all_run_tiles {
  my $self = shift;
  return $self->gen_getall();
}

sub runs {
  my ($self) = @_;

  if (!$self->{runs}) {

    my $query = q{SELECT DISTINCT id_run FROM run_tile ORDER BY id_run DESC};

    my $ref   = [];

    eval {
      $ref = $self->util->dbh->selectall_arrayref($query, {});
      1;
    } or do {
      croak 'Unable to obtain run ids';
    };

    foreach my $run (@{$ref}) {
      $run = $run->[0];
    }

    $self->{runs} = $ref;
  }

  return $self->{runs};
}

sub run_tiles_per_run {
  my ($self, $id_run) = @_;

  $id_run ||= $self->id_run();

  my $pkg = ref$self;

  my $query = q{SELECT * FROM run_tile WHERE id_run = ? ORDER BY end, position, tile};

  return $self->gen_getarray($pkg, $query, $id_run);
}

sub run_tiles_per_run_by_lane_end {
  my ($self, $id_run) = @_;
  my $run_tiles = $self->run_tiles_per_run($id_run);
  my $id_run_pair = $self->id_run_pair($id_run);
  my $run_tiles_run_log_pair = $self->run_tiles_per_run($id_run_pair);
  my $run_log_pair_hash;
  foreach my $tile (@{$run_tiles_run_log_pair}) {
    my $key = $tile->position() . q{_} . $tile->tile;
    $run_log_pair_hash->{$key} = $tile;
  }
  my $return_array;
  foreach my $tile (@{$run_tiles}) {
    my $end = $tile->end() - 1;
    my $position = $tile->position() - 1;
    if ($tile->end() == 2 && scalar@{$run_tiles_run_log_pair}) {
      my $key = $tile->position() . q{_} . $tile->tile;
      $tile->row($run_log_pair_hash->{$key}->row());
      $tile->col($run_log_pair_hash->{$key}->col());
      $tile->avg_newz($run_log_pair_hash->{$key}->avg_newz());
    }
    push @{$return_array->[$end]->[$position]}, $tile;
  }
  return $return_array;
}

sub run_tiles_per_run_lane {
  my ($self) = @_;

  my $pkg = ref$self;

  my $query = q{SELECT * FROM run_tile WHERE id_run = ? AND position = ? AND end = ? ORDER BY tile};

  return $self->gen_getarray($pkg, $query, $self->id_run(), $self->position(), $self->end());
}


sub get_object_arrays {
  my ($self, $pkg) = @_;

  my @fields = $pkg->fields();
  shift @fields;

  my $query = qq(SELECT @{[join q(, ), @fields]}
                 FROM   @{[$pkg->table()]}
                 WHERE  id_run_tile = ?);

  return $self->gen_getarray($pkg, $query, $self->id_run_tile());
}

sub move_zes {
  my $self  = shift;
  my $pkg   = 'npg_qc::model::move_z';
  my @move_zes = sort {$a->cycle() <=> $b->cycle()} @{$self->get_object_arrays($pkg)};
  return \@move_zes;
}

sub tile_scores {
  my $self  = shift;
  my $pkg   = 'npg_qc::model::tile_score';
  return $self->get_object_arrays($pkg);
}

sub cumulative_errors_by_cycles {
  my $self  = shift;
  my $pkg   = 'npg_qc::model::cumulative_errors_by_cycle';
  return $self->get_object_arrays($pkg);
}

sub error_rate_reference_including_blank {
  my $self  = shift;
  my $pkg   = 'npg_qc::model::error_rate_reference_including_blanks';
  return $self->get_object_arrays($pkg);
}

sub error_rate_reference_no_blank {
  my $self  = shift;
  my $pkg   = 'npg_qc::model::error_rate_reference_no_blanks';
  return $self->get_object_arrays($pkg);
}

sub error_rate_relative_reference_cycle_nucleotides {
  my $self  = shift;
  my $pkg   = 'npg_qc::model::error_rate_relative_reference_cycle_nucleotide';
  return $self->get_object_arrays($pkg);
}

sub error_rate_relative_sequence_bases {
  my $self  = shift;
  my $pkg   = 'npg_qc::model::error_rate_relative_sequence_base';
  return $self->get_object_arrays($pkg);
}

sub errors_by_cycles {
  my $self  = shift;
  my $pkg   = 'npg_qc::model::errors_by_cycle';
  return $self->get_object_arrays($pkg);
}

sub errors_by_cycle_and_nucleotides {
  my $self  = shift;
  my $pkg   = 'npg_qc::model::errors_by_cycle_and_nucleotide';
  return $self->get_object_arrays($pkg);
}

sub errors_by_nucleotides {
  my $self  = shift;
  my $pkg   = 'npg_qc::model::errors_by_nucleotide';
  return $self->get_object_arrays($pkg);
}

sub information_content_by_cycles {
  my $self  = shift;
  my $pkg   = 'npg_qc::model::information_content_by_cycle';
  return $self->get_object_arrays($pkg);
}

sub log_likelihoods {
  my $self  = shift;
  my $pkg   = 'npg_qc::model::log_likelihood';
  return $self->get_object_arrays($pkg);
}

sub most_common_blank_patterns {
  my $self  = shift;
  my $pkg   = 'npg_qc::model::most_common_blank_pattern';
  return $self->get_object_arrays($pkg);
}

sub most_common_words {
  my $self  = shift;
  my $pkg   = 'npg_qc::model::most_common_word';
  return $self->get_object_arrays($pkg);
}

sub lane_qcs {
  my $self = shift;
  my $pkg  = 'npg_qc::model::lane_qc';
  return $self->get_object_arrays($pkg);
}

sub tile_rescore {
  my ($self) = @_;

  my $pkg   = 'npg_qc::model::tile_score';

  my $query = qq(SELECT @{[join q(, ), $pkg->fields()]}
                 FROM   @{[$pkg->table()]}
                 WHERE  id_run_tile = ?
                 AND    rescore = 1);

  my $tile_rescore = $self->gen_getarray($pkg, $query, $self->id_run_tile())->[0];

  if ($tile_rescore) {
    return $tile_rescore;
  }

  $query = qq(SELECT @{[join q(, ), $pkg->fields()]}
              FROM   @{[$pkg->table()]}
              WHERE  id_run_tile = ?
              AND    rescore = 0);

  return $self->gen_getarray($pkg, $query, $self->id_run_tile())->[0];
}

sub log_likelihood_rescores {
  my ($self) = @_;
  return $self->pure_table_refactor('npg_qc::model::log_likelihood', [qw(cycle id_log_likelihood)]);
}

sub most_common_word_rescores {
  my ($self) = @_;
  return $self->pure_table_refactor('npg_qc::model::most_common_word', [qw(rank)]);
}

sub most_common_blank_pattern_rescores {
  my ($self) = @_;
  return $self->pure_table_refactor('npg_qc::model::most_common_blank_pattern', [qw(rank)]);
}

sub error_rate_reference_including_blanks {
  my ($self) = @_;
  return $self->pure_table_refactor('npg_qc::model::error_rate_reference_including_blanks', [qw(really)]);
}

sub error_rate_reference_no_blanks {
  my ($self) = @_;
  return $self->pure_table_refactor('npg_qc::model::error_rate_reference_no_blanks', [qw(really)]);
}

sub error_rate_relative_to_sequence_bases {
  my ($self) = @_;
  return $self->pure_table_refactor('npg_qc::model::error_rate_relative_sequence_base', [qw(read_as)]);
}

sub errors_by_nucleotide {
  my ($self) = @_;
  return $self->pure_table_refactor('npg_qc::model::errors_by_nucleotide', [qw(read_as)]);
}

sub errors_by_cycle_and_nucleotide {
  my ($self) = @_;
  return $self->pure_table_refactor('npg_qc::model::errors_by_cycle_and_nucleotide', [qw(cycle read_as)]);
}

sub error_rate_relative_reference_cycle_nucleotide {
  my ($self) = @_;
  return $self->pure_table_refactor('npg_qc::model::error_rate_relative_reference_cycle_nucleotide', [qw(cycle read_as)]);
}

sub pure_table_refactor {
  my ($self, $pkg, $order_by) = @_;

  my @fields = $pkg->fields();
  shift @fields;

  my $query  = qq(SELECT @{[join q(, ), @fields]}
                  FROM   @{[$pkg->table()]}
                  WHERE  id_run_tile = ?
                  AND    rescore = 1
                  ORDER BY @{[join q(, ), @{$order_by}]});

  my $return_array = $self->gen_getarray($pkg, $query, $self->id_run_tile());

  if ($return_array->[0]) {
    return $return_array;
  }

  $query  = qq(SELECT @{[join q(, ), $pkg->fields()]}
               FROM   @{[$pkg->table()]}
               WHERE  id_run_tile = ?
               AND    rescore = 0
               ORDER BY @{[join q(, ), @{$order_by}]});

  return $self->gen_getarray($pkg, $query, $self->id_run_tile());
}

sub cycle_count {
  my ($self) = @_;
  if (!$self->{cycle_count}) {

    my $id_run = $self->{id_run};
    my $end = $self->{end} || 1;

    $self->{cycle_count} = $self->get_cycle_count_from_recipe($id_run, $end);
  }
  return $self->{cycle_count};
}

sub movez_id_runs {
  my ($self) = @_;

  my %return_id_runs = ();
  my $dbh = $self->util->dbh();
  my $query = q{
SELECT run_lane_table.id_run
FROM (
SELECT temp.id_run, count(*) AS lane_count
FROM(
SELECT id_run, position, count(*) AS tile_count
FROM run_tile
WHERE row is NOT NULL
GROUP BY id_run, position
) temp, run_recipe rr
WHERE temp.id_run = rr.id_run
AND tile_count = rr.tile
GROUP BY id_run
) run_lane_table, run_recipe 
WHERE run_lane_table.id_run = run_recipe.id_run
AND run_lane_table.lane_count = run_recipe.lane
ORDER BY run_lane_table.id_run DESC
  };
  eval {
    my $sth = $dbh->prepare($query);
    $sth->execute();
    while (my @row = $sth->fetchrow_array()) {
      $return_id_runs{$row[0]} = 1;
    }
    1;
  } or do {
      croak $EVAL_ERROR;
  };
  return \%return_id_runs;
}

sub tile_max {
  my ($self, $id_run) = @_;

  $id_run ||= $self->id_run();

  if (!$self->{tile_max}) {

    my $query = q(SELECT max(tile) FROM run_tile where id_run = ?);

    my $ref;

    eval {
      $ref = $self->util->dbh->selectall_arrayref($query, {}, $id_run);
      1;
    } or do {
      croak $EVAL_ERROR;
    };

    $self->{tile_max} = $ref->[0]->[0];

  }
  return $self->{tile_max};
}

sub get_run_log_tile_pair {
  my ($self) = @_;

  if (!$self->{get_run_log_tile_pair}) {
    my $pkg = ref$self;

    $self->{get_run_log_tile_pair} = $pkg->new({
      util => $self->util(),
      id_run => $self->id_run_pair(),
      end => 1,
      position => $self->position(),
      tile => $self->tile()
    });

    if (!$self->{get_run_log_tile_pair} || !$self->{get_run_log_tile_pair}->id_run_tile()) {
      $self->{get_run_log_tile_pair} = $pkg->new({
        util => $self->util(),
        id_run => $self->id_run(),
        end => 2,
        position => $self->position(),
        tile => $self->tile()
      });
    }

    $self->{get_run_log_tile_pair}->read();
  }
  return $self->{get_run_log_tile_pair};
}

sub get_end_descriptions {
  my ($self) = @_;

  if (!$self->{get_end_descriptions}) {

    my $pkg = ref$self;
    my $id_run_pair = $self->id_run_pair($self->id_run());

    if (!$id_run_pair || $id_run_pair == $self->id_run()) {

      $self->{get_end_descriptions} =  {
        end_one_tile => $self,
        run_log_tile_end_one => $self,
      };

    } elsif ($id_run_pair < $self->id_run()) {

      my $run_log_tile_pair = $self->get_run_log_tile_pair();
      my $other_end_tile = $run_log_tile_pair->other_end_tile();

      $self->{get_end_descriptions} = {
        run_log_tile_end_one => $run_log_tile_pair,
        run_log_tile_end_two => $self,
        end_two_tile => $other_end_tile,
        end_one_tile => $run_log_tile_pair,
      };

    } else {

      my $run_log_tile_pair = $self->get_run_log_tile_pair();
      my $other_end_tile = $self->other_end_tile();

      if ($self->end() == 1) {

        $self->{get_end_descriptions} = {
          run_log_tile_end_one => $self,
          run_log_tile_end_two => $run_log_tile_pair,
          end_two_tile => $other_end_tile,
          end_one_tile => $self,
        };

      } else {

        $self->{get_end_descriptions} = {
          run_log_tile_end_one => $other_end_tile,
          run_log_tile_end_two => $run_log_tile_pair,
          end_two_tile => $self,
          end_one_tile => $other_end_tile,
        };
      }
    }
  }

  return $self->{get_end_descriptions};
}

1;
__END__
=head1 NAME

npg_qc::model::run_tile

=head1 VERSION

$Revision$

=head1 SYNOPSIS

  my $oRunTile = npg_qc::model::run_tile->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - return array of fields, first of which is the primary key

  my $aFields = $oRunTile->fields();

=head2 init - on new creation, if tries to retrieve primary key if this run_tile is already present in database

=head2 all_run_tiles - returns array of all run_tile objects

  my $aAllRunTiles = $oRunTile->all_run_tiles();

=head2 runs - returns an array of all the id_runs which are in the run_tile table

  my $aRuns = $oRunTile->runs();

=head2 run_tiles_per_run - returns array of all run_tile objects for a the given id_run

  my $aRunTilesPerRun = $oRunTile->run_tiles_per_run();

=head2 run_tiles_per_run_by_lane_end - returns array of all run_tile objects for a the given id_run, structured by end, then position, then tile order, optionally providing an id_run

  my $aRunTilesPerRunByLane = $oRunTile->run_tiles_per_run_by_lane_end();

=head2 run_tiles_per_run_lane - returns array of all run_tile objects for the given id_run and position (lane)

  my $aRunTilesPerRunLane = $oRunTile->run_tiles_per_run_lane();

=head2 other_end_tile - fetches a RunTile object for the corresponding ends run tile (if a paired run)

  my $oOtherEndRunTile = $oRunTile->other_end_tile();

=head2 get_object_arrays - refactor of query for each of the array calls to children of run_tile

  my $aGetObjects = $oRunTile->get_object_arrays($pkg);

=head2 tile_alls - returns array of all tile_alls that are children of this run_tile

  my $aTileAlls = $oRunTile->tile_alls();

=head2 move_zes - returns array of all move_zes that are children of this run_tile

  my $aMoveZes = $oRunTile->move_zes();

=head2 tile_scores - returns array of all tile_scores that are children of this run_tile

  my $aTileScores = $oRunTile->tile_scores();

=head2 cumulative_errors_by_cycles - returns array of all cumulative_errors_by_cycles that are children of this run_tile

  my $aCumulativeErrorsByCycles = $oRunTile->cumulative_errors_by_cycles();

=head2 error_rate_reference_including_blank - returns array of all error_rate_reference_including_blank that are children of this run_tile

  my $aErrorRateReferenceIncludingBlank = $oRunTile->error_rate_reference_including_blank();

=head2 error_rate_reference_no_blank - returns array of all error_rate_reference_no_blank that are children of this run_tile

  my $aErrorRateReferenceNoBlank = $oRunTile->error_rate_reference_no_blank();

=head2 error_rate_relative_reference_cycle_nucleotides - returns array of all error_rate_relative_reference_cycle_nucleotides that are children of this run_tile

  my $aErrorRateRelativeReferenceCycleNucleotides = $oRunTile->error_rate_relative_reference_cycle_nucleotides();

=head2 error_rate_relative_sequence_bases - returns array of all error_rate_relative_sequence_bases that are children of this run_tile

  my $aErrorRateRelativeSequenceBases = $oRunTile->error_rate_relative_sequence_bases();

=head2 errors_by_cycles - returns array of all errors_by_cycles that are children of this run_tile

  my $aErrorsByCycles = $oRunTile->errors_by_cycles();

=head2 errors_by_cycle_and_nucleotides - returns array of all errors_by_cycle_and_nucleotides that are children of this run_tile

  my $aErrorsByCycleAndNucleotides = $oRunTile->errors_by_cycle_and_nucleotides();

=head2 errors_by_nucleotides - returns array of all errors_by_nucleotides that are children of this run_tile

  my $aErrorsByNucleotides = $oRunTile->errors_by_nucleotides();

=head2 information_content_by_cycles - returns array of all information_content_by_cycles that are children of this run_tile

  my $aInformationContentByCycles = $oRunTile->information_content_by_cycles();

=head2 log_likelihoods - returns array of all log_likelihoods that are children of this run_tile

  my $aLogLikelihoods = $oRunTile->log_likelihoods();

=head2 most_common_blank_patterns - returns array of all most_common_blank_patterns that are children of this run_tile

  my $aMostCommonBlankPatterns = $oRunTile->most_common_blank_patterns();

=head2 most_common_words - returns array of all most_common_words that are children of this run_tile

  my $aMostCommonWords = $oRunTile->most_common_words();

=head2 swift_reports - returns array of all swift_reports that are children of this run_tile

  my $aSwiftReports = $oRunTile->swift_reports();

=head2 swift_pf_errors_per_cycles - returns array of all swift_pf_errors_per_cycles that are children of this run_tile

  my $aSwiftPFErrorsPerCycles = $oRunTile->swift_pf_errors_per_cycles();

=head2 swift_npf_errors_per_cycles - returns array of all swift_npf_errors_per_cycles that are children of this run_tile

  my $aSwiftNPFErrorsPerCycles = $oRunTile->swift_npf_errors_per_cycles();

=head2 swift_all_intensities_per_cycle_per_bases - returns array of all swift_all_intensities_per_cycle_per_bases that are children of this run_tile

  my $aSwiftAllIntensitiesPerCyclePerBases = $oRunTile->swift_all_intensities_per_cycle_per_bases();

=head2 swift_called_intensities_per_cycle_per_bases - returns array of all swift_called_intensities_per_cycle_per_bases that are children of this run_tile

  my $aSwiftCalledIntensitiesPerCyclePerBases = $oRunTile->swift_called_intensities_per_cycle_per_bases();

=head2 lane_qcs - returns array of all the lane_qcs which are children of this run_tile

  my $aLaneQCs = $oRunTile->lane_qcs();

=head2 tile_rescore - returns an array containing the rescore information for a tile as it was processed

  my $aTileRescore = $oRunTile->tile_rescore();

=head2 pure_table_refactor - a refactor of the common code for returning all rescore tables for the run_tile

  my $aTableRows = $oRunTile->pure_table_refactor($pkg, [qw(order by in order)]);

=head2 cycle_count - for Illumina data, returns the cycle_count for the run

  my $iCycleCount = $oRunTile->cycle_count();

=head2 tile_max - returns the highest tile number for given id_run

  my $iTileMax = $oRunTile->tile_max($id_run);

=head2 log_likelihood_rescores
=head2 most_common_word_rescores
=head2 most_common_blank_pattern_rescores
=head2 error_rate_reference_including_blanks
=head2 error_rate_reference_no_blanks
=head2 error_rate_relative_to_sequence_bases
=head2 errors_by_nucleotide
=head2 errors_by_cycle_and_nucleotide
=head2 error_rate_relative_reference_cycle_nucleotide

=head2 movez_id_runs - get the list of id_runs from the database with row not null


 each uses pure_table_refactor to return the rescore table data for the run tile
 
 my $aTableRows = $oRunTile->method();

=head2 get_end_descriptions - returns a hashref containing a run_tile object for the descriptions (keys)

  end_one_tile
  end_two_tile
  run_log_tile_end_one
  run_log_tile_end_two

  my $hGetEndDescriptions = $oRunTile->get_end_descriptions();

=head2 get_run_log_tile_pair - returns a run_tile object which is for the pair of this object, but that contains run_log information

  my $oGetRunLogTilePair = $oRunTile->get_run_log_tile_pair();

=head2 runpair - accessor to store/retrieve Boolean for if both ends may be required
=head2 requested_id_run - accessor to store/retrieve requested_id_run for if only one end is required

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

strict
warnings
npg_qc::model

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Andy Brown, E<lt>ajb@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Andy Brown

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut

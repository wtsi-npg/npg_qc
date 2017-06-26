
use strict;
use warnings;
use base qw(npg_qc::model);
use English qw{-no_match_vars};
use Readonly;
use Carp;

our $VERSION = '0';

Readonly our $MAX_ERROR_PERCENTAGE => 20; # max error percentage set to 20
Readonly our $HEATMAP_VALUE_GT_20  => 100;
Readonly our $HEATMAP_VALUE_GT_5   => 50;
Readonly our $FIVE                 => 5;
Readonly our $FOURTH_ARRAY_INDEX   => 3;
Readonly our $FIFTH_ARRAY_INDEX    => 4;
Readonly our $X_LABEL_SKIP_THUMB   => 20;
Readonly our $THUMB_HEIGHT         => 86;
Readonly our $THUMB_WIDTH          => 126;

__PACKAGE__->mk_accessors(__PACKAGE__->fields());

sub fields {
  return qw(
            id_errors_by_cycle
            id_run_tile
            cycle
            error_percentage
            blank_percentage
            rescore
          );
}

sub init {
  my $self = shift;

  if($self->id_run_tile() &&
     $self->cycle() &&
     defined $self->rescore() &&
     !$self->id_errors_by_cycle()) {

    my $query = q(SELECT id_errors_by_cycle
                 FROM errors_by_cycle
                 WHERE id_run_tile = ?
                 AND cycle = ?
                 AND rescore = ?
                 );

    my $ref   = [];

    eval {
      $ref = $self->util->dbh->selectall_arrayref($query, {}, $self->id_run_tile(), $self->cycle(), $self->rescore());
      1;
    } or do {
      carp $EVAL_ERROR;
      return;
    };

    if(@{$ref}) {
      $self->id_errors_by_cycle($ref->[0]->[0]);
    }
  }
  return 1;
}

sub id_run {
  my ($self, $id_run) = @_;
  if ($id_run) { $self->{id_run} = $id_run; }
  return $self->{id_run};
}

sub run_tile {
  my $self  = shift;
  my $pkg   = 'npg_qc::model::run_tile';
  return $pkg->new({
		    'util' => $self->util(),
		    'id_run_tile' => $self->id_run_tile(),
		   });
}

sub average_perc_for_lane {
  my ($self, $id_run, $position) = @_;

  my @rows;

  eval {

    my $dbh = $self->util->dbh();
    my $query = q{SELECT ec.cycle, AVG(ec.error_percentage) AS error_percentage
                  FROM   run_tile rt,
                         errors_by_cycle ec
                  WHERE  rt.id_run = ?
                  AND    rt.position = ?
                  AND    rt.end = 1
                  AND    rt.id_run_tile = ec.id_run_tile
                  AND    rescore = 1
                  GROUP BY cycle,position
                  ORDER BY position, cycle};
    my $sth = $dbh->prepare($query);
    $sth->execute($id_run, $position);

    while (my @row = $sth->fetchrow_array()) {
      if ($row[1] > $MAX_ERROR_PERCENTAGE) {
        $row[1] = $MAX_ERROR_PERCENTAGE;
      }
      push @rows, \@row;
    }

    my $cycles;
    if(scalar @rows){
      $cycles = $rows[-1]->[0];

      $query = q{SELECT ec.cycle, AVG(ec.error_percentage) AS error_percentage
               FROM   run_tile rt,
                      errors_by_cycle ec
               WHERE  rt.id_run = ?
               AND    rt.position = ?
               AND    rt.end = 2
               AND    rt.id_run_tile = ec.id_run_tile
               AND    rescore = 1
               GROUP BY cycle,position
               ORDER BY position, cycle};
      $sth = $dbh->prepare($query);
      $sth->execute($id_run, $position);

      while (my @row = $sth->fetchrow_array()) {
        if ($row[1] > $MAX_ERROR_PERCENTAGE) {
          $row[1] = $MAX_ERROR_PERCENTAGE;
        }
        $row[0] += $cycles;
        push @rows, \@row;
      }
    }

    1;
  } or do {

    croak $EVAL_ERROR;

  };

  return \@rows;
}

sub errors_by_tile {
  my ($self, $tile) = @_;

  my @errors_by_tile = sort { $a->cycle() <=> $b->cycle } @{$tile->errors_by_cycles()};

  return @errors_by_tile;
}

sub cycle_count {
  my ($self) = @_;

  if (!$self->{cycle_count}) {
    my $id_run = $self->{id_run};
    my $dbh = $self->util->dbh();

    my $query = qq{SELECT max(ec.cycle) FROM run_tile rt, errors_by_cycle ec WHERE rt.id_run = $id_run AND ec.id_run_tile = rt.id_run_tile};
    my $sth = $dbh->prepare($query);
    $sth->execute();

    $self->{cycle_count} = $sth->fetchrow_array();
  }

  return $self->{cycle_count};
}

sub cycles_for_run {
  my ($self) = @_;

  my $id_run = $self->{id_run};
  my $dbh = $self->util->dbh();

  my $cycle_count = $self->cycle_count();

  my $query = qq{SELECT max(end) FROM run_tile WHERE id_run = $id_run};
  my $sth = $dbh->prepare($query);
  $sth->execute();

  my $end = $sth->fetchrow_array();

  if ($end && $end ne 't' && ($end == 2)) {
    $cycle_count *= 2;
  }

  return [1..$cycle_count];
}

sub all_data_for_run {
  my ($self) = @_;
  my $id_run = $self->id_run();

  if (!$self->{all_data_for_run}) {
    my $query = q{SELECT r.position, r.tile, e.cycle, e.error_percentage, e.blank_percentage
                  FROM run_tile r, errors_by_cycle e
                  WHERE r.id_run = ?
                  AND   r.end    = ?
                  AND   r.id_run_tile = e.id_run_tile
                  AND   e.rescore = 1
                  ORDER BY r.position, r.tile, e.cycle};
    my $dbh = $self->util->dbh();
    my $all = $dbh->selectall_arrayref($query, {}, $id_run, 1);

    my $cycle;

    foreach my $row (@{$all}) {
      my $i = $row->[0] - 1;
      push @{$self->{all_data_for_run}->[$i]}, {
        position         => $row->[0],
	tile             => $row->[1],
	cycle            => $row->[2],
	error_percentage => $row->[$FOURTH_ARRAY_INDEX],
	blank_percentage => $row->[$FIFTH_ARRAY_INDEX]
      };
      if ($cycle < $row->[2]) {
        $cycle = $row->[2];
      }
    }
    if ($self->id_run_pair()) {
      my $all_other_end_pair = $dbh->selectall_arrayref($query, {}, $id_run, 2);
      foreach my $row (@{$all_other_end_pair}) {
        my $i = $row->[0] - 1;
        my $cycle_next_end = $row->[2] + $cycle;
        push @{$self->{all_data_for_run}->[$i]},{
          position         => $row->[0],
          tile             => $row->[1],
          cycle            => $cycle_next_end,
          error_percentage => $row->[$FOURTH_ARRAY_INDEX],
          blank_percentage => $row->[$FIFTH_ARRAY_INDEX]
        };
     }
    }

  }

  return $self->{all_data_for_run};
}

__END__
=head1 NAME

npg_qc::model::errors_by_cycle

=head1 SYNOPSIS

  my $oErrorsByCycle = npg_qc::model::errors_by_cycle->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 init 

=head2 id_run - accessor for id_run

=head2 fields - return array of fields, first of which is the primary key

  my $aFields = $oErrorsByCycle->fields();

=head2 run_tile - returns run_tile object that this object belongs to

  my $oRunTile = $oErrorsByCycle->run_tile();

=head2 errors_by_tile - fetches the errors by cycle for a given tile

  my @ErrorsByTile = $oErrorsByCycle->errors_by_tile($oRunTile);

=head2 run_tiles - returns an arrayref of all the run_tiles for a given run (in $self->{id_run})

  my $aRunTiles = $oErrorsByCycle->run_tiles();

=head2 run_tiles_uniq_names - returns an arrayref of unique tile names in the format <id_run>_<lane>_<tile_no>

  my $aRunTilesUnigNames = $oErrorsByCycle->run_tiles_uniq_names();

=head2 average_perc_for_lane - returns the data to plot average percentage errors by cycle for a lane

  my $aAveragePercForLane = $oErrorsByCycle->average_perc_for_lane($id_run, $position);

=head2 lanes - returns an array of all lanes for a run (provided id_run has already been put onto object)

  my $aLanes = $oErrorsByCycle->lanes();

=head2 cycle_count - returns (and caches) the cycle count for a single run of the run/runpair

  my $iCycleCount = $oErrorsByCycle->cycle_count();

=head2 cycles_for_run - returns an arrayref containing all the cycle numbers for a run (or run/runpair)

  my $aCyclesForRun = $oErrorsByCycle->cycles_for_run();

=head2 all_data_for_run - retrieves all the rescore error percent and blank percent for a run

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

strict
warnings
npg_qc::model
English
Readonly

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Andy Brown, E<lt>ajb@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2017 GRL

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut

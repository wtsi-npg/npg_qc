#########
# Author:        ajb
# Maintainer:    $Author: mg8 $
# Created:       2008-06-10
# Last Modified: $Date: 2013-09-02 10:40:54 +0100 (Mon, 02 Sep 2013) $
# Id:            $Id: errors_by_cycle.pm 17429 2013-09-02 09:40:54Z mg8 $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/model/errors_by_cycle.pm $
#

package npg_qc::model::errors_by_cycle;
use strict;
use warnings;
use base qw(npg_qc::model);
use English qw{-no_match_vars};
use Readonly;
use Carp;
use npg::util::image::heatmap;
use npg::util::image::image_map;

our $VERSION = do { my ($r) = q$Revision: 17429 $ =~ /(\d+)/mxs; $r; };

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

sub heatmap_with_map { ## no critic (ProhibitManyArgs)
  my ($self, $id_run, $end, $dataset, $url, $cycle) = @_;

  my $data_refs = {
    id_run    => $id_run,
    end       => $end,
    dataset   => $dataset,
    image_url => $url,
    id        => $dataset . q{:} . $id_run . q{:} . $end,
    hover_map => 1,
  };

  my $data_array = $self->heatmap_data($data_refs);

  my $heatmap_obj = npg::util::image::heatmap->new({
    data_array => $data_array,
  });

  eval {
    $heatmap_obj->plot_illumina_map($data_refs);
    $data_refs->{data} = $heatmap_obj->image_map_reference();
    foreach my $box (@{$data_refs->{data}}) {
      my $data_information = $box->[-1];
      my $params = q{id_run=} . $id_run . q{&position=} . $data_information->{position} . q{&tile=} . $data_information->{tile} . q{&end=} . $end . q{&cycle=} . $cycle;
      $box->[-1]->{url} = q{#" onclick="open_tile_viewer(SCRIPT_NAME + '/run_tile/;read_tile_viewer?} . $params .q{');return false;};
    }
    my $image_map_object = npg::util::image::image_map->new();
    $self->{map} = $image_map_object->render_map($data_refs);
  } or do {
    croak 'Unable to render map: ' . $EVAL_ERROR;
  };

  return $self->{map};
}

sub run_tile {
  my $self  = shift;
  my $pkg   = 'npg_qc::model::run_tile';
  return $pkg->new({
		    'util' => $self->util(),
		    'id_run_tile' => $self->id_run_tile(),
		   });
}

sub data_for_plot {
  my ($self, $id_run, $position, $tile) = @_;

  my @rows;
  eval {

    my $cycles;
    my $dbh = $self->util->dbh();
    my $query = q{SELECT DISTINCT ec.cycle, ec.error_percentage
                  FROM   run_tile rt,
                         errors_by_cycle ec
                  WHERE  rt.id_run = ?
                  AND    rt.position = ?
                  AND    rt.tile = ?
                  AND    rt.end = 1
                  AND    rt.id_run_tile = ec.id_run_tile
                  AND    rescore = 1
                  ORDER BY position, cycle};
    my $sth = $dbh->prepare($query);
    $sth->execute($id_run, $position, $tile);

    while (my @row = $sth->fetchrow_array()) {
      if ($row[1] > $MAX_ERROR_PERCENTAGE) {
        $row[1] = $MAX_ERROR_PERCENTAGE;
      }
      push @rows, \@row;
      $cycles = $row[0];

    }

    $query = q{SELECT DISTINCT ec.cycle, ec.error_percentage
               FROM   run_tile rt,
                      errors_by_cycle ec
               WHERE  rt.id_run = ?
               AND    rt.position = ?
               AND    rt.tile = ?
               AND    rt.end = 2
               AND    rt.id_run_tile = ec.id_run_tile
               AND    rescore = 1
               ORDER BY position, cycle};
    $sth = $dbh->prepare($query);
    $sth->execute($id_run, $position, $tile);

    while (my @row = $sth->fetchrow_array()) {
      if ($row[1] > $MAX_ERROR_PERCENTAGE) {
        $row[1] = $MAX_ERROR_PERCENTAGE;
      }
      $row[0] += $cycles;
      push @rows, \@row;
    }

    1;

  } or do {
    croak $EVAL_ERROR;
  };

  if (!scalar@rows) {
    return [];

  }
  return \@rows;
}

sub data_for_plot_blank_error {
  my ($self, $id_run, $position, $tile) = @_;

  my @rows;
  eval {

    my $cycles;
    my $dbh = $self->util->dbh();
    my $query = q{SELECT rt.end, ec.cycle, ec.blank_percentage
                  FROM   run_tile rt,
                         errors_by_cycle ec
                  WHERE  rt.id_run = ?
                  AND    rt.position = ?
                  AND    rt.tile = ?
                  AND    rt.id_run_tile = ec.id_run_tile
                  AND    rescore = 1
                  ORDER BY end, position, cycle};
    my $sth = $dbh->prepare($query);
    $sth->execute($id_run, $position, $tile);

    my $cycle_max_first_end = 0;
    while (my @row = $sth->fetchrow_array()) {

      if ($row[2] > $MAX_ERROR_PERCENTAGE) {
        $row[2] = $MAX_ERROR_PERCENTAGE;
      }

      my $row_plot_data = [];
      if($row[0] == 1){
        $cycle_max_first_end = $row[1];
        $row_plot_data = [$row[1], $row[2]];
      }elsif($row[0] == 2){
        $row_plot_data = [$row[1]+$cycle_max_first_end, $row[2]];
      }
      push @rows, $row_plot_data;

    }
    1;
  } or do {
    croak $EVAL_ERROR;
  };

  if (!scalar@rows) {
    return [];
  }

  return \@rows;
}

sub data_for_plot_including_pre_chastity {
  my ($self, $id_run, $position, $tile) = @_;
  my @rows;
  my %collated;
  eval {

    my $cycles;
    my $dbh = $self->util->dbh();
    my $query = q{SELECT DISTINCT ec.cycle, rescore, ec.error_percentage
                  FROM   run_tile rt,
                         errors_by_cycle ec
                  WHERE  rt.id_run = ?
                  AND    rt.position = ?
                  AND    rt.tile = ?
                  AND    rt.end = 1
                  AND    rt.id_run_tile = ec.id_run_tile
                  ORDER BY rescore, cycle};
    my $sth = $dbh->prepare($query);
    $sth->execute($id_run, $position, $tile);

    while (my @row = $sth->fetchrow_array()) {
      if ($row[2] > $MAX_ERROR_PERCENTAGE) {
        $row[2] = $MAX_ERROR_PERCENTAGE;
      }
      $collated{$row[0]}->{$row[1]} = $row[2];
      $cycles = $row[0];

    }

    $query = q{SELECT DISTINCT  ec.cycle, rescore, ec.error_percentage
               FROM   run_tile rt,
                      errors_by_cycle ec
               WHERE  rt.id_run = ?
               AND    rt.position = ?
               AND    rt.tile = ?
               AND    rt.end = 2
               AND    rt.id_run_tile = ec.id_run_tile
               ORDER BY rescore, cycle};
    $sth = $dbh->prepare($query);
    $sth->execute($id_run, $position, $tile);

    while (my @row = $sth->fetchrow_array()) {
      if ($row[2] > $MAX_ERROR_PERCENTAGE) {
        $row[2] = $MAX_ERROR_PERCENTAGE;
      }
      $row[0] += $cycles;
      $collated{$row[0]}->{$row[1]} = $row[2];
    }

    foreach my $cycle (sort { $a <=> $b } keys %collated) {
      push @rows, [$cycle, $collated{$cycle}{0}, $collated{$cycle}{1}];
    }

    1;

  } or do {
    croak $EVAL_ERROR;
  };

  if (!scalar@rows) {
    return [];

  }


  return \@rows;
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

sub heatmap_data_per_cycle {
  my ($self) = @_;
  my $cycle = $self->cycle();
  my $id_run = $self->{id_run};
  my $dbh = $self->util->dbh();

  my $query = qq{SELECT max(tile) FROM run_tile WHERE id_run = $id_run};
  my $sth = $dbh->prepare($query);
  $sth->execute();
  my $tile_count = $sth->fetchrow_array();

  $query = qq{SELECT max(ec.cycle) FROM run_tile rt, errors_by_cycle ec WHERE rt.id_run = $id_run AND ec.id_run_tile = rt.id_run_tile};
  $sth = $dbh->prepare($query);
  $sth->execute();
  my $cycle_count = $sth->fetchrow_array();

  my $end = 1;

  if ($cycle > $cycle_count) {
    $end = 2;
    $cycle = $cycle - $cycle_count;
  }

  $query = q{SELECT rt.position, rt.tile, ec.cycle, ec.error_percentage
             FROM   run_tile rt,
                    errors_by_cycle ec
             WHERE  rt.id_run = ?
             AND    rt.end = ?
             AND    rt.id_run_tile = ec.id_run_tile
             AND    ec.rescore = 1
             AND    ec.cycle = ?
             ORDER BY cycle, position, tile};

  $dbh = $self->util->dbh();
  $sth = $dbh->prepare($query);
  $sth->execute($id_run, $end, $cycle);

  my $data = [[],[],[],[],[],[],[],[]];

  while (my @row = $sth->fetchrow_array) {
    my $position = $row[0] - 1;

    my $value = $row[$FOURTH_ARRAY_INDEX] > $MAX_ERROR_PERCENTAGE ? $HEATMAP_VALUE_GT_20
              : $row[$FOURTH_ARRAY_INDEX] > $FIVE                 ? $HEATMAP_VALUE_GT_5
              :                                                     $row[$FOURTH_ARRAY_INDEX]
              ;

    push @{$data->[$position]}, $value;
  }

  foreach my $array (@{$data}) {

    if (scalar @{$array} == 0) {

      my $temp_count = $tile_count - 1;
      for my $i (0..$temp_count) {
        push @{$array}, 0;
      }

    }

  }

  return $data;
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
sub all_thumbnail_data {
  my ($self) = @_;

  if (!$self->{all_thumbnail_data}) {
    my $adf_run = $self->all_data_for_run();

    foreach my $lane (@{$adf_run}) {
      if ($lane) {
        foreach my $tile (@{$lane}) {
          push @{$self->{all_thumbnail_data}->[$tile->{position}]->[$tile->{tile}]->{error_percentage}->[0]}, $tile->{cycle};
          push @{$self->{all_thumbnail_data}->[$tile->{position}]->[$tile->{tile}]->{error_percentage}->[1]}, $tile->{error_percentage};
          push @{$self->{all_thumbnail_data}->[$tile->{position}]->[$tile->{tile}]->{blank_percentage}->[0]}, $tile->{cycle};
          push @{$self->{all_thumbnail_data}->[$tile->{position}]->[$tile->{tile}]->{blank_percentage}->[1]}, $tile->{blank_percentage};
        }
      }
    }
  }

  return $self->{all_thumbnail_data};
}

sub all_thumbs_map {
  my ($self, $imr) = @_;

  if ($imr) { $self->{all_thumbs_map} = $imr;}

  return $self->{all_thumbs_map};
}

1;
__END__
=head1 NAME

npg_qc::model::errors_by_cycle

=head1 VERSION

$Revision: 17429 $

=head1 SYNOPSIS

  my $oErrorsByCycle = npg_qc::model::errors_by_cycle->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 init 

=head2 data_for_plot_blank_error

=head2 id_run - accessor for id_run

  my $iIdRun = $oErrorsByCycle->id_run($iIdRun);

=head2 fields - return array of fields, first of which is the primary key

  my $aFields = $oErrorsByCycle->fields();

=head2 run_tile - returns run_tile object that this object belongs to

  my $oRunTile = $oErrorsByCycle->run_tile();

=head2 data_for_plot - generates the data to plot errors_by_cycle for a lane in order to be plotted

  my $aDataForPlot = $oErrorsByCycle->data_for_plot($id_run, $position, $tile);

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

=head2 heatmap_data_per_cycle - obtains the error percentages per tile for a given cycle

=head2 cycle_count - returns (and caches) the cycle count for a single run of the run/runpair

  my $iCycleCount = $oErrorsByCycle->cycle_count();

=head2 cycles_for_run - returns an arrayref containing all the cycle numbers for a run (or run/runpair)

  my $aCyclesForRun = $oErrorsByCycle->cycles_for_run();

=head2 heatmap_with_map - returns some html code with a heatmap url and a hovermap for it

=head2 data_for_plot_including_pre_chastity - returns the data required to draw a plot with two lines, pre- and post-chastity

  my $aDataForPlotIncludingChastity = $oErrorsByCycle->data_for_plot_including_pre_chastity($id_run, $position, $tile);

=head2 all_data_for_run - retrieves all the rescore error percent and blank percent for a run

=head2 all_thumbnail_data - turns all_data_for_run into format to be processed generating all the thumbnails for a run

=head2 all_thumbs_map - accessor to store and retrieve all the map data points

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

Copyright (C) 2010 GRL, by Andy Brown

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut

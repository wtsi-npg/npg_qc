#########
# Author:        rmp
# Maintainer:    $Author$
# Created:       2008-06-10
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#
package npg_qc::model;
use strict;
use warnings;
use base qw(ClearPress::model);
use npg_qc::util;
use English qw(-no_match_vars);
use Carp;
use npg_qc::model::run_tile;
use npg_qc::model::chip_summary;
use npg::api::run;
use npg_qc::model::run_and_pair;
use npg_qc::model::cache_query;

our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/mxs; $r; };

sub uid {
  my $self  = shift;
  my $zdate = $self->zdate();
  $zdate    =~ s/[^[:lower:]\d]//smigx;
  $zdate   .= $self->{'_uid_sequence'}++;
  return $zdate;
}

sub model_type {
  my $self = shift;
  my $ref = ref$self;
  my @temp = split /::/xms, $ref;
  return $temp[-1];
}

sub dbh_datetime {
  my $self = shift;
  return $self->util->dbh->selectall_arrayref('SELECT NOW()',{})->[0]->[0];
}

sub lanes {
  my ($self) = @_;
  if (!$self->{lanes}) {
    my $ref;
    my $query = q{SELECT DISTINCT rt.position FROM run_tile rt WHERE rt.id_run = ? ORDER BY position};
    eval {
      $ref = $self->util->dbh->selectall_arrayref($query, {}, $self->{id_run});
      1;
    } or do {
      croak $EVAL_ERROR;
    };
    foreach my $lane (@{$ref}) {
      push @{$self->{lanes}}, $lane->[0];
    }
  }
  return $self->{lanes};
}

sub run_tiles {
  my $self = shift;
  my $pkg  = 'npg_qc::model::run_tile';
  if (!$self->{run_tiles}) {
    my $run_tile_obj = npg_qc::model::run_tile->new({ util => $self->util() });
    $run_tile_obj->id_run($self->{id_run});
    $self->{run_tiles} = $run_tile_obj->run_tiles_per_run();
  }
  return $self->{run_tiles};
}

sub run_tiles_uniq_names {
  my $self = shift;
  if (!$self->{run_tiles_uniq_names}) {
    my $run_tiles = $self->run_tiles();
    my $tile_names = {};
    foreach my $run_tile (@{$run_tiles}) {
      my $tile_name = $run_tile->id_run . q{_} . $run_tile->position() . q{_} . $run_tile->tile();
      if ($tile_names->{$tile_name}) {
      } else {
        $tile_names->{$tile_name}++;
        push @{$self->{run_tiles_uniq_names}}, $tile_name;
      }
    }
  }
  return $self->{run_tiles_uniq_names};
}

sub id_run {
  my ($self, $id_run) = @_;
  if (!$id_run) {
    $id_run = $self->{id_run};
    if (!$id_run) {
      my $class = ref $self;
      ($class) = $class =~ /(\w+)$/sxm;
      if ($class eq q[move_z] || $class eq q[run_config] || $class eq q[run_tile]) {
        $id_run = $self->{q[id_] . $class};
      }
    }
  }
  if ($id_run) {
    $self->{id_run} = $id_run;
  }
  return $id_run;
}

sub id_run_pair {
  my ($self, $id_run) = @_;

  if (!$id_run) {
    $id_run = $self->{id_run};
  }
  if (!$id_run) {
    croak 'no id_run given';
  }

  my $chip_summary = npg_qc::model::chip_summary->new({
    util => $self->util(),
    id_run => $id_run,
  });

  if (! exists $self->{already_found}->{$id_run}
      ||
     (!$self->{already_found}->{$id_run} && (($chip_summary->paired() || !$chip_summary->id_chip_summary()) && ! $self->paired_read($id_run) ))
     ) {
    if (($chip_summary->paired() || !$chip_summary->id_chip_summary()) && !$self->paired_read($id_run)) {

      my $run_and_pair_obj = npg_qc::model::run_and_pair->new({
        util   => $self->util,
	     id_run => $id_run,
      });

      if (!$run_and_pair_obj->id_run_pair() && !$self->paired_read($id_run)) {
        my $npg_run = npg::api::run->new({
          id_run => $id_run,
        });

        eval{
           my $id_run_pair = $npg_run->id_run_pair();
           $run_and_pair_obj->id_run_pair($id_run_pair);
	        $run_and_pair_obj->save();
           1;
         } or do {
           carp $EVAL_ERROR;
         };
      }

      foreach my $run_pair (@{$run_and_pair_obj->run_and_pairs()}) {

        $self->{already_found}->{$run_pair->id_run()} = $run_pair->id_run_pair() || q{};

	if ($run_pair->id_run_pair()) {
          $self->{already_found}->{$run_pair->id_run_pair()} = $run_pair->id_run();
	}

      }
    }
  }

  return $self->{already_found}->{$id_run};
}

sub run_having_control_lane {
  my ($self, $id_run) = @_;

  if (!$id_run) {
    $id_run = $self->{id_run};
  }
  if (!$id_run) {
    croak 'no id_run given';
  }

  if( !exists $self->{run_having_control_lane}->{$id_run} ){
    my $npg_run = npg::api::run->new({
          id_run => $id_run,
    });
    if($npg_run->having_control_lane()){
      $self->{run_having_control_lane}->{$id_run} = 1;
    }else{
      $self->{run_having_control_lane}->{$id_run} = 0;
    }
  }
  return $self->{run_having_control_lane}->{$id_run};
}

sub paired_read{
  my ($self, $id_run) = @_;

  if(! exists $self->{paired_read}->{$id_run}){

    my $query = q{SELECT cycle_read1, cycle_read2
                FROM   run_recipe
                WHERE  id_run = ?
                };

    my $dbh = $self->util->dbh();
    my $sth = $dbh->prepare($query);
    $sth->execute($id_run);
    my $row_ref = $sth->fetchrow_arrayref();

    my ($cycle_read1, $cycle_read2);

    if($row_ref){

      $cycle_read1 = $row_ref->[0];
      $cycle_read2 = $row_ref->[1];
    }
    if($cycle_read1 && $cycle_read2){
      $self->{paired_read}->{$id_run} = 1;
    }else{
      $self->{paired_read}->{$id_run} = 0;
    }
  }

  return $self->{paired_read}->{$id_run};
}


sub get_cycle_count_from_recipe{
  my ($self, $id_run, $end) = @_;

  my $actual_id_run = $id_run;
  if($end == 2){

    $actual_id_run = $self->id_run_pair($id_run);
  }

  if(!$actual_id_run){
    $actual_id_run = $id_run;
  }

  my $query = q{SELECT cycle
                FROM   run_recipe
                WHERE  id_run = ?
                };

  my $dbh = $self->util->dbh();
  my $sth = $dbh->prepare($query);
  $sth->execute($actual_id_run);
  my $row_ref = $sth->fetchrow_arrayref();

  my $cycle;

  if($row_ref){

    $cycle = $row_ref->[0];
  }
  return $cycle;
}

sub get_single_read_length_from_recipe{
  my ($self, $id_run, $end) = @_;

  my $query = q{SELECT cycle_read1, cycle_read2, first_indexing_cycle, last_indexing_cycle
                FROM   run_recipe
                WHERE  id_run = ?
                };

  my $dbh = $self->util->dbh();
  my $sth = $dbh->prepare($query);
  $sth->execute($id_run);
  my @row = $sth->fetchrow_array();

  my $read_length;
  if(scalar @row){

    my $cycle_read1 = shift @row;
    my $cycle_read2 = shift @row;
    my $first_indexing_cycle = shift @row;
    my $last_indexing_cycle = shift @row;

    if($end == 1){
      $read_length = $cycle_read1;
      #if($first_indexing_cycle && $last_indexing_cycle){
      #  $read_length += ($last_indexing_cycle - $first_indexing_cycle + 1);
      #}
    }elsif($end == 2){
      $read_length = $cycle_read2;
    }
  }
  return $read_length;
}

sub get_read_cycle_range_from_recipe {
  my ($self, $id_run, $end) = @_;

  if(!$end){
    $end = 0;
  }

  if(!$self->{get_read_cycle_range_from_recipe}->{$id_run}->{$end}){
    my $query = q{SELECT cycle, cycle_read1, cycle_read2, first_indexing_cycle, last_indexing_cycle
                  FROM   run_recipe
                  WHERE  id_run = ?
                };

    my $dbh = $self->util->dbh();
    my $sth = $dbh->prepare($query);
    $sth->execute($id_run);
    my @row = $sth->fetchrow_array();

    my $cycle_range;
    if(! scalar @row){
      return $cycle_range;
    }

    my $cycle = shift @row;
    my $cycle_read1 = shift @row;
    my $cycle_read2 = shift @row;
    my $first_indexing_cycle = shift @row;
    my $last_indexing_cycle = shift @row;

    $cycle_range = [1, $cycle];
    if($end == 1 && $cycle_read1){
      $cycle_range = [1, $cycle_read1];
    }elsif($end == 2 && $cycle_read2){
        $cycle_range = [$cycle_read1 + 1, $cycle];
        if($first_indexing_cycle && $last_indexing_cycle){
          $cycle_range = [$last_indexing_cycle + 1, $cycle];
        }
    }
    $self->{get_read_cycle_range_from_recipe}->{$id_run}->{$end} = $cycle_range;
  }
  return $self->{get_read_cycle_range_from_recipe}->{$id_run}->{$end};
}

sub get_single_read_length{
  my ($self, $id_run, $end) = @_;
  my $error = "Wrong end number for run $id_run: $end";
  # croak for t end moved here to avoid warnings in numeric comparison
  if ($end eq 't') { croak $error; }
  if($end == 1){
    return $self->get_single_read_length_from_recipe($id_run, 1);
  }elsif($end == 2){
    my $paired_id_run = $self->id_run_pair($id_run);
    if($paired_id_run){
      return $self->get_single_read_length_from_recipe($paired_id_run, 1);
    }else{
      return $self->get_single_read_length_from_recipe($id_run, 2);
    }
  }else{
    croak $error;
  }
  return 1;
}

sub get_read_length_from_recipe{
  my ($self, $id_run, $end) = @_;

  my $actual_id_run = $id_run;
  if($end == 2){

    $actual_id_run = $self->id_run_pair($id_run);
  }

  my $query = q{SELECT cycle_read1, cycle_read2, first_indexing_cycle, last_indexing_cycle
                FROM   run_recipe
                WHERE  id_run = ?
                };

  my $dbh = $self->util->dbh();
  my $sth = $dbh->prepare($query);
  $sth->execute($actual_id_run);
  my @row = $sth->fetchrow_array();

  my $read_length = q{};
  if(scalar @row){

    my $cycle_read1 = shift @row;
    my $cycle_read2 = shift @row;
    my $first_indexing_cycle = shift @row;
    my $last_indexing_cycle = shift @row;

    if($cycle_read1){
      $read_length = $cycle_read1;
    }
    if($first_indexing_cycle && $last_indexing_cycle){
      $read_length .= qq{($first_indexing_cycle-$last_indexing_cycle)};
    }
    if($cycle_read2){
      $read_length .= qq{, $cycle_read2};
    }
  }
  return $read_length;
}

sub run_has_swift {
  my ($self, $id_run) = @_;

  if (! exists $self->{run_has_swift}) {

    ($id_run) = $id_run =~ /(\d+)/xms;

    my $query = q{SELECT sr.id_run_tile
                  FROM   swift_report sr,
                         run_tile rt
                  WHERE  rt.id_run      = ?
                  AND    rt.id_run_tile = sr.id_run_tile};

    my $dbh = $self->util->dbh();
    my $sth = $dbh->prepare($query);
    $sth->execute($id_run);
    my $tiles = $sth->fetchrow_arrayref();

    $self->{run_has_swift} = $tiles ? 1
                           :          0
                           ;
  }
  return $self->{run_has_swift};
}

sub run_has_log_metrics {
  my ($self, $id_run) = @_;

  if (! exists $self->{run_has_log_metrics} || $self->{run_has_log_metrics} != $id_run) {

    ($id_run) = $id_run =~ /(\d+)/xms;

    my $query = q{SELECT mz.id_run_tile
                  FROM   move_z mz,
                         run_tile rt
                  WHERE  rt.id_run      = ?
                  AND    rt.id_run_tile = mz.id_run_tile};

    my $dbh = $self->util->dbh();
    my $sth = $dbh->prepare($query);
    $sth->execute($id_run);
    my $tiles = $sth->fetchrow_arrayref();

    $self->{run_has_log_metrics} = $tiles ? $id_run
                                 :          0
                                 ;
  }
  return $self->{run_has_log_metrics};
}

sub run_has_illumina {
  my ($self, $id_run) = @_;

  if (! exists $self->{run_has_illumina}) {

    ($id_run) = $id_run =~ /(\d+)/xms;

    my $query = q{SELECT distinct id_run
                  FROM   run_tile
                  WHERE  id_run      = ?};

    my $dbh = $self->util->dbh();
    my $sth = $dbh->prepare($query);
    $sth->execute($id_run);
    my $tiles = $sth->fetchrow_arrayref();

    $self->{run_has_illumina} = $tiles ? 1
                              :          0
                              ;
  }
  return $self->{run_has_illumina};
}

sub alert_query_appended_to_alert_hash {
  my ($self, $arg_refs) = @_;

  my $query  = $arg_refs->{query};
  my $params = $arg_refs->{params};
  my $hash   = $arg_refs->{hash};
  my $key    = $arg_refs->{key};

  my $dbh = $self->util->dbh();

  my $sth = $dbh->prepare($query);
  $sth->execute(@{$params});

  while (my $row = $sth->fetchrow_hashref()) {
    push @{$hash->{$key}->[$row->{position}]}, $row;
  }

  return 1;
}

sub has_rescore {
  my ($self, $name) = @_;
  my $util     = $self->util();
  my ($id_run, $position, $tile) = split /_/xms, $name;
  my $run_tile = npg_qc::model::run_tile->new({
    util     => $util,
    id_run   => $id_run,
    position => $position,
    tile     => $tile,
    end      => 1,
  });
  $run_tile->read();
  my $new_model = $run_tile->tile_rescore();
  eval {
    $new_model->run_tile($run_tile);
  } or do {
    return 0;
  };
  return 1;
}
sub run_alerts_from_caching{
  my ($self) = @_;

  my $util   = $self->util();

  my %alerts = ();
  if(!$self->{run_alerts}){
    eval {
      my $dbh = $self->util->dbh();
      my $query  = q{SELECT id_run, end, results
                     FROM cache_query
                     WHERE type = 'movez_tiles'
                     AND is_current = 1 };
      $query    .= q{AND results != '$rows_ref = [[''0'']];' ORDER BY id_run DESC, end ASC limit 50}; ## no critic (RequireInterpolationOfMetachars)

      my $sth = $dbh->prepare($query);
      $sth->execute();

      my $rows_ref;
      while (my @row = $sth->fetchrow_array()) {
        eval $row[2]; ## no critic (ErrorHandling::RequireCheckingReturnValueOfEval, ProhibitStringyEval)
        my $num_tiles = $rows_ref->[0][0];
        if($num_tiles >0){
          $alerts{$row[0]}{$row[1]} = $rows_ref->[0][0];
        }
      }

      1;
    } or do {
      croak $EVAL_ERROR;
    };
    $self->{run_alerts} = \%alerts;
  }
  return$self->{run_alerts};
}

sub cache_query_retrieval {
  my ($self, $args) = @_;
  return npg_qc::model::cache_query->new({
    util   => $self->util(),
    id_run => $args->{id_run},
    type   => $args->{type},
    end    => $args->{end} || 1
  });
}

sub retrieve_primary_key_value {
  my ($self) = @_;

  eval {
    my $pkg = ref$self;
    my @fields = $pkg->fields();
    my $pk = shift@fields;
    my $query = qq(SELECT $pk
                   FROM   @{[$pkg->table()]} );
    my $count = 0;
    foreach my $field (@fields) {
      my $clause = $count ? q{AND}
                 :          q{WHERE}
                 ;
      if (defined $self->$field()) {
        $query .= qq($clause $field = '@{[$self->$field()]}' );
        $count++;
      }
    }
    $query .= 'LIMIT 1';
    my $dbh = $self->util->dbh();
    my $sth = $dbh->prepare($query);
    $sth->execute();
    $self->$pk($sth->fetchrow_arrayref()->[0]);
    1;
  } or do {
    croak $EVAL_ERROR;
  };
  return;
}

1;
__END__

=head1 NAME

npg_qc::model - a base class for the npg_qc family, derived from ClearPress::model

=head1 VERSION

$Revision$

=head1 SYNOPSIS

=head1 DESCRIPTION

As legend would have it, this set of modules was Written for SVV in
under 20 minutes in the Autumn of 2006.

=head1 SUBROUTINES/METHODS

=head2 uid - a basic method for generating low-volume (time-based) unique ids

  my $id = $oModelSubClass->uid();

=head2 model_type - a basic method for a model to identify it's model (entity) type by returning last part of ref (package name)

  my $model_type = $oModelSubClass->model_type();

=head2 dbh_datetime - returns a datetime from the database

=head2 lanes - returns an array of lanes for the run, provided id_run has been put on the model

  my $aLanes = $oModelSubClass->lanes();

=head2 run_tiles - returns an array of all the run_tiles for a run, provided id_run has been put on the model

  my $aRunTiles = $oModelSubClass->run_tiles();

=head2 run_tiles_uniq_names - returns an array of all the tiles for a run as a generated unique name in format <id_run>_<position>_<tile>

  my $aRunTilesUniqNames = $oModelSubClass->run_tiles_uniq_names();

=head2 id_run_pair - returns the id_run_pair of a given id_run, should it be paired

  my $iIdRunPair = $oModelSubClass->id_run_pair($id_run);

=head2 run_having_control_lane  - given an id_run, check the run having control lane or not using npg api run

=head2 paired_read - given an id_run, check the run is paired read or not by checking the cycle numbers of read 1 and 2
  
=head2 get_cycle_count_from_recipe - get cycle count from run recipe table based on id_run and end

=head2 run_has_swift - returns Boolean dependent on whether or not data can be found for swift analysis

  my $bRunHasSwift = $oModelSubClass->run_has_swift($id_run);

=head2 run_has_log_metrics - returns Boolean dependent on whether or not data can be found for log metrics

  my $bRunHasLogMetrics = $oModelSubClass->run_has_log_metrics($id_run);

=head2 run_has_illumina - returns Boolean dependent on whether or not data can be found for Illumina analysis

  my $bRunHasIllumina = $oModelSubClass->run_has_illumina($id_run);

=head2 alert_query_appended_to_alert_hash - for alert queries, handles the database query and appending the results into the hash

  my $bAlertQueryAppendedToAlertHash = $oModelSubClass->alert_query_appended_to_alert_hash({
    query => $query,
    params => [],
    hash => {},
    key => $key_to_be_used_in_hash,
  });

=head2 has_rescore - returns Boolean to determine if the run_tile has any rescore data

=head2 run_alerts_from_caching

  my $bHasRescore = $oModelSubClass->has_rescore('<id_run>_<position>_<tile>');

=head2 cache_query_retrieval - quick method to obtain a Cache Query object which will return the query saved

  my $oCacheQuery = $oModelSubClass->cache_query_retrieval({
    util => $oUtil,
    id_run => $iIdRun,
    type => $sTypeOfCachedQuery,
    end  => $iEnd
  });

=head2 retrieve_primary_key_value - method to attempt to populate the primary key of a model object given other populated parameters.

=head2 get_read_length_from_recipe - get cycle details of each run in a string

=head2 get_read_cycle_range_from_recipe - get cycle number range for each read or the whole run

=head2 get_single_read_length_from_recipe - given an id_run and end, return the read length of that read, plus any indexing cycle number if it is the first read of that run.

=head2 get_single_read_length - given an id_run (smaller id_run if paired run) and end, return the read length of that read

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2007 GRL, by Roger Pettett

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut

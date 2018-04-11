package npg_qc::model::run_graph;

use strict;
use warnings;
use base qw(npg_qc::model);
use English qw(-no_match_vars);
use Carp;
use Readonly;
use npg_qc::model::cache_query;

our $VERSION = '0';

Readonly our $PERCENTAGE      => 100;
Readonly our $GIGABASE        => 1_000_000;
Readonly our @CYCLES_AVG_YIELD_PER_LANES => (37, 54, 76, 108);

__PACKAGE__->mk_accessors(__PACKAGE__->fields());
__PACKAGE__->has_all();

sub fields {
  return qw(
            id_run_graph
            id_run
            end
            yield_gb
            avg_error
            avg_cluster_per_tile
            avg_cluster_per_tile_raw
            avg_cluster_per_tile_control
            avg_cluster_per_tile_raw_control
            cycle
          );
}
#given id_run end, find primary key if there is one
sub init {
  my $self = shift;

  if($self->id_run()
     && $self->end()
     &&!$self->id_run_graph()) {

    my $query = q(SELECT id_run_graph
                  FROM   run_graph
                  WHERE  id_run = ? AND end = ?
                 );

    my $ref   = [];

    eval {
      $ref = $self->util->dbh->selectall_arrayref($query, {}, $self->id_run(), $self->end());
      1;
    } or do {
      carp $EVAL_ERROR;
      return;
    };

    if(@{$ref}) {
      $self->id_run_graph($ref->[0]->[0]);
    }
  }
  return 1;
}
#given id_run, end and the cycle count of this run
#get total yield, avg error and avg cluster number per tile for this run
sub get_total_yield_cluster{
  my ($self, $id_run, $end, $cycle) = @_;

  my $query = q{   
         SELECT ROUND(SUM(temp.clusters_raw*temp.perc_pf_clusters*?/?)) AS total_pf_yield,
                ROUND(AVG(temp.clusters_raw*temp.perc_pf_clusters/100)) AS clusters_pf,
                ROUND(AVG(temp.clusters_raw)) AS clusters_raw
         FROM  (SELECT position, tile, clusters_raw, perc_pf_clusters, perc_error_rate_pf
                         FROM  lane_qc lqc, run_tile rt
                         WHERE rt.id_run = ?
                         AND   rt.id_run_tile = lqc.id_run_tile
                         AND   lqc.end = ?
                         ORDER BY position, tile) temp
               };
  eval {
      my $dbh = $self->util->dbh();

      my $sth = $dbh->prepare($query);

      $sth->execute($cycle,($GIGABASE*$PERCENTAGE), $id_run, $end);

      my @row = $sth->fetchrow_array();
      if(@row){
        $self->yield_gb($row[0]);
        $self->avg_cluster_per_tile($row[1]);
        $self->avg_cluster_per_tile_raw($row[2]);
      }
      1;
  } or do {
      croak $EVAL_ERROR;
  };

   return;
}
#given id_run, end
#get the average cluster number per tile for the control lanes
sub get_error_cluster_control_lane{
  my ($self, $id_run, $end,) = @_;

  my $query = q{   
         SELECT ROUND(AVG(temp.clusters_raw*temp.perc_pf_clusters/?)) AS clusters_pf,
                ROUND(AVG(temp.clusters_raw)) AS clusters_raw,
                ROUND(AVG(temp.perc_error_rate_pf),2) AS perc_error_rate
         FROM  (SELECT position, tile, clusters_raw, perc_pf_clusters, perc_error_rate_pf
                         FROM  lane_qc lqc, run_tile rt
                         WHERE rt.id_run = ?
                         AND   rt.id_run_tile = lqc.id_run_tile
                         AND   lqc.end = ?
                         AND   lqc.perc_align_pf IS NOT NULL
                         ORDER BY tile) temp
               };
  eval {
      my $dbh = $self->util->dbh();

      my $sth = $dbh->prepare($query);

      $sth->execute($PERCENTAGE, $id_run, $end);

      my @row = $sth->fetchrow_array();
      if(@row){
        $self->avg_cluster_per_tile_control($row[0]);
        $self->avg_cluster_per_tile_raw_control($row[1]);
        $self->avg_error($row[2]);
      }
      1;
  } or do {
      croak $EVAL_ERROR;
  };

   return;
}

#get the run list which data already being calculated
sub get_runlist_done{
    my ($self) = @_;

    my $runlist;

    my $query = q{SELECT id_run, end
                  FROM run_graph
                  WHERE yield_gb IS NOT NULL
                  AND avg_cluster_per_tile_raw IS NOT NULL;
                 };
    eval {
      my $dbh = $self->util->dbh();
      #print $query, "\n";
      my $sth = $dbh->prepare($query);

      $sth->execute();

      while (my @row = $sth->fetchrow_array()){
        $runlist->{$row[0]}->{$row[1]} = 1;
      }

      1;
    } or do {
      croak $EVAL_ERROR;
    };

  return $runlist;
}
#get the run list which data need to be calculated
sub get_runlist_todo{
    my ($self) = @_;

    my $runlist_todo;

    my $runlist_done = $self->get_runlist_done();

    my $query = q{
SELECT id_run, end
FROM cache_query
WHERE type= 'lane_summary'
AND is_current = 1
                 };

    eval {
      my $dbh = $self->util->dbh();
      #print $query, "\n";
      my $sth = $dbh->prepare($query);

      $sth->execute();

      while (my @row = $sth->fetchrow_array()){
         my $id_run = $row[0];
         my $end = $row[1];

         if(!$runlist_done->{$id_run}->{$end}){
            push @{$runlist_todo}, \@row;
         }
      }

      1;
    } or do {
      croak $EVAL_ERROR;
    };

  return $runlist_todo;
}
#given an id_run, get the cycle_count for this run via cache table
sub get_cycle_count_from_cache{
    my ($self, $id_run, $end) = @_;

    my $util = $self->{util};

    my $cycle_count;

    my $cache_cycle_count = npg_qc::model::cache_query->new({
                                 util => $util,
                                 id_run => $id_run,
                                 end => $end,
                                 type =>'cycle_count',
                            });
    my $rows_ref = $cache_cycle_count->get_cache_by_id_type_end();
    if($rows_ref){
      $cycle_count = $rows_ref->[0][0];
    }
    return $cycle_count;
}
#given an id_run, get the cycle_count for this run via direct query
sub get_cycle_count_direct{
    my ($self, $id_run, $end) = @_;
    my $cycle_count = $self->get_cycle_count_from_db($id_run, $end, q{errors_by_cycle});
    return $cycle_count;
}

sub get_cycle_count_from_db{
    my ($self, $id_run, $end, $table_name) = @_;

    my $query = qq{SELECT MAX(cycle) FROM $table_name ec, run_tile rt}
             .q{ WHERE rt.id_run = ? AND rt.end = ? AND rt.id_run_tile = ec.id_run_tile};
    my $cycle_count;
    eval {
      my $dbh = $self->util->dbh();
      #print $query, "\n";
      my $sth = $dbh->prepare($query);

      $sth->execute($id_run, $end);

      my @row = $sth->fetchrow_array();
      if(@row){
        $cycle_count = $row[0];
      }
      1;
    } or do {
      croak $EVAL_ERROR;
    };
    if(!$cycle_count){
    }
    return $cycle_count;
}
#given an id_run, get the cycle_count for this run
sub get_cycle_count{
  my ($self, $id_run, $end) = @_;

  my $cycle_count_from_recipe = $self->get_single_read_length($id_run, $end);
  if($cycle_count_from_recipe){
    return $cycle_count_from_recipe;
  }

  my $cycle_count_cached = $self->get_cycle_count_from_cache($id_run, $end);
  if($cycle_count_cached){

    return $cycle_count_cached;
  }else{
    my $cycle_count_direct = $self->get_cycle_count_direct($id_run, $end);
    if($cycle_count_direct){
      return $cycle_count_direct;
    }
    croak "can not get cycle count for run $id_run\n";
  }
  return;
}

sub calculate_one_run{
  my ($self, $run_id, $end) = @_;

  my $util = $self->{util};
  my $run_graph_model;
  eval{
    my $cycle_count = $self->get_cycle_count($run_id, $end);

    $run_graph_model = npg_qc::model::run_graph->new({
                                  util => $util,
                                  id_run => $run_id,
                                  end    => $end,
                                  cycle=> $cycle_count,
                               });

    $run_graph_model->get_total_yield_cluster($run_id, $end, $cycle_count);
    $run_graph_model->get_error_cluster_control_lane($run_id, $end);
    if(defined $run_graph_model->yield_gb()
     ){
       $run_graph_model->save();
    }else{
      carp "there is no run graph data for caching for run $run_id end $end";
    }

    1;
  } or do{
    croak $EVAL_ERROR;
  };

  return $run_graph_model;
}
#get list of runs which data need to be calculated,
#calculate and save to the database
sub calculate_all{
  my ($self) = @_;

  my $util = $self->{util};

  my $runlist_todo = $self->get_runlist_todo();

  if (!$runlist_todo) {
    carp 'there are no runs to calculate run_graph';
    return 0;
  }
  carp 'there are '.(scalar @{$runlist_todo}).' to cache run_graph data';

  $util->transactions(0);
  eval{

    foreach my $run_end (@{$runlist_todo}){

      my $run_id = $run_end->[0];
      my $end = $run_end->[1];
      my $run_graph_model;
      eval{
	     my $cycle_count= $self->get_cycle_count($run_id, $end);
	     $run_graph_model = npg_qc::model::run_graph->new({
				                            util => $util,
				                            id_run => $run_id,
				                            end    => $end,
				                            cycle =>$cycle_count,
			                     });
	     $run_graph_model->get_total_yield_cluster($run_id, $end, $cycle_count);
	     $run_graph_model->get_error_cluster_control_lane($run_id, $end);


	     if(defined $run_graph_model->yield_gb()){
            $run_graph_model->save();
        }else{
            carp "there is no run graph data for caching for run $run_id end $end";
        }
	     1;
      } or do{
        carp $EVAL_ERROR;
	     next;
      };
    }
    $util->dbh->commit();
    $util->transactions(1);
    1;
  } or do {
    $util->transactions(1);
    $util->dbh->rollback();
    croak $EVAL_ERROR;
  };

  return scalar @{$runlist_todo};
}

sub get_yield_by_run {
  my ($self, $num_runs, $cycle_length) = @_;
  $num_runs ||= $self->{graph_size};
  $cycle_length ||= $self->{cycle_length};
  $cycle_length ||= 0;

  if($self->{get_yield_by_run}->{$num_runs}->{$cycle_length}){
    return $self->{get_yield_by_run}->{$num_runs}->{$cycle_length};
  }

  my @rows;

  eval {
    my $dbh = $self->util->dbh();
    my $query = q{SELECT temp.id_run, temp.yield_gb, temp.cycle, temp.end
                  FROM (SELECT id_run, yield_gb, cycle, end FROM run_graph};
    if(defined $cycle_length && $cycle_length != 0){
        $query .= qq{ WHERE cycle = $cycle_length};
    }
        $query .= q{ ORDER BY id_run DESC LIMIT 0, };
        $query .= $num_runs;
        $query .= q{ )
                  temp
                  ORDER BY id_run ASC, end ASC
                 };

    my $sth = $dbh->prepare($query);

    $sth->execute();

    while (my @row = $sth->fetchrow_array()) {
      push @rows, \@row;
    }
    1;
  } or do {
    croak $EVAL_ERROR;
  };

  if (!scalar@rows) {
    return [];
  }

  $self->{get_yield_by_run}->{$num_runs}->{$cycle_length} = \@rows;

  return $self->{get_yield_by_run}->{$num_runs}->{$cycle_length};
}

sub get_yield_avg {
  my ($self, $num_runs, $cycle_length) = @_;
  my $data = $self->get_yield_by_run($num_runs, $cycle_length);
  my $num_runs_actual = 0;
  my $total = 0;
  foreach my $run (@{$data}) {
    my $yield = $run->[1];
    if(defined $yield){
      $total += $yield;
      $num_runs_actual++;
    }
  }
  if($num_runs_actual){
    return sprintf '%.02f', $total/$num_runs_actual;
  }
  return q{NULL};
}

sub get_error_avg {
  my ($self, $num_runs, $cycle_length) = @_;
  my $data = $self->get_avg_error_by_run($num_runs, $cycle_length);
  my $num_runs_actual = 0;
  my $total = 0;
  foreach my $run (@{$data}) {
    my $error = $run->[1];
    if(defined $error){
      $total += $error;
      $num_runs_actual++;
    }
  }
  if($num_runs_actual){
    return sprintf '%.02f', $total/$num_runs_actual;
  }
  return q{NULL};
}

sub get_avg_error_by_run {
  my ($self, $num_runs, $cycle_length) = @_;
  $num_runs ||= $self->{graph_size};
  $cycle_length ||= $self->{cycle_length};
  $cycle_length ||= 0;

  if($self->{get_avg_error_by_run}->{$num_runs}->{$cycle_length}){
    return $self->{get_avg_error_by_run}->{$num_runs}->{$cycle_length};
  }

  my @rows;

  eval {
    my $dbh = $self->util->dbh();
    my $query = q{SELECT temp.id_run, temp.avg_error, temp.cycle, temp.end
                  FROM (SELECT id_run, avg_error, cycle, end  FROM run_graph};
    if(defined $cycle_length && $cycle_length != 0){
      $query .= qq{ WHERE cycle = $cycle_length};
    }
        $query .= q{ ORDER BY id_run DESC LIMIT 0, };
        $query .= $num_runs;
        $query .= q{ )
                  temp
                  ORDER BY id_run ASC, end ASC
                 };
    my $sth = $dbh->prepare($query);

    $sth->execute();

    while (my @row = $sth->fetchrow_array()) {
      push @rows, \@row;
    }
    1;
  } or do {
    croak $EVAL_ERROR;
  };

  if (!scalar@rows) {
    return [];
  }

  $self->{get_avg_error_by_run}->{$num_runs}->{$cycle_length} = \@rows;
  return $self->{get_avg_error_by_run}->{$num_runs}->{$cycle_length};
}

sub get_clusters_per_tile_avg {
  my ($self, $num_runs, $cycle_length) = @_;
  if (!$self->{get_clusters_per_tile_avg} ) {
    my $data = $self->get_cluster_per_tile_by_run($num_runs, $cycle_length);
    my $num_runs_actual = 0;
    my $pf_total  = 0;
    my $raw_total = 0;
    foreach my $run (@{$data}) {
      my $pf_cluster = $run->[1];
      my $raw_cluster =  $run->[2];
      if(defined $pf_cluster && defined $raw_cluster){
        $pf_total += $pf_cluster;
        $raw_total +=$raw_cluster ;
        $num_runs_actual++;
      }
    }
    if($num_runs_actual){
      my $pf_average = sprintf '%.02f', $pf_total/$num_runs_actual;
      my $raw_average = sprintf '%.02f', $raw_total/$num_runs_actual;
      $self->{get_clusters_per_tile_avg} = { pf => $pf_average, raw =>$raw_average };
    }else{
      $self->{get_clusters_per_tile_avg} = { pf => q{NULL}, raw =>q{NULL} };
    }

  }
  return $self->{get_clusters_per_tile_avg};
}

sub get_cluster_per_tile_by_run {
  my ($self, $num_runs, $cycle_length) = @_;
  $num_runs ||= $self->{graph_size};
  $cycle_length ||= $self->{cycle_length};
  $cycle_length ||= 0;

  if($self->{get_cluster_per_tile_by_run}->{$num_runs}->{$cycle_length}){
    return $self->{get_cluster_per_tile_by_run}->{$num_runs}->{$cycle_length};
  }

  my @rows;

  eval {
    my $dbh = $self->util->dbh();
    my $query = q{SELECT temp.id_run, temp.avg_cluster_per_tile, temp.avg_cluster_per_tile_raw, temp.cycle, temp.end
                  FROM (SELECT id_run, avg_cluster_per_tile, avg_cluster_per_tile_raw, cycle, end
                     FROM run_graph};
    if(defined $cycle_length && $cycle_length != 0){
      $query .= qq{ WHERE cycle = $cycle_length};
    }
        $query .= q{ ORDER BY id_run DESC LIMIT 0, };
        $query .= $num_runs;
        $query .= q{ )
                  temp
                  ORDER BY id_run ASC, end ASC
                 };

    my $sth = $dbh->prepare($query);

    $sth->execute();

    while (my @row = $sth->fetchrow_array()) {
      push @rows, \@row;
    }
    1;
  } or do {
    croak $EVAL_ERROR;
  };

  if (!scalar@rows) {
    return [];
  }
  $self->{get_cluster_per_tile_by_run}->{$num_runs}->{$cycle_length} = \@rows;
  return $self->{get_cluster_per_tile_by_run}->{$num_runs}->{$cycle_length};
}

sub get_clusters_per_tile_control_avg {
  my ($self, $num_runs, $cycle_length) = @_;

  if (!$self->{get_clusters_per_tile_control_avg} ) {
    my $data = $self->get_cluster_per_tile_control_by_run($num_runs, $cycle_length);
    my $num_runs_actual = 0;

    my $pf_total  = 0;
    my $raw_total = 0;
    foreach my $run (@{$data}) {
      my $pf_cluster = $run->[1];
      my $raw_cluster =  $run->[2];
      if(defined $pf_cluster && defined $raw_cluster){
        $pf_total += $pf_cluster;
        $raw_total +=$raw_cluster ;
        $num_runs_actual++;
      }
    }
    if($num_runs_actual){
      my $pf_average = sprintf '%.02f', $pf_total/$num_runs_actual;
      my $raw_average = sprintf '%.02f', $raw_total/$num_runs_actual;
      $self->{get_clusters_per_tile_control_avg} = { pf =>$pf_average, raw => $raw_average};
    }else{
      $self->{get_clusters_per_tile_control_avg} = { pf =>q{NULL}, raw =>q{NULL}};
    }
  }

  return $self->{get_clusters_per_tile_control_avg};
}

sub get_cluster_per_tile_control_by_run {
  my ($self, $num_runs, $cycle_length) = @_;
  $num_runs ||= $self->{graph_size};
  $cycle_length ||= $self->{cycle_length};
  $cycle_length ||= 0;

  if($self->{get_cluster_per_tile_control_by_run}->{$num_runs}->{$cycle_length}){
    return $self->{get_cluster_per_tile_control_by_run}->{$num_runs}->{$cycle_length};
  }

  my @rows;

  eval {
    my $dbh = $self->util->dbh();
    my $query = q{SELECT temp.id_run, temp.avg_cluster_per_tile_control, temp.avg_cluster_per_tile_raw_control, temp.cycle, temp.end
                  FROM
                    (SELECT id_run, avg_cluster_per_tile_control, avg_cluster_per_tile_raw_control, cycle, end
                     FROM run_graph};
    if(defined $cycle_length && $cycle_length != 0){
      $query .= qq{ WHERE cycle = $cycle_length};
    }
        $query .= q{ ORDER BY id_run DESC LIMIT 0, };
        $query .= $num_runs;
        $query .= q{ )
                  temp
                  ORDER BY id_run ASC, end ASC
                 };

    my $sth = $dbh->prepare($query);

    $sth->execute();

    while (my @row = $sth->fetchrow_array()) {
      push @rows, \@row;
    }
    1;
  } or do {
    croak $EVAL_ERROR;
  };

  if (!scalar@rows) {
    return [];
  }

  $self->{get_cluster_per_tile_control_by_run}->{$num_runs}->{$cycle_length} = \@rows;
  return $self->{get_cluster_per_tile_control_by_run}->{$num_runs}->{$cycle_length};
}

1;
__END__
=head1 NAME

npg_qc::model::run_graph

=head1 SYNOPSIS

  my $oRun_graph = npg_qc::model::run_graph->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2  fields - a list of fields

=head2  calculate_all - get list of runs which data need to be calculated, calculate and save to the database

=head2  calculate_one_run - calculate and save data for one run

=head2  get_error_cluster_control_lane - given id_run and end, get the average cluster number per tile for the control lanes, and average error per tile for control lanes

=head2  get_cycle_count - given an id_run, get the cycle_count for this run

=head2  get_cycle_count_direct - given an id_run, get the cycle_count for this run via direct query

=head2  get_cycle_count_from_cache - given an id_run, get the cycle_count for this run via cache table

=head2  get_pair_id_run - given id_run, get the id_run for its paired run

=head2  get_runlist_done - get the run list which data already being calculated

=head2  get_runlist_todo - get the run list which data need to be calculated

=head2  get_total_yield_cluster - given id_run, end and the cycle count of one run, get total yield and avg cluster number per tile for this run

=head2  init - given id_run, find primary key if there is one

=head2  get_actual_id_run - get the actual id_run number based on its end

=head2  get_yield_by_run - given the number for the last runs, get data by run from database

=head2  get_avg_error_by_run - given the number for the last runs, get data by run from database

=head2  get_cluster_per_tile_by_run - given the number for the last runs, get data by run from database

=head2  get_cluster_per_tile_control_by_run - given the number for the last runs, get data by run from database

=head2 get_clusters_per_tile_avg - calculate the average of data

=head2 get_clusters_per_tile_control_avg - calculate the average of data

=head2 get_error_avg - calculate the average of data

=head2 get_yield_avg - calculate the average of data

=head2 get_cycle_count_from_db

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

strict
warnings
npg_qc::model
Carp
Readonly

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Guoying Qi, E<lt>gq1@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Guoying Qi

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut

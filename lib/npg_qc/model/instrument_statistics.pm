package npg_qc::model::instrument_statistics;
use strict;
use warnings;
use base qw(npg_qc::model);
use English qw(-no_match_vars);
use Carp;
use Readonly;


our $VERSION = '0';

Readonly our $CLUSTER_GA1_RAW_MINIMUM  => 15_000;
Readonly our $CLUSTER_GA1_RAW_MAX      => 50_000;
Readonly our $CLUSTER_GA2_RAW_MINIMUM  => 100_000;
Readonly our $CLUSTER_GA2_RAW_MAX      => 200_000;
Readonly our $PERC_ERROR_RATE_MINIMUM  => 2;
Readonly our $TILES_ON_GA2             => 100;
Readonly our $HIGH_TWENTIETH_CYCLE_MAX => 100;
Readonly our $LOW_TWENTIETH_CYCLE_MIN  => 60;
Readonly our $DEFAULT_NUMBER_OF_RUNS   => 25;
Readonly our $DEFAULT_NUMBER_OF_LATEST_RUNS   => 4;
Readonly our $THIRD                    => 3;
Readonly our $FOURTH                   => 4;

__PACKAGE__->mk_accessors(__PACKAGE__->fields());

sub default_number_of_runs {
  my ($self) = @_;
  return $DEFAULT_NUMBER_OF_RUNS;
}

sub fields {
  return qw(
            id_instrument_statistics
            id_run
            end
            id_run_actual
            instrument
            num_tile_low_cluster
            num_tile_high_cluster
            num_tile_high_intensity
            num_tile_low_intensity
            num_tile_high_error
            num_tile_movez_out
           );
}
#given id_run, find primary key if there is one
sub init {
  my $self = shift;

  if($self->id_run() && $self->end()
     &&!$self->id_instrument_statistics()) {

    my $query = q(SELECT id_instrument_statistics
                  FROM   instrument_statistics
                  WHERE  id_run = ?
                  AND    end = ?
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
      $self->id_instrument_statistics($ref->[0]->[0]);
    }
  }
  return 1;
}

sub calculate_all{
  my ($self) = @_;

  my $util = $self->{util};

  my $runlist_todo = $self->get_runlist_todo();

  if (!$runlist_todo) {
    carp 'there are no runs to calculate instrument statistics';
    return 0;
  }
  carp 'there are '.(scalar @{$runlist_todo}).' to cache instrument statistics';

  $util->transactions(0);
  eval{

    foreach my $run_end (@{$runlist_todo}){

      my $run_id = $run_end->[0];
      my $end = $run_end->[1];
      my $instrument_statistics_model;
      #warn "$run_id:$end";
      eval{

	     $instrument_statistics_model = npg_qc::model::instrument_statistics->new({
				                            util => $util,
				                            id_run => $run_id,
				                            end    => $end,
			                     });
        $instrument_statistics_model->get_all_field_from_db();
        $util->dbh->commit();
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


sub get_runlist_todo{
    my ($self) = @_;

    my $runlist_todo = [];

    my $query = q{
SELECT id_run, end
FROM cache_query
WHERE type= 'lane_summary'
AND is_current = 1
AND (id_run, end) NOT IN (SELECT id_run, end FROM instrument_statistics)
                 };

    eval {
      my $dbh = $self->util->dbh();
      #print $query, "\n";
      my $sth = $dbh->prepare($query);

      $sth->execute();

      while (my @row = $sth->fetchrow_array()){

         push @{$runlist_todo}, \@row;
      }

      1;
    } or do {
      croak $EVAL_ERROR;
    };

  return $runlist_todo;
}

sub get_all_field_from_db{
  my ($self) = @_;
  my $util = $self->{util};
  eval{
    $self->get_id_run_actual();
    $self->get_instrument();
    $self->get_num_tile_movez_out();
    $self->get_num_tiles_low_cluster();
    $self->get_num_tiles_high_cluster();
    $self->get_num_tiles_low_intensity();
    $self->get_num_tiles_high_intensity();
    $self->get_num_tiles_high_error();

    if($self->id_run() && $self->end() && $self->instrument() && $self->id_run_actual()){

      $self->save();
    }
    1;
  } or do {
    croak $EVAL_ERROR;
  };

  return 1;
}
sub tile_max {
  my ($self, $id_run) = @_;
  $id_run ||= $self->id_run();
  if (!$self->{tile_max}) {
    my $query = q(SELECT max(tile) FROM run_tile where id_run = ?);
    my $ref = $self->util->dbh->selectall_arrayref($query, {}, $id_run);
    $self->{tile_max} = $ref->[0]->[0];
  }
  return $self->{tile_max};



  if (!$self->{tile_max}) {
    my $rt = npg_qc::model::run_tile->new({ util => $self->util() });
    $self->{tile_max} = $rt->tile_max($id_run);
  }

  return $self->{tile_max};
}

sub get_id_run_actual{
  my ($self) = @_;
  $self->id_run_actual($self->id_run);
  return;
}

sub get_instrument{
    my ($self) = @_;

    my $query = q{ 
                  SELECT machine FROM chip_summary
                  WHERE id_run = ?;          
                 };

  eval {
      my $dbh = $self->util->dbh();

      my $sth = $dbh->prepare($query);

      $sth->execute($self->id_run());

      my @row = $sth->fetchrow_array();
      if(@row){
        $self->instrument($row[0]);
      }
      1;
  } or do {
      croak $EVAL_ERROR;
  };
  return 1;
}
sub get_num_tile_movez_out{
   my ($self) = @_;
   my $query = q{SELECT results
                 FROM cache_query
                 WHERE type ='movez_tiles'
                 AND id_run = ?
                 AND end = ?             
               };

  eval {
      my $dbh = $self->util->dbh();

      my $sth = $dbh->prepare($query);

      $sth->execute($self->id_run, $self->end());

      my @row = $sth->fetchrow_array();
      if(@row){
        my $rows_ref;
        eval $row[0];## no critic (ProhibitStringyEval,RequireCheckingReturnValueOfEval)
        $self->num_tile_movez_out($rows_ref->[0][0]);
      }
      1;
  } or do {
      croak $EVAL_ERROR;
  };
   return 1;
}
sub get_num_tiles_low_cluster{
  my ($self) = @_;

  my $query = q{   
                SELECT COUNT(*) as num_tiles_low_cluster
                FROM   lane_qc lqc, run_tile rt
                WHERE  rt.id_run_tile = lqc.id_run_tile
                AND    lqc.clusters_raw < ?
                AND    rt.id_run = ?
                AND    rt.end = 1               
               };
   my  $cluster_raw_min;

   if ($self->tile_max($self->id_run()) == $TILES_ON_GA2) {

      $cluster_raw_min = $CLUSTER_GA2_RAW_MINIMUM;
   } else {

      $cluster_raw_min = $CLUSTER_GA1_RAW_MINIMUM;
   }

  eval {
      my $dbh = $self->util->dbh();

      my $sth = $dbh->prepare($query);

      $sth->execute($cluster_raw_min, $self->id_run());

      my @row = $sth->fetchrow_array();
      if(@row){

        $self->num_tile_low_cluster($row[0]);
      }
      1;
  } or do {
      croak $EVAL_ERROR;
  };

  return 1;
}

sub get_num_tiles_high_cluster{
  my ($self) = @_;

  my $query = q{   
                SELECT COUNT(*) as num_tiles_high_cluster
                FROM   lane_qc lqc, run_tile rt
                WHERE  rt.id_run_tile = lqc.id_run_tile
                AND    lqc.clusters_raw > ?
                AND    rt.id_run = ?
                AND    rt.end = 1               
               };
   my  $cluster_raw_max;

   if ($self->tile_max($self->id_run()) == $TILES_ON_GA2) {

      $cluster_raw_max = $CLUSTER_GA2_RAW_MAX;
   } else {

      $cluster_raw_max = $CLUSTER_GA1_RAW_MAX;
   }

  eval {
      my $dbh = $self->util->dbh();

      my $sth = $dbh->prepare($query);

      $sth->execute($cluster_raw_max, $self->id_run());

      my @row = $sth->fetchrow_array();
      if(@row){

        $self->num_tile_high_cluster($row[0]);
      }
      1;
  } or do {
      croak $EVAL_ERROR;
  };

  return 1;
}

sub get_num_tiles_low_intensity{
  my ($self) = @_;

  my $query = q{   
                SELECT COUNT(*) as num_tiles_low_intensity
                FROM   lane_qc lqc, run_tile rt
                WHERE  rt.id_run_tile = lqc.id_run_tile
                AND    lqc.av_perc_intensity_after_20_cycles_pf < ?
                AND    rt.id_run = ?
                AND    rt.end = ?               
               };


  eval {
      my $dbh = $self->util->dbh();

      my $sth = $dbh->prepare($query);

      $sth->execute($LOW_TWENTIETH_CYCLE_MIN, $self->id_run(), $self->end());

      my @row = $sth->fetchrow_array();
      if(@row){

        $self->num_tile_low_intensity($row[0]);
      }
      1;
  } or do {
      croak $EVAL_ERROR;
  };

  return 1;
}

sub get_num_tiles_high_intensity{
  my ($self) = @_;

  my $query = q{   
                SELECT COUNT(*) as num_tiles_high_intensity
                FROM   lane_qc lqc, run_tile rt
                WHERE  rt.id_run_tile = lqc.id_run_tile
                AND    lqc.av_perc_intensity_after_20_cycles_pf > ?
                AND    rt.id_run = ?
                AND    rt.end = ?               
               };


  eval {
      my $dbh = $self->util->dbh();

      my $sth = $dbh->prepare($query);

      $sth->execute($HIGH_TWENTIETH_CYCLE_MAX, $self->id_run(), $self->end());

      my @row = $sth->fetchrow_array();
      if(@row){

        $self->num_tile_high_intensity($row[0]);
      }
      1;
  } or do {
      croak $EVAL_ERROR;
  };

  return 1;
}

sub get_num_tiles_high_error{
  my ($self) = @_;

  eval {
      my $dbh = $self->util->dbh();
      my $id_run = $self->id_run();
      my $end = $self->end();
      my $query = q{   
                SELECT COUNT(*) as num_tiles_high_error
                FROM   lane_qc lqc, run_tile rt
                WHERE  rt.id_run_tile = lqc.id_run_tile
                AND    lqc.perc_error_rate_pf > ?
                AND    rt.id_run = ?
                AND    rt.end = ?               
               };

      my $sth = $dbh->prepare($query);

      $sth->execute($PERC_ERROR_RATE_MINIMUM, $id_run, $end);

      my @row = $sth->fetchrow_array();
      if(@row){

        $self->num_tile_high_error($row[0]);
      }

      1;
  } or do {
      croak $EVAL_ERROR;
  };

  return 1;
}

sub instruments {
  my ($self) = @_;
  my $query = q{SELECT DISTINCT instrument FROM instrument_statistics ORDER BY instrument};
  my $insts = $self->util->dbh->selectall_arrayref($query, {});
  foreach my $inst (@{$insts}) {
    $inst = $inst->[0];
  }
  return $insts;
}

sub instrument_statistic_graph_refactor {
  my ($self, $arg_ref) = @_;

  my $instrument = $arg_ref->{instrument};
  my $no_of_runs = $arg_ref->{no_of_runs} || $DEFAULT_NUMBER_OF_RUNS;
  my $column     = $arg_ref->{column};
  my $cycle_length = $arg_ref->{cycle_length};

  my $query = qq{SELECT r.id_run AS id_run, $column
                 FROM instrument_statistics i, run_graph r
                 WHERE i.instrument = ?
                 AND i.$column IS NOT NULL
                 AND i.id_run = r.id_run
                 AND i.end = r.end };

  if(defined $cycle_length && $cycle_length){
      $query .= qq{ AND r.cycle = $cycle_length};
  }

  $query .= q{   ORDER BY r.id_run DESC, r.end ASC 
                 LIMIT ?};

  my $dbh = $self->util->dbh();
  my $results = $dbh->selectall_arrayref($query, {}, $instrument, $no_of_runs);

  $no_of_runs = scalar@{$results};

  my @reversed_results = reverse @{$results};

  return (\@reversed_results, $no_of_runs);
}

sub low_clusters {
  my ($self, $arg_ref) = @_;
  $arg_ref->{column} = q{num_tile_low_cluster};
  return $self->instrument_statistic_graph_refactor($arg_ref);
}
sub high_clusters {
  my ($self, $arg_ref) = @_;
  $arg_ref->{column} = q{num_tile_high_cluster};
  return $self->instrument_statistic_graph_refactor($arg_ref);
}

sub low_intensity {
  my ($self, $arg_ref) = @_;
  $arg_ref->{column} = q{num_tile_low_intensity};
  return $self->instrument_statistic_graph_refactor($arg_ref);
}
sub high_intensity {
  my ($self, $arg_ref) = @_;
  $arg_ref->{column} = q{num_tile_high_intensity};
  return $self->instrument_statistic_graph_refactor($arg_ref);
}
sub high_error {
  my ($self, $arg_ref) = @_;
  $arg_ref->{column} = q{num_tile_high_error};
  return $self->instrument_statistic_graph_refactor($arg_ref);
}
sub movez_out {
  my ($self, $arg_ref) = @_;
  $arg_ref->{column} = q{num_tile_movez_out};
  return $self->instrument_statistic_graph_refactor($arg_ref);
}

sub yield_per_run{
  my ($self, $arg_ref) = @_;

  my $instrument = $arg_ref->{instrument};
  my $no_of_runs = $arg_ref->{no_of_runs} || $DEFAULT_NUMBER_OF_RUNS;
  my $cycle_length = $arg_ref->{cycle_length};

  my $query = q{SELECT rg.id_run , yield_gb
                 FROM run_graph rg, instrument_statistics i
                 WHERE rg.id_run = i.id_run
                 AND rg.end = i.end
                 AND instrument = ? };

  if(defined $cycle_length && $cycle_length){
      $query .= qq{ AND rg.cycle = $cycle_length};
  }
  $query .= q{ ORDER BY rg.id_run DESC , rg.end DESC LIMIT ?};

  my $dbh = $self->util->dbh();
  my $results = $dbh->selectall_arrayref($query, {}, $instrument, $no_of_runs);

  $no_of_runs = scalar@{$results};

  my @reversed_results = reverse @{$results};

  return (\@reversed_results, $no_of_runs);
}

sub avg_error_per_run{
  my ($self, $arg_ref) = @_;

  my $instrument = $arg_ref->{instrument};
  my $no_of_runs = $arg_ref->{no_of_runs} || $DEFAULT_NUMBER_OF_RUNS;
  my $cycle_length = $arg_ref->{cycle_length};

  my $query = q{SELECT rg.id_run , avg_error
                 FROM run_graph rg, instrument_statistics i
                 WHERE rg.id_run = i.id_run
                 AND rg.end = i.end
                 AND instrument = ? };
  if(defined $cycle_length && $cycle_length){
     $query .= qq{ AND rg.cycle = $cycle_length};
  }
  $query .=    q{ ORDER BY rg.id_run DESC, rg.end DESC LIMIT ?};

  my $dbh = $self->util->dbh();
  my $results = $dbh->selectall_arrayref($query, {}, $instrument, $no_of_runs);

  $no_of_runs = scalar@{$results};

  my @reversed_results = reverse @{$results};

  return (\@reversed_results, $no_of_runs);
}

sub latest_runs_by_instrument{
  my ($self, $no_of_runs) = @_;

  $no_of_runs ||= $DEFAULT_NUMBER_OF_LATEST_RUNS;

  if(!$self->{latest_runs}){

    my $query = qq{SELECT i.instrument, i.id_run, i.end, r.avg_error, r.cycle
                FROM instrument_statistics i, run_graph r
                WHERE $no_of_runs >= (SELECT count(distinct ist.id_run)
                                      FROM instrument_statistics ist
                                      WHERE ist.instrument = i.instrument
                                      AND ist.id_run>=i.id_run)
                AND r.id_run = i.id_run
                AND r.end = i.end
                ORDER BY i.instrument, i.id_run desc, i.end asc};
    my $latest_runs = {};
    eval{
      my $dbh = $self->util->dbh();
      my $sth = $dbh->prepare($query);

      $sth->execute();
      my $paired_run_count = 0;
      while (my @row = $sth->fetchrow_array()){
        my $instrument_no = $row[0];
        $instrument_no =~ s/IL//sm;
        my $first_id_run = $row[1];
        if( ! $latest_runs->{$instrument_no}->{$first_id_run} ){
          push @{$latest_runs->{$instrument_no}->{$first_id_run}}, [$row[$FOURTH], $row[$THIRD]];
        }else{
          push @{$latest_runs->{$instrument_no}->{$first_id_run}}, [$row[$THIRD]];
        }
      }
      $self->{latest_runs} = $latest_runs;
      1;
    } or do {
      croak $EVAL_ERROR;
    };
  }
  return $no_of_runs;
}
1;
__END__

=head1 NAME

npg_qc::model::instrument_statistics

=head1 SYNOPSIS

  my $oRun_graph = npg_qc::model::instrument_statistics->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 init
=head2 fields
=head2 default_number_of_runs
=head2 calculate_all
=head2 get_runlist_todo
=head2 get_all_field_from_db
=head2 tile_max
=head2 get_instrument
=head2 get_id_run_actual
=head2 get_num_tile_movez_out
=head2 get_num_tiles_low_cluster
=head2 get_num_tiles_high_cluster
=head2 get_num_tiles_low_intensity
=head2 get_num_tiles_high_intensity
=head2 get_num_tiles_high_error
=head2 instruments
=head2 instrument_statistic_graph_refactor
=head2 low_clusters
=head2 high_clusters
=head2 low_intensity
=head2 high_intensity
=head2 high_error
=head2 movez_out
=head2 yield_per_run
=head2 avg_error_per_run
=head2 latest_runs_by_instrument

=head1 DIAGNOSTIC

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

Copyright (C) 2017 GRL

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut

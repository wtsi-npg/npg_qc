#########
# Author:        gq1
# Maintainer:    $Author$
# Created:       2008-09-23
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

package npg_qc::model::cache_query;
use strict;
use warnings;
use base qw(npg_qc::model);
use English qw(-no_match_vars);
use Carp;
use Readonly;
use Digest::SHA1;
use MIME::Base64;
use Data::Dumper;

our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/mxs; $r; };


Readonly our $PERCENTAGE => 100;
Readonly our $KILOBASE   => 1000;

__PACKAGE__->mk_accessors(__PACKAGE__->fields());
__PACKAGE__->has_all();

sub fields {
  return qw(
            id_cache_query
            cache_time
            ssha_sql
            id_run
            end
            type
            results
            is_current
          );
}

sub init {
  my $self = shift;

  if($self->id_run() && $self->end() && $self->type()
     && !$self->id_cache_query()) {

    my $query = q(SELECT id_cache_query
                  FROM   cache_query
                  WHERE  id_run = ?
                  AND    end = ?
                  AND    type = ?
                  AND    is_current = 1
                 );

    my $ref   = [];

    eval {
      $ref = $self->util->dbh->selectall_arrayref($query, {},
                $self->id_run(), $self->end(),$self->type());
      1;
    } or do {
      carp $EVAL_ERROR;
      return;
    };

    if(@{$ref}) {
      $self->id_cache_query($ref->[0]->[0]);
    }
  }
  return 1;
}
#cache lane summary given id_run and end if know cycle count
sub cache_lane_summary{
  my ($self, $cycle_count) = @_;

  my $query = q{SELECT temp.position AS lane,}
              .q{ temp.end AS end,}
              .q{ ROUND(SUM(temp.clusters_raw*temp.perc_pf_clusters*?/?)) AS lane_yield,}
              .q{ ROUND(AVG(temp.clusters_raw*temp.perc_pf_clusters/?)) AS clusters_pf,}
              .q{ ROUND(STD(temp.clusters_raw*temp.perc_pf_clusters/?)) AS clusters_pf_sd,}
              .q{ ROUND(AVG(temp.clusters_raw)) AS clusters_raw,}
              .q{ ROUND(STD(temp.clusters_raw)) AS clusters_raw_sd,}
              .q{ ROUND(AVG(temp.av_1st_cycle_int_pf)) AS first_cycle_int,}
              .q{ ROUND(STD(temp.av_1st_cycle_int_pf)) AS first_cycle_int_sd,}
              .q{ ROUND(AVG(temp.av_perc_intensity_after_20_cycles_pf),2) AS perc_int_20_cycles,}
              .q{ ROUND(STD(temp.av_perc_intensity_after_20_cycles_pf),2) AS perc_int_20_cycles_sd,}
              .q{ ROUND(AVG(temp.perc_pf_clusters),2) AS perc_pf_clusters,}
              .q{ ROUND(STD(temp.perc_pf_clusters),2) AS perc_pf_clusters_sd,}
              .q{ ROUND(AVG(temp.perc_align_pf),2) AS perc_pf_align,}
              .q{ ROUND(STD(temp.perc_align_pf),2) AS perc_pf_align_sd,}
              .q{ ROUND(AVG(temp.av_alignment_score_pf),2) AS align_score,}
              .q{ ROUND(STD(temp.av_alignment_score_pf),2) AS align_score_sd,}
              .q{ ROUND(AVG(temp.perc_error_rate_pf),2) AS perc_error_rate,}
              .q{ ROUND(STD(temp.perc_error_rate_pf),2) AS perc_error_rate_sd}
              .q{ FROM (SELECT DISTINCT clusters_raw, av_1st_cycle_int_pf, av_perc_intensity_after_20_cycles_pf,}
              .q{ perc_pf_clusters, perc_align_pf, av_alignment_score_pf,}
              .q{ perc_error_rate_pf, position, tile, lqc.end AS end}
              .q{ FROM  lane_qc lqc, run_tile rt}
              .q{ WHERE rt.id_run = ?}
              .q{ AND   rt.id_run_tile = lqc.id_run_tile}
              .q{ AND   lqc.end = ?}
              .q{ ORDER BY position) temp}
              .q{ GROUP BY temp.position}
              .q{ ORDER BY temp.position};
  #print $query, "\n";
  my @args = ($cycle_count, ($PERCENTAGE*$KILOBASE), $PERCENTAGE, $PERCENTAGE, $self->id_run(),$self->end());
  my $to_hash = $query.q{?id_run=}.$self->id_run().q{&end=}.$self->end();
  #print $to_hash, "\n";
  my $ssha = $self->generate_ssha($to_hash);
  #print $ssha, "\n";
  $self->ssha_sql($ssha);

  $self->run_cache_hash($query, @args);

  return;
}
#cache cycle count given id_run
sub cache_cycle_count{
  my ($self) = @_;
  my $query = q{SELECT MAX(cycle) FROM errors_by_cycle ec, run_tile rt}
             .q{ WHERE rt.id_run = ? AND rt.end = ? AND rt.id_run_tile = ec.id_run_tile};

  my @args = ($self->id_run(), $self->end());
  my $to_hash = $query.q{?id_run=}.$self->id_run().q{?end=}.$self->end();
   #print $to_hash, "\n";
   my $ssha = $self->generate_ssha($to_hash);
   #print $ssha, "\n";
   $self->ssha_sql($ssha);

   $self->run_cache($query, @args);

   return 1;
}
#check cycle count cached or not if given id_run, if not cache it and return the cycle count
sub check_cycle_count{
  my ($self) = @_;

  my $cycle = $self->get_single_read_length($self->id_run, $self->end());

  my $cycle_cache;

  my $rows_ref = $self->get_cache_by_id_type_end();
  if($rows_ref){
    $cycle_cache = $rows_ref->[0][0];
  }else{
    $self->cache_cycle_count();
    if($self->{cache_query}){
      $cycle_cache = $self->{cache_query}->[0][0];
    }
  }
  if($cycle){
    return $cycle;
  }

  return $cycle_cache;

}
# cache number of movez  tiles out of range given id_run
sub cache_movez_tiles{
  my ($self) = @_;

  my $end = $self->end();

  my $start_cycle = 2;
  my $end_cycle;

  if($end){
    my $cycle_range = $self->get_read_cycle_range_from_recipe($self->id_run(), $end);
    $end_cycle = $cycle_range->[1];
    if($end == 2){
      $start_cycle = $cycle_range->[0] + 1;
    }
  }else{
    my $cycle_range = $self->get_read_cycle_range_from_recipe($self->id_run());
    $end_cycle = $cycle_range->[1];
  }

  my $query = q{SELECT COUNT(*)}
                 .q{ FROM}
                 .q{ (SELECT r.id_run, r.position, r.tile,  abs( max(m.newz)-min(m.newz)) as diff}
                 .q{ FROM run_tile r, move_z m}
                 .q{ WHERE m.cycle >= ? }
                 .q{ AND m.cycle <= ? }
                 .q{ AND r.id_run_tile = m.id_run_tile}
                 .q{ AND r.id_run = ?}
                 .q{ GROUP BY r.position, r.tile}
                 .q{ HAVING  diff >=5000)}
                 .q{ AS vari};
   my @args = ($start_cycle, $end_cycle, $self->id_run());

   my $to_hash = $query.q{?id_run=}.$self->id_run().q{&start=}.$start_cycle.q{&end=}.$end_cycle;
   #print $to_hash, "\n";
   my $ssha = $self->generate_ssha($to_hash);
   #print $ssha, "\n";
   $self->ssha_sql($ssha);

   $self->run_cache($query, @args);

   return;
}
# cache sql query with some args
sub run_cache{
  my ($self, $query, @args) = @_;
  my $util   = $self->util();

  eval {
      my $dbh = $self->util->dbh();

      my $sth = $dbh->prepare($query);

      $sth->execute(@args);

      my $rows_ref = $sth->fetchall_arrayref();
      if($rows_ref){
        $self->{cache_query} = $rows_ref;
        my $dump = Data::Dumper->new([$rows_ref],['rows_ref']);
        $dump->Indent(0);
        $self->results($dump->Dump);
        #print $dump->Dump, "\n";
        $self->is_current(1);

        $self->save();
       # carp q{data cached for }.$self->id_run(). q{ } . $self->end(). q{ }.$self->type();
      }else{
        carp q{there is no data to cache }.$self->id_run(). q{ } . $self->end(). q{ }.$self->type();
      }
      1;
    } or do {
      croak $EVAL_ERROR;
    };
    return;
}
#given id_run, query type and end, get the current cached rows_ref
sub run_cache_hash{
  my ($self, $query, @args) = @_;
  my $util   = $self->util();

  eval {
      my $dbh = $self->util->dbh();

      my $sth = $dbh->prepare($query);

      $sth->execute(@args);

      my $rows_ref;
      while (my $row = $sth->fetchrow_hashref()) {
        push @{$rows_ref}, $row;
      }
      if($rows_ref){
        $self->{cache_query} = $rows_ref;
        my $dump = Data::Dumper->new([$rows_ref],['rows_ref']);
        $dump->Indent(0);
        $self->results($dump->Dump);
        #print $dump->Dump, "\n";
        $self->is_current(1);

        $self->save();
        #carp q{cached data  for }.$self->id_run(). q{ } . $self->end(). q{ }.$self->type();
      }else{
        carp q{there is no data to cache }.$self->id_run(). q{ } . $self->end(). q{ }.$self->type();
      }
      1;
    } or do {
      croak $EVAL_ERROR;
    };
    return;

}

sub get_cache_by_id_type_end{
  my($self) = @_;
  my $util   = $self->util();

  my $rows_ref;
  eval {
      my $dbh = $self->util->dbh();
      my $query = q{SELECT results
                    FROM cache_query
                    WHERE id_run = ?
                    AND type = ?
                    AND end = ?
                    AND is_current = 1};

      my $sth = $dbh->prepare($query);

      $sth->execute($self->id_run(), $self->type(), $self->end());
      #print $query, "\n";
      my @row  = $sth->fetchrow_array();

      #print $row[0], "\n";
      if(@row){
        my $semi_colon_count = $row[0] =~ tr/;/;/;
        if ($semi_colon_count == 1 && ($row[0] =~ /\$rows_ref\ =\ \[\[.*?\]\];/xms || $row[0] =~ /\$rows_ref\ =\ \[\{.*?\}\];/xms)) {
          eval $row[0];## no critic (ProhibitStringyEval,RequireCheckingReturnValueOfEval)
        } else {
          croak 'Too many statements in returned code: ' . $row[0];
        }
      }
      1;
    } or do {
      croak $EVAL_ERROR;
    };

    return $rows_ref;
}

#given a string, get ssha key
sub generate_ssha {
  my ($self, $to_hash) = @_;

  my $sha1 = Digest::SHA1->new;
  $sha1->add($to_hash);

  my $digest = $sha1->digest;
  #my $digest = $ctx->b64digest;

  my $hashed = encode_base64($digest,q{});

  return $hashed;
}


#get id_run and ends which need to be cached for lane summary
sub get_runs_cache_lane_summary{
  my ($self) = @_;

  my $util   = $self->util();

  my $id_run_ends;
  eval {
      my $dbh = $self->util->dbh();

      my $query = q{
SELECT id_run, end
FROM (
SELECT DISTINCT id_run, rt.end AS end
FROM run_tile rt, lane_qc lqc
WHERE rt.id_run_tile = lqc.id_run_tile
) temp
WHERE NOT EXISTS
(SELECT 1 FROM cache_query
WHERE type = 'lane_summary'
AND is_current = 1
AND cache_query.id_run = temp.id_run
AND cache_query.end = temp.end);
                   };
      #print "$query\n";
      my $sth = $dbh->prepare($query);

      $sth->execute();

      while(my @row = $sth->fetchrow_array()){
        push @{$id_run_ends},  \@row;
        #print @row,"\n";
      }

      1;
    } or do {
      croak $EVAL_ERROR;
    };
    #print Dumper $id_run_ends;
    return $id_run_ends;

}
# cache all lane summary not being done before
sub cache_lane_summary_all{
  my ($self) = @_;

  my $util   = $self->util();

  my $id_run_ends = $self->get_runs_cache_lane_summary();
  my $count_run_cached = 0;
  if($id_run_ends){
    $util->transactions(0);
    eval{
      foreach my $id_run_end (@{$id_run_ends}){
        #warn "@{$id_run_end}: cache lane summary and cycle_count";
        my $cache_query_summary = npg_qc::model::cache_query->new({
                           util   => $util,
                           id_run => $id_run_end->[0],
                           end    => $id_run_end->[1],
                           type   => 'lane_summary',
                     });

        if(!$cache_query_summary->complete_qc_data_one_run()){
           carp q{data is incomplete in the database for run }.$id_run_end->[0].q{ end }.$id_run_end->[1];
           next;
        }

        my $cache_query_cycle = npg_qc::model::cache_query->new({
                           util   => $util,
                           id_run => $id_run_end->[0],
                           end    => $id_run_end->[1],
                           type   => 'cycle_count',
                     });
        my $cycle_count =  $cache_query_cycle ->check_cycle_count();
        eval{
          $cache_query_summary ->cache_lane_summary($cycle_count);
          $util->dbh->commit();
          $count_run_cached ++;
          1;
        } or do {
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
    return $count_run_cached;
  }
  carp "There is no runs to cache lane summary\n";
  return 0;

}
#get all id_runs need to be cached for movez_tiles
sub get_runs_cache_movez_tiles{
  my ($self) = @_;

  my $util   = $self->util();

  my $id_runs;
  eval {
      my $dbh = $self->util->dbh();

      my $query = q{SELECT DISTINCT id_run
                    FROM run_tile
                    WHERE end =1
                    AND row IS NOT NULL
                    AND NOT EXISTS
                      (SELECT * FROM cache_query
                       WHERE type = 'movez_tiles'
                       AND is_current = 1
                       AND run_tile.id_run = cache_query.id_run
                       AND run_tile.end = cache_query.end
                      )
                   };
      #print "$query\n";
      my $sth = $dbh->prepare($query);

      $sth->execute();

      my @row;

      while(@row = $sth->fetchrow_array()){
        push @{$id_runs},  $row[0];
      }
      #print @{$id_runs};
      1;
    } or do {
      croak $EVAL_ERROR;
    };
    return $id_runs;

}
# cache all movez tiles not being done before
sub cache_movez_tiles_all{
  my ($self) = @_;

  my $util   = $self->util();

  my $id_runs = $self->get_runs_cache_movez_tiles();
  if($id_runs){

    $util->transactions(0);
    eval{
      foreach my $id_run (@{$id_runs}){
        my $cache_query1 = npg_qc::model::cache_query->new({
                           util   => $util,
                           id_run => $id_run,
                           end    => 1,
                           type   => 'movez_tiles',
                     });
        eval{
          $cache_query1->set_to_not_current();
          $cache_query1->cache_movez_tiles();
          1;
        } or do {
          carp $EVAL_ERROR;
        };
        if($self->paired_read($id_run)){
             my $cache_query2 = npg_qc::model::cache_query->new({
                           util   => $util,
                           id_run => $id_run,
                           end    => 2,
                           type   => 'movez_tiles',
                     });
            eval{
               $cache_query2->set_to_not_current();
               $cache_query2->cache_movez_tiles();
               1;
            } or do {
              carp $EVAL_ERROR;
            };
        }
        $util->dbh->commit();
      }
      $util->dbh->commit();
      $util->transactions(1);
      1;
    } or do {
      $util->transactions(1);
      $util->dbh->rollback();
      croak $EVAL_ERROR;
    };
    return scalar @{$id_runs};
  }else{
    carp "There is no runs to cache movez tiles\n";
    return 0;
  }
  return;
}

sub is_current_cached{
  my ($self) = @_;
  my $util   = $self->util();
  my $query = q{SELECT results
                FROM cache_query
                WHERE id_run = ? AND end = ? AND type = ? and is_current =1};
  my $cached = 0;
  eval {
      my $dbh = $self->util->dbh();

      my $sth = $dbh->prepare($query);

      $sth->execute($self->id_run(), $self->end(), $self->type());

      my $row_ref = $sth->fetchrow_arrayref();
      if($row_ref){
        $cached = 1;
      }
      1;
  } or do {
      croak $EVAL_ERROR;
  };
  return $cached;
}

sub set_to_not_current{
  my ($self) = @_;
  my $util   = $self->util();
  my $query = q{UPDATE cache_query
                SET is_current = 0
                WHERE id_run = ? AND end = ? AND type = ? and is_current =1};

  my $num_rows;
  my $dbh = $self->util->dbh();
  eval {
      my $sth = $dbh->prepare($query);

      $num_rows = $sth->execute($self->id_run(), $self->end(), $self->type());
      $util->transactions() and $dbh->commit();

      1;
  } or do {
      $dbh->rollback();
      croak $EVAL_ERROR;
  };
  return $num_rows ;
}

sub update_current_cache{
  my ($self) = @_;
  my $util   = $self->util();
  my $id_run = $self->id_run();
  my $end = $self->end();
  eval{
    if($self->type() eq 'movez_tiles'){
      $self->cache_movez_tiles();
    }elsif ($self->type() eq 'lane_summary'){
      if($self->complete_qc_data_one_run()){
        my $cache_query_cycle = npg_qc::model::cache_query->new({
                           util   => $util,
                           id_run => $self->id_run(),
                           end    => $self->end(),
                           type   => 'cycle_count',
                     });

        my $cycle_count =  $cache_query_cycle ->check_cycle_count();

        $self->cache_lane_summary($cycle_count);
      }
      else{
        carp "the qc data for run $id_run end $end is not complete";
      }
    }
    1;
  } or do {
    croak $EVAL_ERROR;
  };
  return 1;
}

sub cache_new_copy_data{
  my ($self) = @_;
  my $util   = $self->util();
  eval{
    $self->set_to_not_current();

    if($self->type() eq 'lane_summary'){
      my $cycle_cache_query = npg_qc::model::cache_query->new({
                           util   => $util,
                           id_run => $self->id_run(),
                           end    => $self->end(),
                           type   => 'cycle_count',
                     });
      $cycle_cache_query->set_to_not_current();
    }
    my $new_cache_query = npg_qc::model::cache_query->new({
                           util   => $util,
                           id_run => $self->id_run(),
                           end    => $self->end(),
                           type   => $self->type(),
                     });

    $new_cache_query->update_current_cache();
    1;
  } or do {
    croak $EVAL_ERROR;
  };
  return 1;
}

sub complete_qc_data_one_run{
  my ($self) = @_;
  my $id_run = $self->id_run();
  my $end = $self->end();

  my $data_complete = $self->complete_signal_mean_data($id_run) && $self->complete_lane_qc_data($id_run, $end);

  if( ! $self->run_having_control_lane($id_run) ){
    return $data_complete;
  }

  return $data_complete && $self->complete_errors_by_cycle_data($id_run, $end);
}

sub complete_lane_qc_data{
  my ($self, $id_run, $end) = @_;

  my $util   = $self->util();
  my $num_lanes_complete = 0;
  eval {
        my $dbh = $self->util->dbh();

        my $query = q{
SELECT COUNT(lane_tile_table.position) AS count_lane
FROM(                    
SELECT rt.position, COUNT(lqc.id_run_tile) AS tile_count_lane
FROM run_tile rt, lane_qc lqc
WHERE rt.id_run_tile = lqc.id_run_tile
AND rt.id_run = ?
AND rt.end = ?
GROUP BY rt.position
HAVING tile_count_lane = (SELECT tile FROM run_recipe WHERE id_run  = ?)
) lane_tile_table
HAVING count_lane = (SELECT lane FROM run_recipe WHERE id_run  = ?)
                    };

        my $sth = $dbh->prepare($query);

        $sth->execute($id_run, $end, $id_run, $id_run);
        my $row = $sth->fetchrow_arrayref();
        if($row){
           $num_lanes_complete = $row->[0];
        }
        1;
    } or do {
        croak $EVAL_ERROR;
    };
    if(!$num_lanes_complete){
      carp qq{$num_lanes_complete lanes qc data complete};
    }
    return $num_lanes_complete;
}

sub complete_signal_mean_data{
  my ($self, $id_run) = @_;

  my $id_run_pair = $self->id_run_pair($id_run);

  if(!$id_run_pair){
    $id_run_pair = $id_run;
  }

  my $util   = $self->util();
  my $num_lanes_complete = 0;
  eval {
        my $dbh = $self->util->dbh();

        my $query = q{
SELECT COUNT(lane_cycle_table.position) AS lane_count
FROM (
SELECT position, COUNT(cycle) AS cycle_count
FROM signal_mean
WHERE id_run = ?
GROUP BY position
HAVING cycle_count = (SELECT sum(cycle) FROM run_recipe WHERE id_run = ? OR id_run = ?)
) lane_cycle_table
HAVING lane_count = (SELECT lane FROM run_recipe WHERE id_run  = ?)
                    };

        my $sth = $dbh->prepare($query);

        $sth->execute($id_run, $id_run, $id_run_pair, $id_run);
        my $row = $sth->fetchrow_arrayref();
        if($row){
           $num_lanes_complete = $row->[0];
        }
        1;
    } or do {
        croak $EVAL_ERROR;
    };
    if(!$num_lanes_complete){
      carp qq{$num_lanes_complete lanes signal_mean complete};
    }
    return $num_lanes_complete;
}

sub complete_errors_by_cycle_data{
  my ($self, $id_run, $end) = @_;

  if ($end eq 't') { return; }

  my $actual_id_run = $id_run;

  if ($end == 2){
    $actual_id_run =  $self->id_run_pair($id_run);
  }
  if(!$actual_id_run){
    $actual_id_run = $id_run;
  }
  my $util   = $self->util();
  my $num_lanes_complete = 0;
  eval {
        my $dbh = $self->util->dbh();

        my $query = q{
SELECT position, count(rescore) as score_count
FROM(
SELECT position, rescore, count(*) AS tile_count
FROM(
SELECT position, tile, rescore, COUNT(*) AS cycle_count
FROM errors_by_cycle ec, run_tile rt
WHERE rt.id_run_tile = ec.id_run_tile
AND rt.id_run = ?
AND rt.end = ?
AND ec.cycle <= (SELECT cycle_read1 FROM run_recipe WHERE id_run  = ?)
GROUP BY position, tile, rescore
HAVING cycle_count = (SELECT cycle_read1 FROM run_recipe WHERE id_run  = ?)
) cycle_count_table
GROUP BY position, rescore
HAVING tile_count = (SELECT tile FROM run_recipe WHERE id_run  = ?)
) temp
GROUP BY position
HAVING score_count = 2
                    };

        my $sth = $dbh->prepare($query);

        $sth->execute($id_run, $end, $actual_id_run, $actual_id_run, $id_run);
        my $rows = $sth->fetchall_arrayref();
        $num_lanes_complete = scalar @{$rows};
        1;
    } or do {
        croak $EVAL_ERROR;
    };
    if(!$num_lanes_complete){
      carp qq{$num_lanes_complete lanes errors_by_cycle complete};
    }
    return $num_lanes_complete;
}
1;
__END__
=head1 NAME

npg_qc::model::cache_query

=head1 VERSION

$Revision$

=head1 SYNOPSIS

  my $oCache_query = npg_qc::model::cache_query->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - a list of fields

=head2 cache_lane_summary  cache lane summary given id_run and end if know cycle count

=head2 cache_cycle_count - cache cycle count given id_run

=head2 check_cycle_count - check cycle count cached or not if given id_run, if not cache it and return the cycle count

=head2 cache_movez_tiles - cache number of movez  tiles out of range given id_run

=head2 run_cache - cache sql query with some args

=head2 get_cache_by_id_type_end - given id_run, query type and end, get the current cached rows_ref

=head2 generate_ssha - given a string, get ssha key

=head2 get_runs_cache_lane_summary - get id_run and ends which need to be cached for lane summary

=head2 cache_lane_summary_all - cache all lane summary not being done before

=head2 get_runs_cache_movez_tiles - get all id_runs need to be cached for movez_tiles

=head2 cache_movez_tiles_all - cache all movez tiles not being done before

=head2 run_cache_hash - store sql query results as hash ref 

=head2 is_current_cached - check current model is cached in database or not

=head2 set_to_not_current - set this caching to not current

=head2 update_current_cache - get the new query and update the current cache 

=head2 cache_new_copy_data - save a new copy of data in the cache table and set the old one not current

=head2 init - find out primary key based on id_run, end and type, is_current

=head2 complete_signal_mean_data - given id_run and paired run number of this run, check the lane number with complete cycle data in signal mean table against run recipe table

=head2 complete_lane_qc_data - given id_run and end, check the lane number with complete tiles in lane_qc table against run recipe table

=head2 complete_errors_by_cycle_data - given id_run and end, check any lanes in errors_by_cycle table with score and re-score value for the complete set of tiles of each cycle against run recipe table

=head2 complete_qc_data_one_run - check four tables of qc data, return false if incomplete

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

strict
warnings
npg_qc::model
Carp
Readonly
Digest::SHA1
MIME::Base64

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

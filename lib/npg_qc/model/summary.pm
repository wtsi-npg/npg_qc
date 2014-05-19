#########
# Author:        ajb
# Created:       2008-06-27
#

package npg_qc::model::summary;
use strict;
use warnings;
use base qw(npg_qc::model);
use Carp;
use English qw(-no_match_vars);
use npg_qc::model::chip_summary;
use npg_qc::model::lane_qc;
use npg_qc::model::run_tile;
use npg::util::image::image_map;
use npg::util::image::heatmap;
use npg::api::run;
use Statistics::Lite qw(:all);
use Readonly;

our $VERSION = '0';

Readonly our $CYCLE_COUNT_GA1 => 36;
Readonly our $CYCLE_COUNT_GA2 => 50;
Readonly our $PERCENTAGE      => 100;
Readonly our $KILOBASE        => 1000;
Readonly our $NUM_LANES_PER_RUN =>8;

__PACKAGE__->mk_accessors(fields());

sub fields {
  return qw(id_run);
}

sub chip_summary {
  my ($self) = @_;
  if (!$self->{chip_summary}) {
    $self->{chip_summary} = npg_qc::model::chip_summary->new({
      util   => $self->util(),
      id_run => $self->{id_run},
    });
  }
  return $self->{chip_summary};
}

sub lane_qcs {
  my ($self) = @_;
  if (!$self->{lane_qcs}) {
    my $lane_qc_model = npg_qc::model::lane_qc->new({ util => $self->util() });
    $self->{lane_qcs} = $lane_qc_model->lane_qcs_per_run($self->{id_run});
  }
  return $self->{lane_qcs};
}

sub lane_qcs_per_lane_and_end {
  my ($self) = @_;
  if (!$self->{lane_qcs_per_lane_and_end}) {
    my $lane_end_hash = {};
    foreach my $tile (@{$self->lane_qcs()}) {
      my $end = $tile->end();
      my $lane = $tile->run_tile->position();
      $tile->{position} = $lane;
      push @{$lane_end_hash->{$lane}->{$end}}, $tile;
    }
    my $lane_end_array = [];
    foreach my $position (sort keys %{$lane_end_hash}) {
      my $temp = [];
      push @{$temp}, $position;
      foreach my $end (sort keys %{$lane_end_hash->{$position}}) {
        push @{$temp}, $lane_end_hash->{$position}->{$end};
      }
      push @{$lane_end_array}, $temp;
    }
    $self->{lane_qcs_per_lane_and_end} = $lane_end_array;
  }
  return $self->{lane_qcs_per_lane_and_end};
}

sub lane_results_summary {
  my ($self) = @_;

  if (!$self->{lane_results_summary}) {

    my $cache_query = $self->cache_query_retrieval({ id_run => $self->id_run(), type => 'lane_summary' });

    my $results = $cache_query->get_cache_by_id_type_end();

    my $results_hash = {};

    if ($results) {

      $results_hash->{lane_results_summary}->{read_one} = $results;

      if ($self->id_run_pair($self->id_run()) || $self->paired_read($self->id_run())) {
        $cache_query = $self->cache_query_retrieval({ id_run => $self->id_run(), type => 'lane_summary', end => 2 });
        $results_hash->{lane_results_summary}->{read_two} = $cache_query->get_cache_by_id_type_end();
      }

    } else {

      $results_hash = $self->manual_retrieval_of_lane_summaries();

    }

    my $read_count = $self->reads_per_lane(1);
    foreach my $row (@{$results_hash->{lane_results_summary}->{read_one}}) {
      my $lane = $row->{lane};
      $row->{pf_reads} = $read_count->{$lane}->{pf_reads};
      $row->{raw_reads} = $read_count->{$lane}->{raw_reads};
    }

    if ($results_hash->{lane_results_summary}->{read_two}) {
      foreach my $row (@{$results_hash->{lane_results_summary}->{read_two}}) {
        my $lane = $row->{lane};
        $row->{pf_reads} = $read_count->{$lane}->{pf_reads};
        $row->{raw_reads} = $read_count->{$lane}->{raw_reads};
      }
    }

    $self->{lane_results_summary} = $results_hash;
  }
  return $self->{lane_results_summary};
}

sub manual_retrieval_of_lane_summaries {
  my ($self) = @_;

  my $results_hash;

  my $query = q{SELECT temp.position AS lane,temp.end AS end,
                  ROUND(SUM(temp.clusters_raw*temp.perc_pf_clusters*?/?)) AS lane_yield,
                  ROUND(AVG(temp.clusters_raw*temp.perc_pf_clusters/?)) AS clusters_pf,
                  ROUND(STD(temp.clusters_raw*temp.perc_pf_clusters/?)) AS clusters_pf_sd,
                  ROUND(AVG(temp.clusters_raw)) AS clusters_raw,
                  ROUND(STD(temp.clusters_raw)) AS clusters_raw_sd,
                  ROUND(AVG(temp.av_1st_cycle_int_pf)) AS first_cycle_int,
                  ROUND(STD(temp.av_1st_cycle_int_pf)) AS first_cycle_int_sd,
                  ROUND(AVG(temp.av_perc_intensity_after_20_cycles_pf),2) AS perc_int_20_cycles,
                  ROUND(STD(temp.av_perc_intensity_after_20_cycles_pf),2) AS perc_int_20_cycles_sd,
                  ROUND(AVG(temp.perc_pf_clusters),2) AS perc_pf_clusters,
                  ROUND(STD(temp.perc_pf_clusters),2) AS perc_pf_clusters_sd,
                  ROUND(AVG(temp.perc_align_pf),2) AS perc_pf_align,
                  ROUND(STD(temp.perc_align_pf),2) AS perc_pf_align_sd,
                  ROUND(AVG(temp.av_alignment_score_pf),2) AS align_score,
                  ROUND(STD(temp.av_alignment_score_pf),2) AS align_score_sd,
                  ROUND(AVG(temp.perc_error_rate_pf),2) AS perc_error_rate,
                  ROUND(STD(temp.perc_error_rate_pf),2) AS perc_error_rate_sd
                FROM  (SELECT clusters_raw, av_1st_cycle_int_pf, av_perc_intensity_after_20_cycles_pf,
                         perc_pf_clusters, perc_align_pf, av_alignment_score_pf, perc_error_rate_pf, position, tile, lqc.end AS end
                       FROM  lane_qc lqc, run_tile rt
                       WHERE rt.id_run = ?
                       AND   rt.id_run_tile = lqc.id_run_tile
                       AND   lqc.end = ?
                       ORDER BY position) temp
                GROUP BY temp.position
                ORDER BY temp.position};

  my $dbh = $self->util->dbh();
  my $sth = $dbh->prepare($query);

  my $cycle_count1 = $self->get_single_read_length($self->{id_run}, 1);
  $sth->execute($cycle_count1, ($PERCENTAGE*$KILOBASE), $PERCENTAGE, $PERCENTAGE, $self->{id_run},1);
  while (my $href = $sth->fetchrow_hashref()) {
    $href->{read} = $href->{end};
    push @{$results_hash->{lane_results_summary}->{read_one}}, $href;
  }

  my $cycle_count2 = $self->get_single_read_length($self->{id_run}, 2);
  $sth->execute($cycle_count2, ($PERCENTAGE*$KILOBASE), $PERCENTAGE, $PERCENTAGE, $self->{id_run},2);
  while (my $href = $sth->fetchrow_hashref()) {
    $href->{read} = $href->{end};
    push @{$results_hash->{lane_results_summary}->{read_two}}, $href;
  }

  return $results_hash;
}

sub lane_qc_object {
  my ($self) = @_;
  if (!$self->{lane_qc_obj}) {
    $self->{lane_qc_obj} = npg_qc::model::lane_qc->new({ util => $self->util() });
  }
  return $self->{lane_qc_obj};
}

sub reads_per_lane {
  my ($self, $end) = @_;

  my $query = q{SELECT ROUND(SUM(lqc.clusters_raw*lqc.perc_pf_clusters/?)) AS pf_reads,
                       ROUND(SUM(lqc.clusters_raw)) AS raw_reads,
                       rt.position as lane
                       FROM run_tile rt, lane_qc lqc
                WHERE  rt.id_run = ?
                AND    rt.end = ?
                AND    rt.id_run_tile = lqc.id_run_tile
                GROUP BY rt.position};

  my $dbh = $self->util->dbh();
  my $sth = $dbh->prepare($query);
  $sth->execute($PERCENTAGE, $self->id_run(), $end);

  my $return_hash;
  while (my $href = $sth->fetchrow_hashref()) {
    $return_hash->{$href->{lane}} = $href;
  }

  return $return_hash;
}

sub heatmap_data {
  my ($self, $arg_refs) = @_;

  my $dataset = $arg_refs->{dataset};

  my $allowed_lane_qc_data = {
    raw_clusters                      => 1,
    pf_clusters                       => 1,
    first_cycle_intensities           => 1,
    perc_twentieth_cycles_intensities => 1,
    pf_perc_clusters                  => 1,
    pf_perc_align                     => 1,
    pf_alignment_scores               => 1,
    pf_perc_error_rates               => 1,
  };

  if (!$allowed_lane_qc_data->{$dataset}) {
    croak 'This data is unavailable';
  }

  return $self->lane_qc_object->$dataset($arg_refs);
}

sub alerts {
  my ($self) = @_;

  if (!$self->{alerts}) {

    my $cluster_alerts   = $self->lane_qc_object->cluster_alerts($self->{id_run});
    if ($cluster_alerts) {
      $self->{alerts}->{cluster_alerts} = $cluster_alerts;
    }

    my $error_alerts     = $self->lane_qc_object->error_alerts($self->{id_run});
    if ($error_alerts) {
      $self->{alerts}->{error_alerts} = $error_alerts;
    }

    my $intensity_alerts = $self->lane_qc_object->intensity_alerts($self->{id_run});
    if ($intensity_alerts) {
      $self->{alerts}->{intensity_alerts} = $intensity_alerts;
    }

  }

  return $self->{alerts};
}

sub heatmap_with_map {
  my ($self, $id_run, $end, $dataset, $url) = @_;

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

  my $rt_obj = npg_qc::model::run_tile->new({util => $self->util()});
  my $run_tiles = $rt_obj->run_tiles_per_run_by_lane_end($id_run);

  eval {
    $heatmap_obj->plot_illumina_map($data_refs);
    $data_refs->{data} = $heatmap_obj->image_map_reference();
    foreach my $box (@{$data_refs->{data}}) {
      my $data_information = $box->[-1];
      my $params = q{id_run=} . $id_run . q{&position=} . $data_information->{position} . q{&tile=} . $data_information->{tile} . q{&end=} . $end . q{&cycle=1};

      my $run_tile = $run_tiles->[$end-1]->[$data_information->{position}-1]->[$data_information->{tile} -1];
      my $id_run_tile = $run_tile->id_run_tile();

      $box->[-1]->{url} = q{javascript:run_tile_page(SCRIPT_NAME+'/run_tile/' +} . $run_tile->id_run_tile() .q{);" onclick="open_tile_viewer(SCRIPT_NAME + '/run_tile/}. $id_run_tile.q{;read_tile_viewer');};
    }
    my $image_map_object = npg::util::image::image_map->new();
    $self->{map} = $image_map_object->render_map($data_refs);
  } or do {
    croak 'Unable to render map: ' . $EVAL_ERROR;
  };

  return $self->{map};
}

sub complete_runs {
  my ($self) = @_;

  if (!$self->{complete_runs}) {

       my $query = q{
SELECT cq.id_run, end, cs.paired AS paired
FROM cache_query cq, chip_summary cs
WHERE type = 'lane_summary'
AND is_current = 1
AND cq.id_run = cs.id_run
                   };

    my $dbh  = $self->util->dbh();
    my $sth  = $dbh->prepare($query);
    $sth->execute();

    while (my $hash = $sth->fetchrow_hashref()) {
      push @{$self->{complete_runs}}, $hash;
    }
  }
  return $self->{complete_runs};
}

sub get_paired_runs_complete_data{
  my ($self) = @_;

  my $util   = $self->util();

  my $paired_runs;

  eval {
    my $id_runs = $self->get_runs_complete_data();

    if($id_runs){

      foreach my $id_run (sort keys %{$id_runs}){

        my $id_run_paired = $self->id_run_pair($id_run);

        if($id_run_paired){

          if( $id_run < $id_run_paired){

            $paired_runs->{$id_run} = $id_run_paired;
          }elsif(!$self->{id_runs_complete_data}->{$id_run}){

            $paired_runs->{$id_run} = $id_run_paired;
          }

        }else{
          $paired_runs->{$id_run} = undef;
        }
      }

    }
    1;
  } or do {
    croak $EVAL_ERROR;
  };

  return $paired_runs;
}

sub get_runs_complete_data{
  my ($self) = @_;

  my $util   = $self->util();
  if(!$self->{id_runs_complete_data}){
    my $id_runs;
    eval {
        my $dbh = $self->util->dbh();

        my $query = q{
SELECT id_run, end
FROM cache_query
WHERE type = 'lane_summary'
AND is_current = 1
                    };

        my $sth = $dbh->prepare($query);

        $sth->execute();

        while (my @row = $sth->fetchrow_array()){

          my $id_run = $row[0];
          my $end = $row[1];

          if ($end == 1){

            $id_runs->{$id_run} = 1;

          }elsif ($end == 2){

	    my $id_run_pair = $self->id_run_pair($id_run);

	    if ($id_run_pair) {
              $id_runs->{$id_run_pair} = 1;
	    } else {
	      carp "$id_run should have an id_run_pair, but none found";
	    }

          }

        }
        $self->{id_runs_complete_data} = $id_runs;
        1;
      } or do {
        croak $EVAL_ERROR;
      };
    }
    return $self->{id_runs_complete_data};
}

sub one_run_complete_data{
  my ($self, $id_run, $end) = @_;

  my $util   = $self->util();
  my $lanes_complete = 0;
  eval {
        my $dbh = $self->util->dbh();

        my $query = q{
SELECT results
FROM cache_query
WHERE id_run = ?
AND end = ?
AND is_current = 1
AND type= 'lane_summary'
                    };

        my $sth = $dbh->prepare($query);

        $sth->execute($id_run, $end);
        my $row = $sth->fetchrow_arrayref();
        if($row){
           $lanes_complete = 1;
        }
        1;
    } or do {
        croak $EVAL_ERROR;
    };

    return $lanes_complete;
}

sub one_pair_complete_data{
  my ($self, $id_run) = @_;
  $id_run ||= $self->id_run();

  my $both_run_complete = 0;
  if (!$self->{one_pair_complete_data}->{id_runs}->{$id_run}) {
    $self->{one_pair_complete_data} = undef;
    my $id_runs = {};
    my $paired_id_run = $self->id_run_pair($id_run);

    if($paired_id_run && $id_run > $paired_id_run){
      my $temp_id_run = $id_run;
      $id_run = $paired_id_run;
      $paired_id_run = $temp_id_run;
    }

    my $lanes_complete1 = $self->one_run_complete_data($id_run, 1);
    my $lanes_complete2;
    $id_runs->{$id_run} = $lanes_complete1;

    if($paired_id_run){
      $lanes_complete2 = $self->one_run_complete_data($id_run, 2);
      $id_runs->{$paired_id_run} = $lanes_complete2;
    }
    if((defined $lanes_complete1 && $lanes_complete1)
        && ( !$paired_id_run || (defined $lanes_complete2 && $lanes_complete2 ))){
        $both_run_complete = 1;
    }
    $self->{one_pair_complete_data}->{complete} = $both_run_complete;
    $self->{one_pair_complete_data}->{id_runs} = $id_runs;
  }
  return $self->{one_pair_complete_data};
}

sub both_run_complete {
  my $self = shift;
  return $self->one_pair_complete_data->{complete};
}

sub pf_clusters{
  my ($self, $id_run) = @_;

  my $pf_clusters = [];

  eval {
        my $dbh = $self->util->dbh();

        my $query = q{SELECT rt.tile, rt.position,
                      ROUND((lqc.clusters_raw*lqc.perc_pf_clusters)/100) AS pf_clusters
                      FROM   lane_qc lqc, run_tile rt
                      WHERE  rt.id_run = ?
                      AND    rt.id_run_tile = lqc.id_run_tile
                      AND    lqc.end = 1
                      ORDER BY rt.tile, rt.position
                     };

        my $sth = $dbh->prepare($query);

        $sth->execute($id_run);
        while (my @row = $sth->fetchrow_array()){

          $pf_clusters->[$row[0] - 1]->[0] = $row[0];
          $pf_clusters->[$row[0] - 1]->[$row[1]] = $row[2];
        }
        1;
  } or do {
        croak $EVAL_ERROR;
  };

  return $pf_clusters;
}

sub raw_clusters{
  my ($self, $id_run) = @_;

  my $raw_clusters = [];

  eval {
        my $dbh = $self->util->dbh();

        my $query = q{SELECT rt.tile, rt.position, lqc.clusters_raw
                      FROM   lane_qc lqc, run_tile rt
                      WHERE  rt.id_run = ?
                      AND    rt.id_run_tile = lqc.id_run_tile
                      AND    lqc.end = 1
                      ORDER BY rt.tile, rt.position
                     };

        my $sth = $dbh->prepare($query);

        $sth->execute($id_run);
        while (my @row = $sth->fetchrow_array()){

          $raw_clusters->[$row[0] - 1]->[0] = $row[0];
          $raw_clusters->[$row[0] - 1]->[$row[1]] = $row[2];
        }
        1;
  } or do {
        croak $EVAL_ERROR;
  };

  return $raw_clusters;
}


sub phasing_info{
  my ($self, $id_run) = @_;

  my $phasing_info;

  eval {
        my $dbh = $self->util->dbh();

        my $query = q{SELECT a.id_run, a.end, perc_phasing, perc_prephasing 
                      FROM analysis_lane al, analysis a 
                      WHERE a.id_run = ?
                      AND a.iscurrent = 1
                      AND al.position = 4
                      AND a.id_analysis = al.id_analysis
                     };
        my $sth = $dbh->prepare($query);

        $sth->execute($id_run);

        while (my @row = $sth->fetchrow_array()){

          push @{$phasing_info}, \@row;
        }

        1;
  } or do {
        croak $EVAL_ERROR;
  };
  if(!$phasing_info){
     $phasing_info = [];
  }
  return $phasing_info;
}

sub pair_phasing_info{
  my ($self) = @_;

  if(!$self->{pair_phasing}){

    my $id_run = $self->id_run();
    my $paired_id_run = $self->id_run_pair($id_run);

    my $pair_phasing = [];

    my $phasing_info1 = $self->phasing_info($id_run);
    if(scalar @{$phasing_info1}){

      $pair_phasing = [@{$pair_phasing}, @{$phasing_info1}];
    }

    if($paired_id_run){
      my $phasing_info2 = $self->phasing_info($paired_id_run);
      if(scalar @{$phasing_info2}){

        $pair_phasing = [@{$pair_phasing}, @{$phasing_info2}];
      }
    }
    $self->{pair_phasing} = $pair_phasing;
  }
  return $self->{pair_phasing};
}

sub npg_api_run {
  my $self = shift;

  if(! $self->{npg_api_run}) {
    my $npg_api_run = npg::api::run->new({
          id_run => $self->id_run(),
    });
    $self->{npg_api_run} = $npg_api_run;
  }

  return $self->{npg_api_run};
}

sub cluster_density{
  my ($self, $id_run) = @_;

  if(!$id_run){
    $id_run = $self->id_run();
  }

  my @cluster_density = ();

  eval {
        my $dbh = $self->util->dbh();

        my $query = q{SELECT position, is_pf, min, max, p50
                      FROM cluster_density
                      WHERE id_run = ?
                      ORDER BY position, is_pf
                     };

        my $sth = $dbh->prepare($query);
        $sth->execute($id_run);

        while (my @row = $sth->fetchrow_array()){

         push @cluster_density, \@row;
        }
        1;
  } or do {
        croak $EVAL_ERROR;
  };

  return \@cluster_density;
}

1;
__END__
=head1 NAME

npg_qc::model::summary

=head1 SYNOPSIS

  my $oSummary = npg_qc::model::summary->new({util => $util});

=head1 DESCRIPTION

Base model to sit under npg_qc::view::summary

=head1 SUBROUTINES/METHODS

=head2 one_pair_complete_data - given one id_run, check both runs of the pair with complete data(8 lanes with the correct number of tiles), and store the results in the model

=head2 one_run_complete_data - given one id_run and the end, check complete data or not(8 lanes with the correct number of tiles), and store the results in the model

=head2 fields

=head2 heatmap_with_map - returns some html code with a url for a heatmap, plus the hover map to correspond with it 

=head2 chip_summary

=head2 lane_qcs

=head2 lane_qcs_per_lane_and_end

=head2 lane_results_summary

=head2 lane_qc_object - accessor for getting a lane_qc object to use

=head2 alerts - returns a hashref (or undef) if tiles that may have problems are spotted

  my $hAlerts = $oSummary->alerts();

=head2 heatmap_data - returns arrayref of data for a heatmap to be generated with

  my $aHeatmapData = $oSummary->heatmap_data({$arg_refs});

=head2 complete_runs - returns arrayref containing id_run and end for which the summary data is complete

  my $aCompleteRuns = $oSummary->complete_runs();

=head2 manual_retrieval_of_lane_summaries - should for any reason the lane summaries not be cached, then this can be calculated manually

=head2 get_runs_complete_data - get a list of actual id_runs with complete summary data and cached in cache query table

=head2 get_paired_runs_complete_data - get a list of pairs of actual id_runs with complete summary data and cached in cache query table

=head2 pf_clusters

=head2 raw_clusters

=head2 both_run_complete

=head2 pair_phasing_info

=head2 phasing_info

=head2 cluster_density - return an arrayref of cluster density by lane from database 

=head2 npg_api_run - method to create a npg api run object and cached it once created

=head2 reads_per_lane - obtain the number of raw and pf reads for a run_lane

  my $hReadsPerLane = $oSummary->reads_per_lane($end);

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

strict
warnings
npg_qc::model
English
Carp
Statistics::Lite
npg_qc::model::chip_summary
npg_qc::model::lane_qc

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

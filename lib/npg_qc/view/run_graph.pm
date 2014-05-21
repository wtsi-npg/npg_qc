#########
# Author:        gq1
# Maintainer:    $Author: mg8 $
# Created:       2008-09-30
# Last Modified: $Date: 2013-09-26 17:18:42 +0100 (Thu, 26 Sep 2013) $
# Id:            $Id: run_graph.pm 17546 2013-09-26 16:18:42Z mg8 $
# Source:        $Source: /repos/cvs/webcore/SHARED_docs/cgi-bin/docrep,v $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/view/run_graph.pm $
#

package npg_qc::view::run_graph;
use strict;
use warnings;
use base qw(npg_qc::view);
use English qw{-no_match_vars};
use Carp qw(confess cluck carp croak);
use Readonly;
use npg_qc::model::run_graph;
use npg::util::image::graph;
use npg_qc::model::instrument_statistics;

our $VERSION = '0';

Readonly our $WIDTH                => 800;
Readonly our $HEIGHT               => 460;
Readonly our $NUM_RUNS_GRAPH       => 100;
Readonly our $MAX_X_LABEL          => 50;
Readonly our $MAX_ERROR_SCALE      => 5;
Readonly our $DEFAULT_CYCLE_LENGTH => 0;
Readonly our $DEFAULT_RUN_NUMS_INS =>25;

sub decor {
  my ($self, @args) = @_;

  my $aspect = $self->aspect() || q();

  if($aspect =~ /\Aread_.*?png\z/xms || $aspect eq 'create_xml') {
    return 0;
  }

  return $self->SUPER::decor(@args);
}

sub content_type {
  my ($self, @args) = @_;

  my $aspect = $self->aspect() || q();

  if($aspect =~ /\Aread_.*?png\z/xms ) {
    return 'image/png';
  }

  if($aspect eq 'create_xml' ) {

    return 'application/xml';
  }
  return $self->SUPER::content_type(@args);
}

sub render {
  my ($self, @args) = @_;

  my $aspect = $self->aspect() || q();

  if($aspect =~ /\Aread_.*?png\z/xms ) {
    return $self->$aspect();
  }
  if($aspect eq 'create_xml' ) {

     return $self->create();
  }
  return $self->SUPER::render(@args);
}

sub create {
  my ($self)  = @_;

  my $util    = $self->util();
  my $cgi     = $util->cgi();

  my $content = $cgi->param('POSTDATA');

  if (!$content) {
    $content = $cgi->param('XForms:Model');
  }
  #warn $content;
  my $parser = $util->parser();

  my $parsed_xml;

  eval {
    $parsed_xml = $parser->parse_string($content);
    1;
  } or do {
    croak 'Not well formed xml';
  };

  my $method = $parsed_xml->getElementsByTagName('method');
  $method = lc $method;

  eval {
    $self->allowed_methods($method);
    1;
  } or do {
    croak $EVAL_ERROR
  };

  my $id_run = $parsed_xml->getElementsByTagName('id_run');

  if ($id_run) {
    my $end = $id_run->[0]->getAttribute('end');
    if(!$end){
      $end = 1;
    }
    return $self->only_run($id_run, $end, $method);
  }

  if($method eq 'instrument_statistics'){
    return $self->all_runs_instrument_statistics();
  }

  return $self->all_runs();

}

sub allowed_methods {
  my ($self, $method) = @_;

  my $allowed_methods = {
    run_graph => 1,
    instrument_statistics =>1,
  };

  if (!$allowed_methods->{$method}) {
    croak "This method ($method) is not allowed";
  }

  return 1;
}

sub response_object {
  my ($self, $response) = @_;

  return qq{<?xml version="1.0" encoding="utf-8"?><response>$response</response>};
}
sub only_run{
  my ($self, $id_run, $end, $method) = @_;
  if($method eq 'instrument_statistics'){
    return $self->one_run_instrument_statistics($id_run, $end);
  }
  return $self->one_run_graph($id_run, $end);
}
sub one_run_instrument_statistics {
  my ($self, $id_run, $end) = @_;

  my $util = $self->{util};

  my $response;

  my $instrument_statistics_model;

  eval{
	     $instrument_statistics_model = npg_qc::model::instrument_statistics->new({
				                            util => $util,
				                            id_run => $id_run,
				                            end    => $end,
			                     });
        $instrument_statistics_model->get_all_field_from_db();
        $response = "success: run($id_run $end) done for instrument_statistics";
	     1;
   } or do{
        carp $EVAL_ERROR;
        $response = "failed: $EVAL_ERROR";
   };

  return $self->response_object($response);
}

sub one_run_graph {
  my ($self, $id_run, $end) = @_;

  my $model = $self->model();

  my $response;
  eval{
    my $run_graph_model = $model->calculate_one_run($id_run, $end);
    my $actual_id_run = $run_graph_model->id_run();

    $response = "success: run($actual_id_run $end) done for run_graph";
    1;
  } or do{
    $response = "failed: $EVAL_ERROR"
  };

  return $self->response_object($response);
}

sub all_runs_instrument_statistics{
  my ($self) = @_;

  my $util = $self->{util};

  my $instrument_stat_model = npg_qc::model::instrument_statistics->new({
				                            util => $util,
				                            });
  my $response;
  eval{
    my $num_runs_done = $instrument_stat_model->calculate_all();

    $response = "success: $num_runs_done runs done for instrument statistics";
    1;
  } or do{
    $response = "failed: $EVAL_ERROR"
  };
  return $self->response_object($response);
}

sub all_runs {
  my ($self) = @_;
  my $model = $self->model();
  my $response;
  eval{
    my $num_runs_done = $model->calculate_all();

    $response = "success: $num_runs_done runs done for run_graph";
    1;
  } or do{
    $response = "failed: $EVAL_ERROR"
  };
  return $self->response_object($response);
}


sub list_yield_by_run_png {
  my ($self)    = @_;

  my $model     = $self->model();

  my $cgi       = $self->util->cgi();

  my $num_runs  = $cgi->param('size');
  if(!$num_runs){
    $num_runs = $NUM_RUNS_GRAPH ;
  }

  my $cycle_length  = $cgi->param('cycle');

  if(!$cycle_length){
    $cycle_length = $DEFAULT_CYCLE_LENGTH ;
  }
  my $data  = $model->get_yield_by_run($num_runs, $cycle_length);

  my $num_runs_actual = scalar @{$data};
  my $total = 0;
  my $num_runs_with_values = 0;
  foreach my $run (@{$data}) {
    pop @{$run};
    pop @{$run};
    my $yield = $run->[1];
    if(defined $yield){
      $total += $yield;
      $num_runs_with_values++;
    }
  }
  my $average = q{};
  if($num_runs_with_values){
    $average = sprintf '%.02f', $total/$num_runs_with_values;
  }
  my $specific_info = {
    data     => $data,
    legend   => [qq{Yield per Read (Ave - $average)}],
    y_label  => 'PF Yield per Read(MBases)',
    title    => "PF Yield per Read (Last $num_runs_actual reads)",
    num_runs => $num_runs_actual,
  };

  return $self->draw_graph_run_id_refactor($specific_info);
}

sub list_error_by_run_png {
  my ($self)    = @_;

  my $model     = $self->model();

  my $cgi       = $self->util->cgi();

  my $num_runs  = $cgi->param('size');

  if(!$num_runs){
    $num_runs = $NUM_RUNS_GRAPH ;
  }

  my $cycle_length  = $cgi->param('cycle');

  if(!$cycle_length){
    $cycle_length = $DEFAULT_CYCLE_LENGTH ;
  }

  my $data  = $model->get_avg_error_by_run($num_runs, $cycle_length);
  my $num_runs_actual = scalar @{$data};
  my $total = 0;
  my $num_runs_with_values = 0;
  foreach my $run (@{$data}) {
    pop @{$run};
    pop @{$run};
    my $error = $run->[1];
    if(defined $error){
      $total += $error;
      $num_runs_with_values++;
    }
  }
  my $average = q{};
  if($num_runs_with_values){
    $average = sprintf '%.02f', $total/$num_runs_with_values;
  }

  foreach my $row (@{$data}){
    my $error = $row->[1];
    if(defined $error && $error >$MAX_ERROR_SCALE){
      $row->[1] = $MAX_ERROR_SCALE;
    }
  }

  my $specific_info = {
    data    => $data,
    legend   => [qq{Error (Ave - $average)}],
    y_label => 'Error Rate %',
    title   => "Error Rate by Read (Last $num_runs_actual reads)",
    num_runs => $num_runs_actual,
  };

  return $self->draw_graph_run_id_refactor($specific_info);
}

sub list_cluster_per_tile_by_run_png {
  my ($self)    = @_;

  my $model     = $self->model();

  my $cgi       = $self->util->cgi();

  my $num_runs  = $cgi->param('size');
  if(!$num_runs){
    $num_runs = $NUM_RUNS_GRAPH ;
  }

  my $cycle_length  = $cgi->param('cycle');

  if(!$cycle_length){
    $cycle_length = $DEFAULT_CYCLE_LENGTH ;
  }

  my $data  = $model->get_cluster_per_tile_by_run($num_runs, $cycle_length);
  my $num_runs_actual = scalar @{$data};
  my $pf_total  = 0;
  my $raw_total = 0;
  my $num_runs_with_values = 0;
  foreach my $run (@{$data}) {
    pop @{$run};
    pop @{$run};
    my $pf_cluster =  $run->[1];
    my $raw_cluster = $run->[2];
    if(defined $pf_cluster && defined  $raw_cluster){
      $pf_total += $pf_cluster;
      $raw_total += $raw_cluster;
      $num_runs_with_values ++;
    }
  }
  my $pf_average = q{};
  my $raw_average = q{};
  if($num_runs_with_values){
    $pf_average = sprintf '%.02f', $pf_total/$num_runs_with_values;
    $raw_average = sprintf '%.02f', $raw_total/$num_runs_with_values;
  }
  my $specific_info = {
    data    => $data,
    legend  => [qq{PF Cluster (Ave - $pf_average)}, qq{Raw Cluster (Ave - $raw_average)}],
    y_label => 'Average Cluster Count per Tile',
    title   => "Average Cluster Count per Tile by Read (All Lanes, Last $num_runs_actual reads)",
    num_runs => $num_runs_actual,
  };

  return $self->draw_graph_run_id_refactor($specific_info);
}

sub list_cluster_per_tile_by_run_control_png {
  my ($self)    = @_;

  my $model     = $self->model();

  my $cgi       = $self->util->cgi();

  my $num_runs  = $cgi->param('size');
  if(!$num_runs){
    $num_runs = $NUM_RUNS_GRAPH ;
  }

  my $cycle_length  = $cgi->param('cycle');

  if(!$cycle_length){
    $cycle_length = $DEFAULT_CYCLE_LENGTH ;
  }

  my $data  = $model->get_cluster_per_tile_control_by_run($num_runs, $cycle_length);

  my $num_runs_actual = scalar @{$data};
  my $pf_total  = 0;
  my $raw_total = 0;
  my $num_runs_with_values = 0;
  foreach my $run (@{$data}) {
    pop @{$run};
    pop @{$run};
    my $pf_cluster =  $run->[1];
    my $raw_cluster = $run->[2];
    if(defined $pf_cluster && defined  $raw_cluster){
      $pf_total += $pf_cluster;
      $raw_total += $raw_cluster;
      $num_runs_with_values ++;
    }
  }
  my $pf_average = q{};
  my $raw_average = q{};
  if($num_runs_with_values){
    $pf_average = sprintf '%.02f', $pf_total/$num_runs_with_values;
    $raw_average = sprintf '%.02f', $raw_total/$num_runs_with_values;
  }

  my $specific_info = {
    data    => $data,
    legend  => [qq{PF Cluster (Ave - $pf_average)}, qq{Raw Cluster (Ave - $raw_average)}],
    y_label => 'Average Cluster Count per Tile',
    title   => "Average Cluster Count per Tile by Read (Control Lanes, Last $num_runs_actual reads)",
    num_runs => $num_runs_actual,
  };

  return $self->draw_graph_run_id_refactor($specific_info);
}

sub draw_graph_run_id_refactor {
  my ($self, $specific_info) = @_;

  my $cgi         = $self->util->cgi();
  my $graph_style = $cgi->param('style') || q{bars};

  my $x_label_skip;

  if ($specific_info->{num_runs}) {
    $x_label_skip = int $specific_info->{num_runs}/$MAX_X_LABEL;
  }

  my $graph_obj = npg::util::image::graph->new({util => $self->util});

  my $args = {
    'width'        => $WIDTH,
    'height'       => $HEIGHT,
    'title'        => $specific_info->{title},
    'x_label_skip' => $x_label_skip,
    'x_labels_vertical' => 1,
    'x_label'      => 'Run ID',
    'y_label'      => $specific_info->{y_label},
    'legend'      => $specific_info->{legend},
  };

  if ($specific_info->{legend_placement}) {
    $args->{legend_placement} = $specific_info->{legend_placement};
  }

  my $png = $graph_obj->plotter($specific_info->{data}, $args, $graph_style, undef);

  return $png;
}

sub list {
  my ($self) = @_;
  my $cgi   = $self->util->cgi();
  my $model = $self->model();
  $model->{graph_size} = $cgi->param('size') || $NUM_RUNS_GRAPH;
  $model->{graph_style} = $cgi->param('style')|| q{bars};
  $model->{cycle_length} = $cgi->param('cycle') || $DEFAULT_CYCLE_LENGTH;
  return 1;
}

sub list_instrument_statistics {
  my ($self) = @_;
  my $cgi   = $self->util->cgi();
  my $model = $self->model();
  $model->{instrument} = $cgi->param('instrument');
  $model->{num_runs} = $cgi->param('num_runs') || $DEFAULT_RUN_NUMS_INS;
  $model->{cycle_length} = $cgi->param('cycle') || $DEFAULT_CYCLE_LENGTH;
  return 1;
}

sub list_low_cluster_instrument_png {
  my ($self) = @_;
  my $cgi = $self->util->cgi();
  my $instrument = $cgi->param('instrument');
  my $num_runs   = $cgi->param('num_runs');
  my $cycle_length   = $cgi->param('cycle');
  my $instrument_statistics = $self->model->instrument_statistics();
  my $data;
  ($data, $num_runs) = $instrument_statistics->low_clusters({instrument   => $instrument,
                                                             no_of_runs   => $num_runs,
                                                             cycle_length => $cycle_length});

  my $specific_info = {
    data    => $data,
    y_label => 'Number of Tiles',
    title   => "$instrument - Tiles per Read with Low Raw Cluster Count (Last $num_runs)",
    num_runs => $num_runs,
  };

  return $self->draw_graph_run_id_refactor($specific_info);
}

sub list_high_cluster_instrument_png {
  my ($self) = @_;
  my $cgi = $self->util->cgi();
  my $instrument = $cgi->param('instrument');
  my $num_runs   = $cgi->param('num_runs');
  my $cycle_length   = $cgi->param('cycle');
  my $instrument_statistics = $self->model->instrument_statistics();
  my $data;
  ($data, $num_runs) = $instrument_statistics->high_clusters({instrument   => $instrument,
                                                             no_of_runs   => $num_runs,
                                                             cycle_length => $cycle_length});

  my $specific_info = {
    data    => $data,
    y_label => 'Number of Tiles',
    title   => "$instrument - Tiles per Read with High Raw Cluster Count (Last $num_runs)",
    num_runs => $num_runs,
  };

  return $self->draw_graph_run_id_refactor($specific_info);
}

sub list_low_intensity_instrument_png {
  my ($self) = @_;
  my $cgi = $self->util->cgi();
  my $instrument = $cgi->param('instrument');
  my $num_runs   = $cgi->param('num_runs');
  my $cycle_length   = $cgi->param('cycle');
  my $instrument_statistics = $self->model->instrument_statistics();
  my $data;
  ($data, $num_runs) = $instrument_statistics->low_intensity({instrument   => $instrument,
                                                              no_of_runs   => $num_runs,
                                                              cycle_length => $cycle_length});

  my $specific_info = {
    data    => $data,
    y_label => 'Number of Tiles',
    title   => "$instrument - Tiles per Read with Low Intensity (Last $num_runs)",
    num_runs => $num_runs,
  };

  return $self->draw_graph_run_id_refactor($specific_info);
}

sub list_high_intensity_instrument_png {
  my ($self) = @_;
  my $cgi = $self->util->cgi();
  my $instrument = $cgi->param('instrument');
  my $num_runs   = $cgi->param('num_runs');
  my $cycle_length   = $cgi->param('cycle');
  my $instrument_statistics = $self->model->instrument_statistics();
  my $data;
  ($data, $num_runs) = $instrument_statistics->high_intensity({instrument   => $instrument,
                                                               no_of_runs   => $num_runs,
                                                               cycle_length => $cycle_length});

  my $specific_info = {
    data    => $data,
    y_label => 'Number of Tiles',
    title   => "$instrument - Tiles per Read with High Intensity (Last $num_runs)",
    num_runs => $num_runs,
  };

  return $self->draw_graph_run_id_refactor($specific_info);
}
sub list_high_error_instrument_png {
  my ($self) = @_;
  my $cgi = $self->util->cgi();
  my $instrument = $cgi->param('instrument');
  my $num_runs   = $cgi->param('num_runs');
  my $cycle_length   = $cgi->param('cycle');
  my $instrument_statistics = $self->model->instrument_statistics();
  my $data;
  ($data, $num_runs) = $instrument_statistics->high_error({instrument   => $instrument,
                                                           no_of_runs   => $num_runs,
                                                           cycle_length => $cycle_length});

  my $specific_info = {
    data    => $data,
    y_label => 'Number of Tiles',
    title   => "$instrument - Tiles per Read with High Error Scores (Last $num_runs)",
    num_runs => $num_runs,
  };

  return $self->draw_graph_run_id_refactor($specific_info);
}
sub list_movez_out_instrument_png {
  my ($self) = @_;
  my $cgi = $self->util->cgi();
  my $instrument = $cgi->param('instrument');
  my $num_runs   = $cgi->param('num_runs');
  my $cycle_length   = $cgi->param('cycle');
  my $instrument_statistics = $self->model->instrument_statistics();
  my $data;
  ($data, $num_runs) = $instrument_statistics->movez_out({instrument   => $instrument,
                                                          no_of_runs   => $num_runs,
                                                          cycle_length => $cycle_length});

  my $specific_info = {
    data    => $data,
    y_label => 'Number of Tiles',
    title   => "$instrument - Tiles per Run with Move Z out of Spec (Last $num_runs)",
    num_runs => $num_runs,
  };

  return $self->draw_graph_run_id_refactor($specific_info);
}

sub list_yield_per_run_instrument_png {
  my ($self) = @_;
  my $cgi = $self->util->cgi();
  my $instrument = $cgi->param('instrument');
  my $num_runs   = $cgi->param('num_runs');
  my $cycle_length   = $cgi->param('cycle');
  my $instrument_statistics = $self->model->instrument_statistics();
  my $data;
  ($data, $num_runs) = $instrument_statistics->yield_per_run({instrument   => $instrument,
                                                              no_of_runs   => $num_runs,
                                                              cycle_length => $cycle_length});

  my $total = 0;
  foreach my $run (@{$data}) {
    $total += $run->[1];
  }
  my $average = sprintf '%.02f', $total/$num_runs;

  my $specific_info = {
    data     => $data,
    y_label  => 'Yield per Read (GBases)',
    title    => "$instrument - Yield per Read (Last $num_runs reads)",
    legend   => [qq{Yield (Ave - $average)}],
    num_runs => $num_runs,
  };

  return $self->draw_graph_run_id_refactor($specific_info);
}

sub list_avg_error_per_run_instrument_png {
  my ($self) = @_;
  my $cgi = $self->util->cgi();
  my $instrument = $cgi->param('instrument');
  my $num_runs   = $cgi->param('num_runs');
  my $cycle_length   = $cgi->param('cycle');
  my $instrument_statistics = $self->model->instrument_statistics();
  my $data;
  ($data, $num_runs) = $instrument_statistics->avg_error_per_run({instrument   => $instrument,
                                                                  no_of_runs   => $num_runs,
                                                                  cycle_length => $cycle_length});

  my $total = 0;
  foreach my $run (@{$data}) {
    $total += $run->[1];
  }
  my $average = sprintf '%.02f', $total/$num_runs;
  my $specific_info = {
    data     => $data,
    y_label  => 'Average Error per Read %',
    title    => "$instrument - Average Error per Read (Last $num_runs reads)",
    legend   => [qq{Error (Ave - $average)}],
    num_runs => $num_runs,
  };

  return $self->draw_graph_run_id_refactor($specific_info);
}


sub list_by_time {
  my ($self) = @_;
  return 1;
}

sub list_yield_by_week_png {
  my ($self) = @_;

  my $data = $self->model->get_yield_by_week();

  my $graph_obj = npg::util::image::graph->new({util => $self->util});

  my $args = {
    'width'        => $WIDTH,
    'height'       => $HEIGHT,
    'title'        => 'PF Yield (all runs) by Week',
    'x_labels_vertical' => 1,
    'x_label'      => 'Year-Week',
    'y_label'      => 'PF Yield (GBases)',
  };

  return $graph_obj->plotter($data, $args, 'area', undef);
}

sub list_avg_yield_per_read_lane_by_week_png {
  my ($self) = @_;

  my $data = $self->model->get_avg_yield_per_read_lane_by_week();

  my $graph_obj = npg::util::image::graph->new({util => $self->util});

  my $args = {
    'width'        => $WIDTH,
    'height'       => $HEIGHT,
    'title'        => 'PF Yield per Read Lane by Week',
    'x_labels_vertical' => 1,
    'x_label'      => 'Year-Week',
    'y_label'      => 'PF Yield per Read Lane(GBases)',
    'legend'       => ['all Cycles', 'Cycle 37', 'Cycle 54', 'Cycle 76', 'Cycle 108'],
    'dclrs'         => [ qw(lred green black blue cyan)],
  };

  return $graph_obj->plotter($data, $args, 'lines', 1);
}

sub list_cum_yield_by_week_png {
  my ($self) = @_;

  my $data = $self->model->get_cum_yield_by_week();

  my $graph_obj = npg::util::image::graph->new({util => $self->util});

  my $args = {
    'width'        => $WIDTH,
    'height'       => $HEIGHT,
    'title'        => 'Cumulative PF Yield (all runs) by Week',
    'x_labels_vertical' => 1,
    'x_label'      => 'Year-Week',
    'y_label'      => 'PF Yield (GBases)',
  };

  return $graph_obj->plotter($data, $args, 'area', undef);
}

sub list_error_by_week_png {
  my ($self) = @_;

  my $data = $self->model->get_error_by_week();

  my $graph_obj = npg::util::image::graph->new({util => $self->util});

  my $args = {
    'width'        => $WIDTH,
    'height'       => $HEIGHT,
    'title'        => 'Error Rate (all runs) by Week',
    'x_labels_vertical' => 1,
    'x_label'      => 'Year-Week',
    'y_label'      => '% Error (PF))',
  };

  return $graph_obj->plotter($data, $args, 'area', undef);
}

sub list_latest_runs_by_instrument{
    my ($self) = @_;
    my $cgi = $self->util->cgi();
    my $no_last_runs = $cgi->param('no_last_runs');
    my $instrument_statistics = $self->model->instrument_statistics();
    $no_last_runs = $instrument_statistics->latest_runs_by_instrument($no_last_runs);

    $self->model->{latest_runs} = $instrument_statistics->{latest_runs};

    $self->model->{no_last_runs} = $no_last_runs;

    return 1;
}
1;
__END__
=head1 NAME

npg_qc::view::run_graph

=head1 VERSION

$Revision: 17546 $

=head1 SYNOPSIS

  my $o = npg_qc::view::run_graph->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 decor - sets decor to 0, as only job is to process and respond with xml

=head2 content_type - sets content_type to 'application/xml'

=head2 render - renders view

=head2 create - overall handler to obtain xml and determine what to do with it

=head2 allowed_methods - returns true if xml requested method is ok

=head2 response_object - returns an xml response object with information in it

=head2 list - get the cgi parameters and save into the model

=head2 all_runs - handler to run the cache_query stuff for all runs in the database which need them

=head2 only_run - handler to run the caching of one run based on the requested method

=head2 one_run_graph - handler to run the caching of run_graph stuff for a single run, regenerating if they already exist

=head2 one_run_instrument_statistics - handler to run the caching of instrument statistics stuff for a single run, regenerating if they already exist

=head2 list_yield_by_run_png - generate yield by run png graph of last 100 runs, the number of runs can be passed in

=head2 list_cluster_per_tile_by_run_control_png - generate average cluster count per tile for both RAW and PF by run png graph of last 100 runs, the number of runs can be passed in, this just for control lanes

=head2 list_cluster_per_tile_by_run_png - generate average cluster count per tile for both RAW and PF by run png graph of last 100 runs, the number of runs can be passed in

=head2 list_error_by_run_png - generate average error by run png graph of last 100 runs, the number of runs can be passed in

=head2 draw_graph_run_id_refactor - refactor of common code used by read_*_png

=head2 list_movez_out_instrument_png
=head2 list_high_error_instrument_png
=head2 list_high_intensity_instrument_png
=head2 list_low_intensity_instrument_png
=head2 list_high_cluster_instrument_png
=head2 list_low_cluster_instrument_png
=head2 list_instrument_statistics
=head2 all_runs_instrument_statistics
=head2 list_yield_per_run_instrument_png
=head2 list_avg_error_per_run_instrument_png
=head2 list_latest_runs_by_instrument
=head2 list_avg_yield_per_read_lane_by_week_png

=head2 list_by_time

=head2 list_yield_by_week_png

=head2 list_cum_yield_by_week_png

=head2 list_error_by_week_png

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

strict
warnings
npg_qc::view

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

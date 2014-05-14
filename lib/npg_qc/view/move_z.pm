#########
# Author:        gq1
# Maintainer:    $Author: mg8 $
# Created:       2008-06-10
# Last Modified: $Date: 2012-04-02 10:00:34 +0100 (Mon, 02 Apr 2012) $
# Id:            $Id: move_z.pm 15413 2012-04-02 09:00:34Z mg8 $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/view/move_z.pm $
#

package npg_qc::view::move_z;
use strict;
use warnings;
use base qw(npg_qc::view);
use Readonly;
use Carp;
use English qw(-no_match_vars);

use npg::util::image::heatmap;
use npg::util::image::image_map;
use npg::util::image::graph;
use npg::util::image::scale;

our $VERSION = do { my ($r) = q$Revision: 15413 $ =~ /(\d+)/mxs; $r; };

Readonly our $WIDTH                => 800;
Readonly our $HEIGHT               => 460;
Readonly our $X_LABEL_SKIP         => 2640;
Readonly our $MAX_ERROR_PERCENTAGE => 20;
Readonly our $THUMB_HEIGHT         => 86;
Readonly our $THUMB_WIDTH          => 126;
Readonly our $LEGEND_WIDTH         => 260;
Readonly our $LEGEND_HEIGHT        => 50;
Readonly our $LEGEND_BAR_WIDTH     => 255;
Readonly our $LEGEND_BAR_HEIGHT    => 6;
Readonly our $HEATMAP_THUMB_WIDTH  => 3;
Readonly our $NOT_APPLICABLE       => 0;
Readonly our $LESS_THAN_5K         => 1;
Readonly our $BETWEEN_5K_10K       => 2;
Readonly our $GREATER_THAN_10K     => 3;

sub add_ajax {
  my ($self) = @_;
  return $self->list_refactor();
}

sub list_png {
  my ($self)    = @_;
  my $util      = $self->util();
  my $model     = $self->model();
  my $cgi       = $util->cgi();
  my $id_run  = $cgi->param('id_run');
  my $thumbnail = $cgi->param('thumb');
  my $graph_obj = npg::util::image::graph->new({util => $util});

  $model->{id_run} = $id_run;
  my $data  = $model->data_for_plot($id_run);

  my $title = "Z Value vs Time for Run $id_run";

  my $args = {
    'width'        => $WIDTH,
    'height'       => $HEIGHT,
    'title'        => $title,
    'x_label_skip' => $X_LABEL_SKIP,
    'x_labels_vertical' => 1,
    'x_label'      => 'Time',
    'y_label'      => 'NewZ',
   # 'y_min_value'  => 0,
   # 'y_max_value'  => $MAX_ERROR_PERCENTAGE,
  };

  if ($thumbnail && ($thumbnail eq 'true')) {
    $args->{height}  = $THUMB_HEIGHT;
    $args->{width}   = $THUMB_WIDTH;
    $args->{title}   = undef;
    $args->{x_label} = undef;
    $args->{y_label} = undef;
    $args->{legend}  = undef;
  }

  return $graph_obj->plotter($data, $args, q{lines}, undef);
}


sub list_heatmap_with_hover_ajax {
  my ($self) = @_;
  my $util      = $self->util();
  my $model     = $self->model();
  my $cgi       = $util->cgi();
  my $cycle_ref = $cgi->param('cycle_ref');
  my ($id_run, $cycle) = split /_/xms, $cycle_ref;
  $model->{id_run} = $id_run;
  $model->cycle($cycle);

  my $cycle_count = $model->cycle_count();

  if ($cycle > $cycle_count) {
    $cycle -= $cycle_count;
    $id_run = $model->id_run_pair($id_run);
  }

  my $data_refs = {
    id_run    => $id_run,
    end       => 1,
    dataset   => q{movez},
    image_url => $cgi->param('url'),
    id        => q{movez:} . $id_run . q{:} . $cycle,
    hover_map => 1,
    cycle     => $cycle,
  };

  my $rt_obj = npg_qc::model::run_tile->new({util => $self->util()});
  my $run_tiles = $rt_obj->run_tiles_per_run_by_lane_end($id_run);

  eval {
    my $end = 1;

    $data_refs->{data} = $self->list_heatmap_png($data_refs);
    foreach my $box (@{$data_refs->{data}}) {
      my $data_information = $box->[-1];
      my $params = q{id_run=} . $id_run . q{&position=} . $data_information->{position} . q{&tile=} . $data_information->{tile} . q{&end=} . $end . q{&cycle=} . $cycle;
      $data_information->{value} = $data_information->{value} == $NOT_APPLICABLE   ? 'n/a'
                                 : $data_information->{value} == $LESS_THAN_5K     ? '<5k'
                                 : $data_information->{value} == $BETWEEN_5K_10K   ? '5k-10k'
                                 : $data_information->{value} == $GREATER_THAN_10K ? '>10k'
                                 :                                                   q{}
                                 ;

      my $run_tile = $run_tiles->[$end-1]->[$data_information->{position}-1]->[$data_information->{tile} -1];
      my $id_run_tile = $run_tile->id_run_tile();

      $data_information->{url} = q{javascript:run_tile_page(SCRIPT_NAME+'/run_tile/' +} . $run_tile->id_run_tile() .q{);" onclick="open_tile_viewer(SCRIPT_NAME + '/run_tile/}. $id_run_tile.q{;read_tile_viewer');};

    }
    my $image_map_object = npg::util::image::image_map->new();
    $model->{map} = $image_map_object->render_map($data_refs);
  } or do {
    croak 'Unable to render map: ' . $EVAL_ERROR;
  };

  return 1;
}

sub list_heatmap_png {
  my ($self, $data_refs) = @_;

  my $util   = $self->util();
  my $model  = $self->model();
  my $cgi    = $util->cgi();

  my ($id_run, $cycle, $end);

  if ($data_refs) {
    $id_run = $data_refs->{id_run};
    $cycle  = $data_refs->{cycle};
    $end    = $data_refs->{end};
  } else {
    $id_run = $cgi->param('id_run');
    $cycle  = $cgi->param('cycle');
    $end    = $cgi->param('end');
  }

  $model->{id_run} = $id_run;

  my $thumbnail = $cgi->param('thumb') || q{};

  my $dataset;
  if($cycle){
    $dataset = $model->newz_by_cycle($id_run, $cycle);
  }elsif($end){
    $dataset = $model->variance_newz($id_run, $end);
  }else{
    $dataset = $model->variance_newz($id_run);
  }

  my $heatmap_obj = npg::util::image::heatmap->new({
    data_array => $dataset,
  });

  my $png;

  my $arg_refs = $thumbnail eq 'true' ? {
                                         vertical       => 1,
                                         tile_width     => $HEATMAP_THUMB_WIDTH,
                                        }
               :                        {}
               ;

  $model->{gradient_style} = 'movez';

  $arg_refs->{gradient_style} = $model->{gradient_style};

  $png = $heatmap_obj->plot_illumina_map($arg_refs);

  if ($data_refs->{hover_map}) {
    return $heatmap_obj->image_map_reference();
  }

  return $png;

}

sub list_heatmaps {
  my ($self) = @_;
  return $self->list_refactor();
}

sub list_legend_png{
  my ($self) = @_;

  my $scale = npg::util::image::scale->new({});

  my $png = $scale->get_legend({
    image_height => $LEGEND_HEIGHT,
    image_width  => $LEGEND_WIDTH,
    bar_height   => $LEGEND_BAR_HEIGHT,
    bar_width    => $LEGEND_BAR_WIDTH,
    orientation  => q(horizontal),
    colours      => [qw(grey black yellow red)],
    side_texts   => [qw(n/a <5k 5k-10k >10k)],
  });
  return $png;
}

sub list_alerts_add_ajax{
  my ($self) = @_;
  return $self->list_refactor();
}
1;
__END__
=head1 NAME

npg_qc::view::move_z

=head1 VERSION

$Revision: 15413 $

=head1 SYNOPSIS

  my $o = npg_qc::view::run_tile->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2       add_ajax     - main display method

=head2       list_heatmaps - display all heatmaps for all cycles

=head2       list_heatmap_png  - display one heatmap for one given cycle, if the cycle number not given, return a png to show the variance of the newz value

=head2       list_legend_png  - generate the color code of heatmap

=head2       list_png          - generate the newz vs time plot

=head2       list_alerts_add_ajax  - generate the id_run list with z value alerts

=head2       list_heatmap_with_hover_ajax - handler for an ajax request to generate/view a heatmap with a hover map for it

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

strict
warnings
npg_qc::view

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Guoying Qi, E<lt>gq1@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Andy Brown

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut

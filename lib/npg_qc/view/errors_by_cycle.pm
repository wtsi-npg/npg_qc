#########
# Author:        ajb
# Maintainer:    $Author: mg8 $
# Created:       2008-06-10
# Last Modified: $Date: 2012-04-02 10:00:34 +0100 (Mon, 02 Apr 2012) $
# Id:            $Id: errors_by_cycle.pm 15413 2012-04-02 09:00:34Z mg8 $
# Source:        $Source: /repos/cvs/webcore/SHARED_docs/cgi-bin/docrep,v $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/view/errors_by_cycle.pm $
#

package npg_qc::view::errors_by_cycle;
use strict;
use warnings;
use base qw(npg_qc::view);
use Readonly;
use English qw{-no_match_vars};
use Carp;
use npg::util::image::image_map;
use npg::util::image::heatmap;
use npg::util::image::graph;
use npg::util::image::merge;

our $VERSION = do { my ($r) = q$Revision: 15413 $ =~ /(\d+)/mxs; $r; };

Readonly our $WIDTH                => 600;
Readonly our $HEIGHT               => 350;
Readonly our $X_LABEL_SKIP         => 5;
Readonly our $X_LABEL_SKIP_THUMB   => 20;
Readonly our $MAX_ERROR_PERCENTAGE => 20;
Readonly our $THUMB_HEIGHT         => 86;
Readonly our $THUMB_WIDTH          => 126;
Readonly our $THUMBNAIL_TILE_WIDTH => 4;

sub list {
  my ($self) = @_;
  return $self->list_refactor();
}

sub list_heatmaps{
  my ($self) = @_;
  return $self->list_refactor();
}

sub list_ave_by_position {
  my ($self) = @_;
  return $self->list_refactor();
}

sub list_ec_scale_png {
  my ($self) = @_;
  return $self->read_scale_png({ orientation => 'horizontal', end_text => '>20', });
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

  my $data_refs = {
    id_run    => $id_run,
    end       => 1,
    dataset   => q{error_per_tile},
    image_url => $cgi->param('url'),
    id        => q{error_per_tile:} . $id_run . q{:} . $cycle,
    hover_map => 1,
  };

  my $rt_obj = npg_qc::model::run_tile->new({util => $self->util()});
  my $run_tiles = $rt_obj->run_tiles_per_run_by_lane_end($id_run);


  eval {
    my $end = 1;
    my $cycle_count = $model->cycle_count();

    if ($cycle > $cycle_count) {
      $cycle -= $cycle_count;
      $end = 2;
    }

    $data_refs->{data} = $self->list_heatmap_png($data_refs);
    foreach my $box (@{$data_refs->{data}}) {
      my $data_information = $box->[-1];
      my $params = q{id_run=} . $id_run . q{&position=} . $data_information->{position} . q{&tile=} . $data_information->{tile} . q{&end=} . $end . q{&cycle=} . $cycle;

      my $run_tile = $run_tiles->[$end-1]->[$data_information->{position}-1]->[$data_information->{tile} -1];
      my $id_run_tile = $run_tile->id_run_tile();

      $box->[-1]->{url} = q{javascript:run_tile_page(SCRIPT_NAME+'/run_tile/' +} . $run_tile->id_run_tile() .q{);" onclick="open_tile_viewer(SCRIPT_NAME + '/run_tile/}. $id_run_tile.q{;read_tile_viewer');};
    }
    my $image_map_object = npg::util::image::image_map->new();
    $model->{map} = $image_map_object->render_map($data_refs);
  } or do {
    croak 'Unable to render map: ' . $EVAL_ERROR;
  };

  return 1;
}

sub list_heatmap_png {
  my ($self, $data_refs)    = @_;
  my $util      = $self->util();
  my $model     = $self->model();
  my $cgi       = $util->cgi();
  my $cycle_ref = $cgi->param('cycle_ref');
  my ($id_run, $cycle) = split /_/xms, $cycle_ref;

  $model->{id_run} = $id_run;
  $model->cycle($cycle);

  my $thumbnail = $cgi->param('thumb') || q{};

  my $dataset = $model->heatmap_data_per_cycle();

  my $heatmap_obj = npg::util::image::heatmap->new({
    data_array => $dataset,
  });

  my $png;

  my $arg_refs = $thumbnail eq 'true' ? {
                                         vertical       => 1,
                                         tile_width     => $THUMBNAIL_TILE_WIDTH,
                                         gradient_style => 'percentage',
                                        }
               :                        {
                                         vertical       => 1,
                                         gradient_style => 'percentage',
                                        }
               ;
  eval {

    $png = $heatmap_obj->plot_illumina_map($arg_refs);

    1;

  } or do {

    croak $EVAL_ERROR;

  };

  if ($data_refs->{hover_map}) {
    return $heatmap_obj->image_map_reference();
  }

  return $png;

}

sub combine_error_and_blank_png {
  my ($self) = @_;
  my $args = {};
  $args->{second_pass} = 1;
  my $error_graph = $self->list_png($args);
  $args->{plot_type} = 1;
  my $blank_graph = $self->list_png($args);
  my $merge_obj = npg::util::image::merge->new();

  return $merge_obj->merge_images({
    'graph_1' => $error_graph,
    'graph_2' => $blank_graph,
    'width'   => $WIDTH,
    'height'  => $HEIGHT,
    'format'  => 'add_two_graphs_portrait',
  });

}

sub list_png { ##no critic (ProhibitExcessComplexity)
  my ($self, $ext_args) = @_;
  my $util          = $self->util();
  my $model         = $self->model();
  my $cgi           = $util->cgi();
  my $tile_ref      = $cgi->param('tile_ref');
  my $combine_two   = $cgi->param('combine_two');
  if ($tile_ref eq 'all') {
    return $self->complete_thumbnails_for_run_png();
  }
  if ($combine_two && !$ext_args->{second_pass}) {
    return $self->combine_error_and_blank_png();
  }
  my ($id_run, $position, $tile) = split /_/xms, $tile_ref;
  my $thumbnail    = $cgi->param('thumb');
  my $pre_chastity = $cgi->param('pre_chastity');
  my $plot_type    = $cgi->param('plot_type');
  my $graph_obj    = npg::util::image::graph->new({util => $util});
  my $type         = 'area';

  $model->{id_run} = $id_run;
  my $data  = $tile && ($plot_type || $ext_args->{plot_type}) ? $model->data_for_plot_blank_error($id_run, $position, $tile)
            : $tile && $pre_chastity                          ? $model->data_for_plot_including_pre_chastity($id_run, $position, $tile)
            : $tile                                           ? $model->data_for_plot($id_run, $position, $tile)
            :                                                   $model->average_perc_for_lane($id_run, $position)
            ;

  if(!scalar @{$data}){
    return 0;
  }

  my $title = $tile && $plot_type ? "Blank Base Error rate by cycle for Run $id_run, Position $position, Tile $tile"
            : $tile ? "Error percentage by cycle for Run $id_run, Position $position, Tile $tile."
            :         "Average Error percentage by cycle for Run $id_run, Position $position."
            ;

  my $args = {
    'width'        => $WIDTH,
    'height'       => $HEIGHT,
    'title'        => $title,
    'x_label_skip' => $X_LABEL_SKIP,
    'x_label'      => 'Cycle',
    'y_label'      => 'Percentage',
    'y_min_value'  => 0,
    'y_max_value'  => $MAX_ERROR_PERCENTAGE,
  };

  if (defined $thumbnail && $thumbnail eq 'true') {
    $args->{height}       = $THUMB_HEIGHT;
    $args->{width}        = $THUMB_WIDTH;
    $args->{x_label_skip} = $X_LABEL_SKIP_THUMB;
    $args->{title}        = undef;
    $args->{x_label}      = undef;
    $args->{y_label}      = undef;
    $args->{legend}       = undef;
  }
  if ($pre_chastity) {
    $args->{legend} = ['pre-chastity', 'post-chastity'];
    $type = 'lines';
  }

  if($plot_type || $ext_args->{plot_type}){
     $args->{dclrs} = [ qw(blue) ];
  }
  if ($combine_two && $ext_args->{second_pass}) {
    $args->{return_object} = 1;
  }

  return $graph_obj->plotter($data, $args, $type, undef);
}

sub list_complete_thumbnails_for_run {
  my ($self) = @_;
  $self->list_refactor();
  my $model = $self->model();
  $model->all_thumbs_map($self->complete_thumbnails_for_run_png(1));
  return 1;
}

sub complete_thumbnails_for_run_png {
  my ($self, $map) = @_;
  my $util = $self->util();
  my $cgi   = $util->cgi();
  my $model = $self->model();
  $model->id_run($cgi->param('id_run'));

  my $data = $model->all_thumbnail_data();

  my $image_store = npg_qc::model::image_store->new({
    util => $util,
    image_name => $model->{id_run}.q{_all_error_thumbs.png},
    type => 'errors_by_cycle',
    id_run => $model->{id_run},
    thumbnail => 0,
    suffix => 'png',
  });

  if ($image_store->id_image_store() && !$map) {
    return $image_store->image();
  }

  my $merge_obj = npg::util::image::merge->new({util => $util});

  my $arg_refs = {
    format          => 'all_error_thumbs',
    cols            => '1',
    data            => $data,
    col_headings    => ['Lane & Tile', 'Image'],
    id_run          => $model->{id_run},
    args_for_image  => {
      height       => $THUMB_HEIGHT,
      width        => $THUMB_WIDTH,
      x_label_skip => $X_LABEL_SKIP_THUMB,
      y_min_value  => 0,
      y_max_value  => $MAX_ERROR_PERCENTAGE,
      legend       => q{},
    },
  };
  my $png;
  eval { $png = $merge_obj->merge_images($arg_refs); 1; } or do { croak $EVAL_ERROR; };
  $image_store->image($png);
  eval { $image_store->save(); 1; } or do { croak $EVAL_ERROR; };

  if ($map) {
    return $merge_obj->image_map_reference();
  }

  return $png;
}

1;
__END__
=head1 NAME

npg_qc::view::errors_by_cycle

=head1 VERSION

$Revision: 15413 $

=head1 SYNOPSIS

  my $o = npg_qc::view::errors_by_cycle->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 list - handles the list view

=head2 list_ave_by_position - handles the list average by position

=head2 list_heatmaps - handles the list showing heatmaps

=head2 list_heatmap_png - handles rendering a png heatmap image for the information presented

=head2 list_png - handles rendering a png image for the information presented

=head2 list_ec_scale_png - handles rendering a png image for the scale of the heat gradients

=head2 list_heatmap_with_hover_ajax - handles rendering a return ajax html snippet which includes a map to hover over the rendered heatmap png

=head2 combine_error_and_blank_png - handles returning a joined image of two graphs

=head2 complete_thumbnails_for_run_png - handles returning a merged image of all the thumbnails for a run, and setting points for a hovermap

=head2 list_complete_thumbnails_for_run - handles displaying all thumbnails for a a run

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

strict
warnings
Carp
Readonly
English
npg_qc::view
npg::util::image::image_map
npg::util::image::heatmap
npg::util::image::graph

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

#########
# Author:        ajb
# Maintainer:    $Author$
# Created:       2008-06-26
# Last Modified: $Date$
# Id:            $Id$
# Source:        $Source: /repos/cvs/webcore/SHARED_docs/cgi-bin/docrep,v $
# $HeadURL$
#

package npg_qc::view::summary;
use strict;
use warnings;
use base qw(npg_qc::view);
use English qw{-no_match_vars};
use Carp;
use npg_qc::model::summary;
use npg::util::image::image_map;
use npg::util::image::heatmap;
use Readonly;
use npg::util::image::graph;

our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/mxs; $r; };

Readonly our $PERCENTAGE           => 100;
Readonly our $PERCENTAGE_ERROR     => '10+';
Readonly our $THUMBNAIL_TILE_WIDTH => 4;
Readonly our $WIDTH                => 800;
Readonly our $HEIGHT               => 600;
Readonly our $MAX_X_LABEL_TILE     => 100;

sub read { ## no critic (ProhibitBuiltinHomonyms)
  my ($self) = @_;
  my $model = $self->model();
  my $id_run_pair = $model->id_run_pair();
  if ($id_run_pair && $id_run_pair < $model->id_run()) {
    $model->id_run($id_run_pair);
  }
  return 1;
}

sub add_ajax {
  my ($self) = @_;
  return $self->list_refactor();
}

sub add_heatmaps_ajax {
  my ($self) = @_;

  my $util   = $self->util();
  my $model  = $self->model();
  my $cgi    = $util->cgi();
  $model->{datatype} = $cgi->param('datatype');

  $model->{gradient_style} = $model->{datatype} =~ /perc_error_rates/xms     ? 'percentage_error_rates'
                           : $model->{datatype} =~ /perc/xms                 ? 'percentage'
                           : $model->{datatype} =~ /clusters/xms             ? 'cluster'
                           : $model->{datatype} =~ /intensities/xms          ? 'intensity'
                           :                                                 undef
                           ;

  return $self->list_refactor();
}

sub add_heatmap_with_hover_ajax {
  my ($self) = @_;
  my $util   = $self->util();
  my $model  = $self->model();
  my $cgi    = $util->cgi();

  my $data_refs = {
    id_run    => $cgi->param('id_run'),
    end       => $cgi->param('end'),
    dataset   => $cgi->param('dataset'),
    image_url => $cgi->param('url'),
    id        => $cgi->param('dataset') . q{:} . $cgi->param('id_run') . q{:} . $cgi->param('end'),
    hover_map => 1,
  };

  eval {
    $data_refs->{data} = $self->list_heatmap_png($data_refs);
    my $image_map_object = npg::util::image::image_map->new();
    $model->{map} = $image_map_object->render_map($data_refs);
  } or do {
    croak 'Unable to render map: ' . $EVAL_ERROR;
  };

  return 1;
}


sub list_heatmaps {
  my ($self) = @_;
  return $self->list_refactor();
}

sub read_percentage_error_rates_scale_png {
  my ($self) = @_;
  return $self->read_scale_png({ orientation => 'horizontal', end_text => $PERCENTAGE_ERROR, });
}

sub read_percentage_scale_png {
  my ($self) = @_;
  return $self->read_scale_png({ orientation => 'horizontal', end_text => $PERCENTAGE, });
}

sub read_cluster_scale_png {
  my ($self) = @_;
  if ($self->is_ga2()) {
    return $self->read_scale_png({ orientation => 'horizontal', end_text => '200000+', });
  }
  return $self->read_scale_png({ orientation => 'horizontal', end_text => '50000+', });
}

sub read_intensity_scale_png {
  my ($self) = @_;
  if ($self->is_ga2()) {
    return $self->read_scale_png({ orientation => 'horizontal', end_text => '1000+', });
  }
  return $self->read_scale_png({ orientation => 'horizontal', end_text => '5000+', });
}

sub add_plot_ajax{
  my ($self) = @_;

  my $util   = $self->util();
  my $cgi    = $util->cgi();
  my $model  = $self->model();
  $model->{datatype} = $cgi->param('datatype');
  $model->{id_run} = $cgi->param('id_run');
  return 1;
}

sub list_plot_png{
  my ($self) = @_;

  my $util   = $self->util();
  my $cgi    = $util->cgi();
  my $model  = $self->model();
  my $id_run = $cgi->param('id_run');
  my $dataset = $cgi->param('datatype');

  my $data = $model->$dataset($id_run);

  my $num_tiles = scalar @{$data};
  my $x_label_skip = $num_tiles/$MAX_X_LABEL_TILE;

  my $graph_obj = npg::util::image::graph->new({util => $util});

  my $args = {
    'width'        => $WIDTH,
    'height'       => $HEIGHT,
    'title'        => "Number of $dataset vs Tile Number for Run $id_run",
    'x_labels_vertical' => 1,
    'x_label'      => 'Tile number',
    'y_label'      => 'Number of raw clusters',
    'legend'       => ['Lane1', 'Lane2', 'Lane3', 'Lane4', 'Lane5' ,'Lane6', 'Lane7', 'Lane8'],
    'x_label_skip' => $x_label_skip,
  };

  return $graph_obj->plotter($data, $args, q{lines}, undef);
}

sub list_heatmap_png {
  my ($self, $data_refs) = @_;
  my $util   = $self->util();
  my $model  = $self->model();
  my $cgi    = $util->cgi();

  $data_refs ||= {
    id_run  => $cgi->param('id_run'),
    end     => $cgi->param('end'),
    dataset => $cgi->param('dataset'),
  };

  $model->{id_run} = $data_refs->{id_run};

  my $thumbnail = $cgi->param('thumb') || q{};

  $data_refs->{thumb} = $thumbnail;

  my $dataset = $model->heatmap_data($data_refs);

  my $heatmap_obj = npg::util::image::heatmap->new({
    data_array => $dataset,
  });

  my $png;

  my $arg_refs = $thumbnail eq 'true' ? {
                                         vertical       => 1,
                                         tile_width     => $THUMBNAIL_TILE_WIDTH,
                                        }
               :                        {}
               ;

  $model->{gradient_style} = $data_refs->{dataset}  =~ /perc_error_rates/xms ? 'percentage_error_rates'
                           : $data_refs->{dataset}  =~ /perc/xms             ? 'percentage'
                           : $data_refs->{dataset}  =~ /clusters/xms         ? 'cluster'
                           : $data_refs->{dataset}  =~ /intensities/xms      ? 'intensity'
                           :                                                   undef
                           ;

  $arg_refs->{gradient_style} = $model->{gradient_style};

  eval {

    $png = $heatmap_obj->plot_illumina_map($arg_refs);

    1;

  } or do {

    croak $EVAL_ERROR;

  };

  if ($data_refs->{hover_map}) {
    return $heatmap_obj->image_map_reference();
  }

  if ($model->{gradient_style} && $model->{gradient_style} eq 'percentage_error_rates') {
    $data_refs->{reset_perc_error_rate_hm_max} = 1;
    $heatmap_obj->data_array($model->heatmap_data($data_refs));
    eval {

      $png = $heatmap_obj->plot_illumina_map($arg_refs);

      1;

    } or do {

      croak $EVAL_ERROR;

    };
  }

  return $png;

}

sub list_complete_data_xml{
  my ($self) = @_;
  return;
}

1;
__END__
=head1 NAME

npg_qc::view::summary

=head1 VERSION

$Revision$

=head1 SYNOPSIS

  my $oSummaryView = npg_qc::view::summary->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 list_onerun_complete_xml - return xml to tell whether the run with complete data in the database

=head2 new - inherited from base class, sets up object, passing into it the arguments given, and determining user

=head2 authorised - inherited from base class, only showing analysis data, at this time all are authorised

=head2 decor - sets decor to 0 if aspect is graph, else default

=head2 content_type - sets content_type to image/png if aspect is graph, else default

=head2 render - renders view, determining the aspect to view

=head2 add_ajax - handler to process if an add_ajax view request is made

=head2 add_heatmaps_ajax - handler for rendering the ajax response for heatmaps
=head2 list_heatmaps - handler for rendering a page with a number of heatmaps
=head2 read_cluster_scale_png - handler for rendering a scale png where the scale is for a cluster count
=head2 list_heatmap_png - handler for rendering a heatmap png
=head2 read_percentage_scale_png - handler for rendering a scale png where the scale is for a percentage
=head2 add_heatmap_with_hover_ajax - handler for an ajax request to generate/view a heatmap with a hover map for it
=head2 read_intensity_scale_png 

=head2 read - handler to ensure that if a second end id_run is used, then it defaults to the first end

=head2 list_complete_data_xml - return a list of paired runs with complete data set in database

=head2 read_percentage_error_rates_scale_png

=head2       add_plot_ajax

=head2       list_plot_png

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

strict
warnings
npg_qc::view
English
Carp

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

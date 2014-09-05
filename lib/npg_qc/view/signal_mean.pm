#########
# Author:        ajb
# Created:       2008-06-10
#

package npg_qc::view::signal_mean;
use strict;
use warnings;
use English qw{-no_match_vars};
use npg::util::image::graph;
use base qw(npg_qc::view);
use Readonly;
use npg_qc::model::image_store;
use npg::util::image::merge;
use Carp;

our $VERSION = '0';

Readonly our $STD_HEIGHT   => 600;
Readonly our $STD_WIDTH    => 500;
Readonly our $STD_Y        => 100;
Readonly our $X_LABEL_SKIP => 5;
Readonly our $X_LABEL_SKIP_THUMB => 11;
Readonly our $THUMB_HEIGHT => 84;
Readonly our $THUMB_WIDTH  => 126;
Readonly our $ALL_CALL_Y   => 15_000;
Readonly our $NO_OF_LANES_ON_CHIP => 8;

sub list {
  my ($self) = @_;
  my $util         = $self->util();
  my $model        = $self->model();
  my $cgi          = $util->cgi();
  $model->{id_run} = $cgi->param('id_run');
  $model->rescale_y($cgi->param('rescale_y'));
  return 1;
}

sub list_merged_png {
  my ($self)       = @_;
  my $util         = $self->util();
  my $model        = $self->model();
  my $cgi          = $util->cgi();
  my $id_run       = $cgi->param('id_run');
  $model->{id_run} = $id_run;

  my $original_rescale_y = $model->rescale_y();
  my $new_rescale_y      = $cgi->param('rescale_y');
  my $scale_to_use       = $new_rescale_y || $original_rescale_y;

  $model->rescale_y($scale_to_use);

  my $image_store = npg_qc::model::image_store->new({
    util => $util,
    image_name => $id_run.q{_merged_ivc_}.$scale_to_use.q{.png},
    type => 'signal_mean',
    id_run => $id_run,
    thumbnail => 0,
    suffix => 'png',
  });

  if ($image_store->id_image_store()) {
    return $image_store->image();
  }

  my $merge_obj = npg::util::image::merge->new({util => $util});
  my $data = $model->data_for_merge_ivc();
  my $arg_refs = {
    format          => 'table_landscape',
    rows            => '3',
    cols            => '8',
    data            => $data,
    row_headings => ['All', 'Call', '% Base Calls'],
    y_min_values    => [0,0,0],
    y_max_values    => [$scale_to_use,$scale_to_use,$STD_Y ],
    column_headings    => ['Lane', 1..$NO_OF_LANES_ON_CHIP],
    args_for_image  => {
      height       => $THUMB_HEIGHT,
      width        => $THUMB_WIDTH,
      x_label_skip => $X_LABEL_SKIP_THUMB,
    },
  };
  my $png;
  eval { $png = $merge_obj->merge_images($arg_refs); 1; } or do { croak $EVAL_ERROR; };
  $image_store->image($png);
  eval { $image_store->save(); 1; } or do { croak $EVAL_ERROR; };

  return $png;
}

sub list_png {
  my ($self)       = @_;
  my $util         = $self->util();
  my $model        = $self->model();
  my $cgi          = $util->cgi();
  my $plot         = $cgi->param('plot');
  my $id_run       = $cgi->param('id_run');
  $model->{id_run} = $id_run;
  my $position     = $cgi->param('position');
  my $thumbnail    = $cgi->param('thumb');
  my $original_rescale_y = $model->rescale_y();
  my $rescale_y    = $model->rescale_y($cgi->param('rescale_y'));

  my $graph;
  my $thumb = $thumbnail eq 'true' ? 1
            :                        0
            ;

  if ($original_rescale_y == $rescale_y) {
    my $image_store = npg_qc::model::image_store->new({
      util => $util,
      image_name => $id_run.q{_}.$position.q{_}.$plot.q{_}.$rescale_y.q{.png},
      type => 'signal_mean',
      id_run => $id_run,
      thumbnail => $thumb,
      suffix => 'png',
    });

    $graph = $image_store->image();
  }

  if (!$graph) {
    my $graph_obj    = npg::util::image::graph->new({util => $util});
    my $data = $model->$plot($position);

    my $args = {
     'x_label' => 'Cycle',
     'y_label' => 'Intensity',
     'title'   => ucfirst$plot . " Signal Mean for Run $id_run, Position $position",
     'legend'  => [qw(a c g t)],
     'height'  => $STD_HEIGHT,
     'width'   => $STD_WIDTH,
     'x_label_skip' => $X_LABEL_SKIP,
     'y_min_value'  => 0,
#   'y_max_value'  => $STD_Y,
    };

    if ($plot =~ /all/xms && $rescale_y ne 'self_scale') {
      $args->{y_max_value} = $rescale_y;
    }

    if($plot eq 'base'){
      $args->{y_label} = q{Percentage};
      $args->{y_max_value} = $STD_Y;
    }

    if ($thumbnail eq 'true') {
      $args->{height}       = $THUMB_HEIGHT;
      $args->{width}        = $THUMB_WIDTH;
      $args->{x_label_skip} = $X_LABEL_SKIP_THUMB;
      $args->{title}        = undef;
      $args->{x_label}      = undef;
      $args->{y_label}      = undef;
      $args->{legend}       = undef;
    }

    $graph = $graph_obj->plotter(
      $data,
      $args,
      q{},
      1
    );

    if ($original_rescale_y == $rescale_y) {
      my $image_store = npg_qc::model::image_store->new({
        util => $util,
        image_name => $id_run.q{_}.$position.q{_}.$plot.q{_}.$rescale_y.q{.png},
        type => 'signal_mean',
        id_run => $id_run,
        thumbnail => $thumb,
        suffix => 'png',
        image => $graph,
      });
      $image_store->save();
    }
  }

  return $graph;
}

1;
__END__
=head1 NAME

npg_qc::view::signal_mean

=head1 SYNOPSIS

  my $oSignalMeanView = npg_qc::view::signal_mean->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 list - handles the viewing of the IVC plot page

=head2 list_png - handles generating the png image base on parameters sent

=head2 list_merged_png - retrieves from db, or handles generating a merged png image of all the thumbnails for the IVC, and stores in db, returning image

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

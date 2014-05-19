#########
# Author:        ajb
# Maintainer:    $Author: mg8 $
# Created:       2008-06-10
# Last Modified: $Date: 2012-04-02 10:00:34 +0100 (Mon, 02 Apr 2012) $
# Id:            $Id: cumulative_errors_by_cycle.pm 15413 2012-04-02 09:00:34Z mg8 $
# Source:        $Source: /repos/cvs/webcore/SHARED_docs/cgi-bin/docrep,v $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/view/cumulative_errors_by_cycle.pm $
#

package npg_qc::view::cumulative_errors_by_cycle;
use strict;
use warnings;
use base qw(npg_qc::view);
use Readonly;
use npg::util::image::graph;

our $VERSION = '0';

Readonly our $WIDTH                => 800;
Readonly our $HEIGHT               => 460;
Readonly our $X_LABEL_SKIP         => 5;

sub list {
  my ($self) = @_;
  return $self->list_refactor();
}

sub list_png {
  my ($self)    = @_;
  my $model     = $self->model();
  my $cgi       = $self->util()->cgi();
  my $tile_ref  = $cgi->param('tile_ref');
  my $score     = $cgi->param('score');
  my ($id_run, $position, $tile) = split /_/xms, $tile_ref;
  my $graph_obj = npg::util::image::graph->new();

  $model->{id_run} = $id_run;
  my ($data) = $model->$score($id_run, $position, $tile);
  my $args = {
    'width'        => $WIDTH,
    'height'       => $HEIGHT,
    'title'        => ucfirst$score . " Cumulative Errors By Cycle for Run $id_run, Position $position, Tile $tile.",
    'x_label_skip' => $X_LABEL_SKIP,
    'x_label'      => 'Cycle',
    'y_label'      => q{Percentage Reads with 'x' Errors Or Less},
    'legend'       => [qw{=<4 =<3 =<2 =<1 0}],
  };
  return $graph_obj->plotter($data, $args, q{area}, undef);
}

1;
__END__
=head1 NAME

npg_qc::view::cumulative_errors_by_cycle

=head1 VERSION

$Revision: 15413 $

=head1 SYNOPSIS

  my $o = npg_qc::view::cumulative_errors_by_cycle->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 content_type - handler to determine the content type that should be returned

=head2 decor - handler to determine the decor required

=head2 render - handler to determine what to render

=head2 list - handler to put id_run onto the model

=head2 list_png - handles rendering a png image for the information presented

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

strict
warnings
Readonly
npg_qc::view
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

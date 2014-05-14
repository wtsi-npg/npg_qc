#########
# Author:        rmp
# Maintainer:    $Author: mg8 $
# Created:       2008-06-10
# Last Modified: $Date: 2013-08-22 14:28:15 +0100 (Thu, 22 Aug 2013) $
# Id:            $Id: view.pm 17408 2013-08-22 13:28:15Z mg8 $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/view.pm $
#
package npg_qc::view;
use strict;
use warnings;
use base qw(ClearPress::view);
use Carp;
use POSIX qw(strftime);
use English qw(-no_match_vars);

use npg::util::image::scale;
use npg_qc::model::run_tile;

use Readonly; Readonly::Scalar our $VERSION  => do { my ($r) = q$Revision: 17408 $ =~ /(\d+)/smx; $r; };

Readonly::Scalar our $GA2_MAX_TILE_COUNT => 100;

sub authorised {
  return 1;
}

sub decor {
  my ($self, @args) = @_;
  my $aspect = $self->aspect() || q();
  if($aspect =~ /\Aread_.*?png\z/xms || $aspect eq 'read_heatmap' || $aspect eq 'graph') {
    return 0;
  }
  return $self->SUPER::decor(@args);
}

sub content_type {
  my ($self, @args) = @_;
  my $aspect = $self->aspect();
  if($aspect && ($aspect =~ /\Aread_.*?png\z/xms || $aspect eq 'read_heatmap' || $aspect eq 'graph')) {
    return 'image/png';
  }
  return $self->SUPER::content_type(@args);
}

sub render {
  my ($self, @args) = @_;
  my $aspect = $self->aspect();
  if($aspect && ($aspect =~ /\Aread_.*?png\z/xms || $aspect eq 'read_heatmap' || $aspect eq 'graph')) {
    return $self->$aspect();
  }
  return $self->SUPER::render(@args);
}

sub list_refactor {
  my ($self) = @_;
  my $cgi   = $self->util->cgi();
  my $model = $self->model();
  $model->{id_run} = $cgi->param('id_run');
  return 1;
}

sub read_scale_png {
  my ($self, $arg_refs) = @_;
  return npg::util::image::scale->new()->plot_scale($arg_refs);
}

sub is_ga2 {
  my ($self) = @_;
  my $util   = $self->util();
  my $model  = $self->model();

  my $run_tile_object = npg_qc::model::run_tile->new({ util => $util, id_run => $model->id_run()});
  if ($run_tile_object->tile_max() == $GA2_MAX_TILE_COUNT) {
    return 1;
  }
  return 0;
}

sub app_version {
  return $VERSION;
}

sub time_rendered {
  my $time = strftime '%Y-%m-%dT%H:%M:%S', localtime;
  return $time;
}

sub is_prod {
  my $self = shift;
  my $db =  lc $self->util->dbsection;
  return $db eq q[live] ? 1 : 0;
}

1;

__END__

=head1 NAME

npg_qc::view - npg-qc MVC view superclass, derived from ClearPress::View

=head1 VERSION

$Revision: 17408 $

=head1 SYNOPSIS

  my $oView = npg_qc::view::<subclass>->new({'util' => $oUtil});
  $oView->model($oModel);

  print $oView->decor()?
    $sw->header()
    :
    q(Content-type: ).$oView->content_type()."\n\n";

  print $oView->render();

  print $oView->decor()?$sw->footer():q();

=head1 DESCRIPTION

View superclass for the NPG-QC MVC application

=head1 SUBROUTINES/METHODS

=head2 new - constructor

  my $oView = npg::view::<subclass>->new({'util' => $oUtil, ...});

=head2 authorised - authorize everybody

=head2 decor

=head2 content_type

=head2 render

=head2 list_refactor - refactor of common code to put id_run from cgi parameters onto the base model for the view

=head2 read_scale_png - returns a scale image for use with heatmaps

=head2 is_ga2 - returns true if the max tile count equals that for a GA2 (100)

=head2 app_version

=head2 time_rendered

=head2 is_prod

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

npg::model::user
npg::model::usergroup
ClearPress::view
Carp
English
npg::util::image::scale

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Roger Pettett

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut

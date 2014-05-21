#########
# Author:        ajb
# Maintainer:    $Author: mg8 $
# Created:       2008-06-10
# Last Modified: $Date: 2012-04-02 10:00:34 +0100 (Mon, 02 Apr 2012) $
# Id:            $Id: run_tile.pm 15413 2012-04-02 09:00:34Z mg8 $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/view/run_tile.pm $
#

package npg_qc::view::run_tile;
use strict;
use warnings;
use base qw(npg_qc::view);
use Carp;

our $VERSION = '0';

sub decor {
  my ($self, @args) = @_;

  my $aspect = $self->aspect() || q();

  if($aspect eq 'read_tile_viewer') {
    return 0;
  }

  return $self->SUPER::decor(@args);
}

sub read_tile_viewer {
  my ($self) = @_;
  my $model  = $self->model();
  my $cgi    = $self->util->cgi();
  $model->{tile_viewer} = 1;
  if ($model->id_run_tile()) {
  } else {
    $model->{id_run_tile} = $cgi->param('id_run_tile');
    $model->{id_run}      = $cgi->param('id_run');
    $model->{position}    = $cgi->param('position');
    $model->{tile}        = $cgi->param('tile');
    $model->{end}         = $cgi->param('end') || 1;
  }
  $model->{cycle}       = $cgi->param('cycle') || 1;
  $model->read();
  $model->{source}      = $cgi->param('source');
#croak "$model->{id_run_tile}:$model->{id_run}:$model->{position}";
  $model->{previous} = $model->{cycle} - 1;
  $model->{next}     = $model->{cycle} + 1;

  return;
}
sub list_movez_id_run_xml{
  my ($self) = @_;
  return;
}

sub list {
  my ($self, @args) = @_;

  my $cgi   = $self->util->cgi();
  my $model = $self->model();
  my ($id_run) = $cgi->param('id_run') =~ /(\d+)/xms;
  my ($position) = $cgi->param('position') =~ /(\d+)/xms;
  my ($end) = $cgi->param('end') =~ /(\d+)/xms;
  my ($tile) = $cgi->param('tile') =~ /(\d+)/xms;
  $model->id_run($id_run);
  $model->position($position);
  $model->end($end);
  $model->tile($tile);

  if (defined $model->tile()) {
    $model->retrieve_primary_key_value();
  }
  return $self->SUPER::list(@args);
}

1;
__END__
=head1 NAME

npg_qc::view::run_tile

=head1 VERSION

$Revision: 15413 $

=head1 SYNOPSIS

  my $o = npg_qc::view::run_tile->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 decor - handler to render no decor if read_tile_viewer selected

=head2 read_tile_viewer - handler to render the pop-up tile viewer

=head2 list_movez_id_run_xml - handler to return the list id_runs with movez data already in the database

=head2 list - handler so that is parameters of id_run, position, tile and end are given, it will redirect to read for the tile

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

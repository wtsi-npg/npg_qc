#########
# Author:        ajb
# Maintainer:    $Author: jo3 $
# Created:       2008-06-10
# Last Modified: $Date: 2010-03-30 16:40:28 +0100 (Tue, 30 Mar 2010) $
# Id:            $Id: tile_score.pm 8943 2010-03-30 15:40:28Z jo3 $
# Source:        $Source: /repos/cvs/webcore/SHARED_docs/cgi-bin/docrep,v $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/view/tile_score.pm $
#

package npg_qc::view::tile_score;
use strict;
use warnings;
use base qw(npg_qc::view);
use Carp;

our $VERSION = do { my ($r) = q$Revision: 8943 $ =~ /(\d+)/mxs; $r; };

sub list {
  my $self = shift;
  return $self->list_refactor();
}

sub list_error_rates {
  my ($self) = @_;
  $self->get_run_tile();
  return;
}

sub list_likelihood {
  my ($self) = @_;
  $self->get_run_tile();
  return;
}

sub list_words {
  my ($self) = @_;
  $self->get_run_tile();
  return;
}

sub list_blanks {
  my ($self) = @_;
  $self->get_run_tile();
  return;
}

sub list_rescore_info {
  my ($self) = @_;
  $self->get_run_tile();
  return;
}

sub get_run_tile {
  my ($self)   = @_;
  my $util     = $self->util();
  my $cgi      = $util->cgi();
  my $tile_ref = $cgi->param('tile_ref');

  my ($id_run, $position, $tile) = split /_/xms, $tile_ref;
  my $run_tile = npg_qc::model::run_tile->new({
    util     => $util,
    id_run   => $id_run,
    position => $position,
    tile     => $tile,
    end      => 1,
  });
  $run_tile->read();

  my $model = $self->model();
  my $new_model = $run_tile->tile_rescore();
  eval {
    $new_model->run_tile($run_tile);
  } or do {
    croak q{view unavailable for } . $run_tile->id_run . q{/} . $run_tile->position . q{/} . $run_tile->tile;
  };
  $self->model($new_model);
  return;
}

1;
__END__
=head1 NAME

npg_qc::view::tile_score

=head1 VERSION

$Revision: 8943 $

=head1 SYNOPSIS

  my $o = npg_qc::view::tile_score->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 list - handler to show all run tiles for run that will show various tile_score information

=head2 get_run_tile - gets the run_tile and sets the model to the rescore tile_score model for the run_tile
=head2 list_blanks - handler for showing the most common blank patterns for this tile (rescore)
=head2 list_error_rates - handler for showing the various ungraphed error rate tables for this tile (rescore)
=head2 list_likelihood - handler for showing the base likelihood rescores for this tile
=head2 list_rescore_info - handler for showing the general information after rescore for this tile
=head2 list_words - handler for showing the most common words for this tile (rescore)

=head2 list - list handler for view

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

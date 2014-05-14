#########
# Author:        ajb
# Maintainer:    $Author: jo3 $
# Created:       2008-06-10
# Last Modified: $Date: 2010-03-30 16:40:28 +0100 (Tue, 30 Mar 2010) $
# Id:            $Id: cumulative_errors_by_cycle.pm 8943 2010-03-30 15:40:28Z jo3 $
# Source:        $Source: /repos/cvs/webcore/SHARED_docs/cgi-bin/docrep,v $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/model/cumulative_errors_by_cycle.pm $
#

package npg_qc::model::cumulative_errors_by_cycle;
use strict;
use warnings;
use base qw(npg_qc::model);
use Readonly;
use Carp;
use English qw{-no_match_vars};


our $VERSION = do { my ($r) = q$Revision: 8943 $ =~ /(\d+)/mxs; $r; };

Readonly our $LAST_OF_ARRAY => -1;
Readonly our $PERCENTAGE => 100;

__PACKAGE__->mk_accessors(__PACKAGE__->fields());

sub fields {
  return qw(
            id_cumulative_errors_by_cycle
            id_run_tile
            cycle
            one
            two
            three
            four
            five
            rescore
          );
}

sub init {
  my $self = shift;

  if($self->id_run_tile() &&
     $self->cycle() &&
     defined $self->rescore() &&
     !$self->id_cumulative_errors_by_cycle()) {

    my $query = q(SELECT id_cumulative_errors_by_cycle
                 FROM cumulative_errors_by_cycle
                 WHERE id_run_tile = ?
                 AND cycle = ?
                 AND rescore = ?
                 );

    my $ref   = [];

    eval {
      $ref = $self->util->dbh->selectall_arrayref($query, {}, $self->id_run_tile(), $self->cycle(), $self->rescore());
      1;
    } or do {
      carp $EVAL_ERROR;
      return;
    };

    if(scalar @{$ref}) {
      $self->id_cumulative_errors_by_cycle($ref->[0]->[0]);
    }
  }
  return 1;
}
sub run_tile {
  my $self  = shift;
  my $pkg   = 'npg_qc::model::run_tile';
  return $pkg->new({
		    'util' => $self->util(),
		    'id_run_tile' => $self->id_run_tile(),
		   });
}

sub cumulative_errors_score {
  my ($self, $id_run, $position, $tile) = @_;
  my $arg_refs = {
    id_run   => $id_run,
    position => $position,
    tile     => $tile,
    rescore  => 0,
  };
  return $self->score_rescore_refactor($arg_refs);
}

sub cumulative_errors_rescore {
  my ($self, $id_run, $position, $tile) = @_;
  my $arg_refs = {
    id_run   => $id_run,
    position => $position,
    tile     => $tile,
    rescore  => 1,
  };
  return $self->score_rescore_refactor($arg_refs);
}

sub score_rescore_refactor {
  my ($self, $arg_refs) = @_;
  my $util = $self->util();
  my $dbh = $util->dbh();
  my $run_tile = npg_qc::model::run_tile->new({
    util     => $util,
    id_run   => $arg_refs->{id_run},
    position => $arg_refs->{position},
    tile     => $arg_refs->{tile},
    end      => 1,
  });

  my $other_end = $run_tile->other_end_tile();
  my $query = q{SELECT cycle, five, four, three, two, one
                FROM cumulative_errors_by_cycle
                WHERE id_run_tile = ?
                AND rescore = ?
                ORDER BY cycle};

  my $data = $dbh->selectall_arrayref($query, {}, $run_tile->id_run_tile(), $arg_refs->{rescore});

  if (!$data->[0]) {
   return [];
  }

  my $max_reads = 0;
  foreach my $cycle (@{$data}) {
    my $count = 0;
    foreach my $value (@{$cycle}) {
      $count++;
      next if ($count == 1);
      if ($value > $max_reads) {
        $max_reads = $value;
      }
    }
  }

  foreach my $cycle (@{$data}) {
    my $count = 0;
    foreach my $value (@{$cycle}) {
      $count++;
      next if ($count == 1);
      $value = $value * $PERCENTAGE / $max_reads;
    }
  }

  if ($other_end) {
    $max_reads = 0;
    my $add_cycle_count = $data->[$LAST_OF_ARRAY]->[0];
    my $data_two = $dbh->selectall_arrayref($query, {}, $other_end->id_run_tile(), $arg_refs->{rescore});
    foreach my $cycle (@{$data_two}) {
      $cycle->[0] += $add_cycle_count;
      my $count = 0;
      foreach my $value (@{$cycle}) {
        $count++;
        next if ($count == 1);
        if ($value > $max_reads) {
          $max_reads = $value;
        }
      }
    }
    foreach my $cycle (@{$data_two}) {
      my $count = 0;
      foreach my $value (@{$cycle}) {
        $count++;
        next if ($count == 1);
        $value = $value * $PERCENTAGE / $max_reads;
      }
      push @{$data}, $cycle;
    }
  }

  return $data;
}

1;
__END__

=head1 NAME

npg_qc::model::cumulative_errors_by_cycle

=head1 VERSION

$Revision: 8943 $

=head1 SYNOPSIS

  my $oCumulativeErrorsByCycle = npg_qc::model::cumulative_errors_by_cycle->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - return array of fields, first of which is the primary key

  my $aFields = $oCumulativeErrorsByCycle->fields();

=head2 run_tile - returns run_tile object that this object belongs to

  my $oRunTile = $oCumulativeErrorsByCycle->run_tile();

=head2 run_tiles - returns an arrayref of all the run_tiles for a given run (in $self->{id_run})

  my $aRunTiles = $oCumulativeErrorsByCycle->run_tiles();

=head2 run_tiles_uniq_names - returns an arrayref of unique tile names in the format <id_run>_<lane>_<tile_no>

  my $aRunTilesUnigNames = $oCumulativeErrorsByCycle->run_tiles_uniq_names();

=head2 cumulative_errors_score - handler to return with only data from score
=head2 cumulative_errors_rescore - handler to return with only data from rescore
=head2 score_rescore_refactor - common code to return data either from score or rescore

  my $aScore   = $oCumulativeErrorsByCycle->cumulative_errors_score($id_run, $position, $tile);
  my $aRescore = $oCumulativeErrorsByCycle->cumulative_errors_rescore($id_run, $position, $tile);
  
=head2 init

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

strict
warnings
npg_qc::model

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

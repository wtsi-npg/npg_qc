#########
# Author:        ajb
# Created:       2008-06-10
#

package npg_qc::model::tile_score;
use strict;
use warnings;
use English qw(-no_match_vars);
use Carp;
use base qw(npg_qc::model);

our $VERSION = '0';

__PACKAGE__->mk_accessors(__PACKAGE__->fields());

sub fields {
  return qw(
            id_tile_score
            id_run_tile
            base_count
            error_count
            blank_count
            unique_alignments
            ua_total_score
            cycles
            rescore
            score_version
            score_date_run
            phagealign_version
            phagealign_date_run
            max_blanks
            seq_length
            genome_file
            bases_used
            qualityfilter_version
            qualityfilter_date_run
            filter_criterion
          );
}

sub init {
  my ($self) = @_;
  if ($self->id_run_tile() && defined $self->rescore() && !$self->id_tile_score()) {
    my $query = q(SELECT id_tile_score
                  FROM   tile_score
                  WHERE  id_run_tile = ?
                  AND    rescore = ?);
    my $ref   = [];
    eval {
      $ref = $self->util->dbh->selectall_arrayref($query, {}, $self->id_run_tile(), $self->rescore());
      1;
    } or do {
      carp $EVAL_ERROR;
      return;
    };
    if(@{$ref}) {
      $self->{'id_tile_score'} = $ref->[0]->[0];
    }
  }
  return 1;
}

sub tile_scores {
  my $self = shift;
  return $self->gen_getall();
}

sub run_tile {
  my ($self, $run_tile) = @_;
  if ($run_tile) {
    $self->{run_tile} = $run_tile;
  }
  if (!$self->{run_tile}) {
    my $pkg   = 'npg_qc::model::run_tile';
    $self->{run_tile} = $pkg->new({
      'util' => $self->util(),
      'id_run_tile' => $self->id_run_tile(),
    });
  }
  return $self->{run_tile};
}

1;
__END__
=head1 NAME

npg_qc::model::tile_score

=head1 SYNOPSIS

  my $oTileScore = npg_qc::model::tile_score->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - return array of fields, first of which is the primary key

  my $aFields = $oTileScore->fields();

=head2 init - on creation looks for id_tile_score and sets it if it can

=head2 tile_scores - returns array of all tile_score objects

  my $aTileScores = $oTileScore->tile_scores();

=head2 run_tile - returns run_tile object that this object belongs to

  my $oRunTile = $oTileScore->run_tile();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

strict
warnings
npg_qc::model
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

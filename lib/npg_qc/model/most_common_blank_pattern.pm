#########
# Author:        ajb
# Created:       2008-06-10
#

package npg_qc::model::most_common_blank_pattern;
use strict;
use warnings;
use base qw(npg_qc::model);
use English qw{-no_match_vars};
use Carp;


our $VERSION = '0';

__PACKAGE__->mk_accessors(__PACKAGE__->fields());

sub fields {
  return qw(
            id_most_common_blank_pattern
            id_run_tile
            rank
            occurrence
            pattern
            number_of_sequences
            rescore
          );
}

sub init{
  my $self = shift;

  if($self->id_run_tile() &&
     $self->rank() &&
     $self->occurrence() &&
     $self->pattern() &&
     $self->number_of_sequences() &&
     defined $self->rescore() &&
     !$self->id_most_common_blank_pattern()) {

    my $query = q(SELECT id_most_common_blank_pattern
                 FROM most_common_blank_pattern
                 WHERE id_run_tile = ?
                 AND rank = ?
                 AND occurrence = ?
                 AND pattern = ?
                 AND number_of_sequences = ?
                 AND rescore = ?
                 );

    my $ref   = [];

    eval {
      $ref = $self->util->dbh->selectall_arrayref($query, {},
                  $self->id_run_tile(), $self->rank(), $self->occurrence(),
                  $self->pattern(), $self->number_of_sequences(), $self->rescore());
      1;
    } or do {
      carp $EVAL_ERROR;
      return;
    };

    if(@{$ref}) {
      $self->id_most_common_blank_pattern($ref->[0]->[0]);
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

1;
__END__
=head1 NAME

npg_qc::model::most_common_blank_pattern

=head1 SYNOPSIS

  my $oMostCommonBlankPattern = npg_qc::model::most_common_blank_pattern->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - return array of fields, first of which is the primary key

  my $aFields = $oMostCommonBlankPattern->fields();

=head2 run_tile - returns run_tile object that this object belongs to

  my $oRunTile = $oMostCommonBlankPattern->run_tile();

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

#########
# Author:        ajb
# Maintainer:    $Author$
# Created:       2008-06-10
# Last Modified: $Date$
# Id:            $Id$
# Source:        $Source: /repos/cvs/webcore/SHARED_docs/cgi-bin/docrep,v $
# $HeadURL$
#

package npg_qc::model::log_likelihood;
use strict;
use warnings;
use base qw(npg_qc::model);
use English qw{-no_match_vars};
use Carp;

our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/mxs; $r; };

__PACKAGE__->mk_accessors(__PACKAGE__->fields());

sub fields {
  return qw(
            id_log_likelihood
            id_run_tile
            cycle
            read_as
            really_a
            really_c
            really_g
            really_t
            rescore
          );
}

sub init {
  my $self = shift;

  if($self->id_run_tile() &&
     $self->read_as() &&
     $self->cycle() &&
     defined $self->rescore() &&
     !$self->id_log_likelihood()) {

    my $query = q(SELECT id_log_likelihood
                 FROM log_likelihood
                 WHERE id_run_tile = ?
                 AND cycle = ?
                 AND read_as = ?
                 AND rescore = ?
                 );

    my $ref   = [];

    eval {
      $ref = $self->util->dbh->selectall_arrayref($query, {}, $self->id_run_tile(), $self->cycle(), $self->read_as(), $self->rescore());
      1;
    } or do {
      carp $EVAL_ERROR;
      return;
    };

    if(@{$ref}) {
      $self->id_log_likelihood($ref->[0]->[0]);
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

npg_qc::model::log_likelihood

=head1 VERSION

$Revision$

=head1 SYNOPSIS

  my $oLogLikelihood = npg_qc::model::log_likelihood->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - return array of fields, first of which is the primary key

  my $aFields = $oLogLikelihood->fields();

=head2 run_tile - returns run_tile object that this object belongs to

  my $oRunTile = $oLogLikelihood->run_tile();

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

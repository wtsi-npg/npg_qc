#########
# Author:        ajb
# Maintainer:    $Author: jo3 $
# Created:       2008-08-07
# Last Modified: $Date: 2010-03-30 16:40:28 +0100 (Tue, 30 Mar 2010) $
# Id:            $Id: run_and_pair.pm 8943 2010-03-30 15:40:28Z jo3 $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/model/run_and_pair.pm $
#

package npg_qc::model::run_and_pair;
use strict;
use warnings;
use English qw{-no_match_vars};
use Carp;
use base qw(npg_qc::model);

our $VERSION = '0';

__PACKAGE__->mk_accessors(__PACKAGE__->fields());

sub fields {
  return qw(
            id_run_and_pair
            id_run
            id_run_pair
          );
}

sub init {
  my ($self) = @_;
  if ( defined $self->{id_run}  && !$self->{id_run_and_pair}) {

    my $query = q(SELECT id_run_and_pair, id_run_pair
                  FROM   run_and_pair
                  WHERE  id_run = ?);

    my $ref   = [];

    eval {

      $ref = $self->util->dbh->selectall_arrayref($query, {}, $self->id_run());
      1;

    } or do {

      carp $EVAL_ERROR;
      return;

    };

    if($ref->[0]->[0]) {

      $self->{'id_run_and_pair'} = $ref->[0]->[0];
      $self->{'id_run_pair'}     = $ref->[0]->[1];

    } else {

      $query = q(SELECT id_run_and_pair, id_run, id_run_pair
                 FROM   run_and_pair
                 WHERE  id_run_pair = ?);
      $ref   = [];

      eval {

        $ref = $self->util->dbh->selectall_arrayref($query, {}, $self->id_run());
        1;

      } or do {

        carp $EVAL_ERROR;
        return;

      };

      if($ref->[0]->[0]) {
        $self->{'id_run_and_pair'} = $ref->[0]->[0];
        $self->{'id_run'}          = $ref->[0]->[1];
        $self->{'id_run_pair'}     = $ref->[0]->[2];
      }

    }

  }

  return 1;
}

sub run_and_pairs {
  my $self = shift;
  return $self->gen_getall();
}


1;
__END__
=head1 NAME

npg_qc::model::run_and_pair


=head1 VERSION

$Revision: 8943 $

=head1 SYNOPSIS

  my $oRunAndPair = npg_qc::model::run_and_pair->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - return array of fields, first of which is the primary key

  my $aFields = $oRunAndPair->fields();

=head2 init - initialiser to obtain id_run_and_pair if id_run given in object creation (if id_run is id_run_pair, will try this as well)

=head2 run_and_pairs - returns array of run_and_pair objects

  my $aRunAndPairs = $oRunAndPair->run-and_pairs();

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

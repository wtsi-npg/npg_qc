#########
# Author:        ajb
# Maintainer:    $Author: jo3 $
# Created:       2008-11-23
# Last Modified: $Date: 2010-03-30 16:40:28 +0100 (Tue, 30 Mar 2010) $
# Id:            $Id: image_store.pm 8943 2010-03-30 15:40:28Z jo3 $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/model/image_store.pm $
#

package npg_qc::model::image_store;
use strict;
use warnings;
use base qw(npg_qc::model);
use English qw{-no_match_vars};
use Readonly;
use Carp;

our $VERSION = '0';


__PACKAGE__->mk_accessors(__PACKAGE__->fields());

sub fields {
  return qw(
            id_image_store
            type
            thumbnail
            image
            image_name
            id_run
            suffix
          );
}

sub init {
  my $self = shift;

  if($self->id_run() &&
     $self->image_name() &&
     $self->type() &&
     defined $self->thumbnail() &&
     !$self->id_image_store()) {

    my $query = q(SELECT id_image_store
                 FROM image_store
                 WHERE id_run = ?
                 AND thumbnail = ?
                 AND image_name = ?
                 AND type = ?
                 );

    my $ref   = [];

    eval {
      $ref = $self->util->dbh->selectall_arrayref(
        $query,
        {},
        $self->id_run(),
        $self->thumbnail(),
        $self->image_name(),
        $self->type()
      );
      1;
    } or do {
      carp $EVAL_ERROR;
      return;
    };

    if(@{$ref}) {
      $self->id_image_store($ref->[0]->[0]);
    }
  }

  return 1;
}

1;
__END__
=head1 NAME

npg_qc::model::image_store

=head1 VERSION

$Revision: 8943 $

=head1 SYNOPSIS

  my $oImageStore = npg_qc::model::image_store->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - returns an array of the column names in the database table

=head2 init - if the id_run, image_name, thumbnail Boolean and type provide, will return the id_image_store

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

strict
warnings
npg_qc::model
English
Readonly
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

#########
# Author:        gq1
# Maintainer:    $Author: jo3 $
# Created:       2009-05-21
# Last Modified: $Date: 2010-03-30 16:40:28 +0100 (Tue, 30 Mar 2010) $
# Id:            $Id: run_recipe.pm 8943 2010-03-30 15:40:28Z jo3 $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/model/run_recipe.pm $
#

package npg_qc::model::run_recipe;
use strict;
use warnings;
use base qw(npg_qc::model);
use English qw(-no_match_vars);
use Carp;
use Readonly;

our $VERSION = '0';

__PACKAGE__->mk_accessors(__PACKAGE__->fields());
__PACKAGE__->has_all();

sub fields {
  return qw(
            id_run_recipe
            id_run
            lane
            tile
            cycle
            col
            first_indexing_cycle
            last_indexing_cycle
            cycle_read1
            cycle_read2
            id_recipe_file
          );
}

sub init {
  my $self = shift;

  if($self->{id_run} &&
     !$self->{'id_run_recipe'}) {

    my $query = q(SELECT id_run_recipe
                  FROM   run_recipe
                  WHERE  id_run= ?
                 );

    my $ref   = [];

    eval {
      $ref = $self->util->dbh->selectall_arrayref($query, {}, $self->id_run());
      1;
    } or do {
      carp $EVAL_ERROR;
      return;
    };

    if(@{$ref}) {
      $self->{'id_run_recipe'} = $ref->[0]->[0];
    }
  }
  return 1;
}

sub recipe_xml {
  my ($self) = @_;

  if(!$self->id_recipe_file()){
    $self->init();
  }

  my $xml;
  eval {
    my $dbh = $self->util->dbh();
    my $query = q{SELECT xml FROM recipe_file WHERE id_recipe_file = ? };
    my $sth = $dbh->prepare($query);
    $sth->execute($self->id_recipe_file());

    my @row = $sth->fetchrow_array();
    if(scalar @row){
      $xml = $row[0];
    }
    1;
  } or do {
    croak $EVAL_ERROR;
  };

  return $xml;
}

1;
__END__

=head1 NAME

npg_qc::model::run_recipe

=head1 VERSION

$Revision: 8943 $

=head1 SYNOPSIS

  my $oRunRecipe = npg_qc::model::run_recipe->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields

=head2 init

=head2 recipe_xml

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

strict
warnings
npg_qc::model
Carp
Readonly

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Guoying Qi, E<lt>gq1@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Guoying Qi

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut

#########
# Author:        gq1
# Maintainer:    $Author: jo3 $
# Created:       2010-01-05
# Last Modified: $Date: 2010-03-30 16:40:28 +0100 (Tue, 30 Mar 2010) $
# Id:            $Id: run_info.pm 8943 2010-03-30 15:40:28Z jo3 $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/model/run_info.pm $
#

package npg_qc::model::run_info;
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
            id_run_info
            id_run
            run_info_xml
          );
}

sub init {
  my $self = shift;

  if($self->{id_run} &&
     !$self->{'id_run_info'}) {

    my $query = q(SELECT id_run_info
                  FROM   run_info
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
      $self->{'id_run_info'} = $ref->[0]->[0];
    }
  }
  return 1;
}

1;
__END__

=head1 NAME

npg_qc::model::run_info

=head1 VERSION

$Revision: 8943 $

=head1 SYNOPSIS

  my $oRunRecipe = npg_qc::model::run_info->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields

=head2 init

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

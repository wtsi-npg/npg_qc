#########
# Author:        gq1
# Maintainer:    $Author: jo3 $
# Created:       2008-07-29
# Last Modified: $Date: 2010-03-30 16:40:28 +0100 (Tue, 30 Mar 2010) $
# Id:            $Id: runlog_sax_handler_simple.pm 8943 2010-03-30 15:40:28Z jo3 $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/model/runlog_sax_handler_simple.pm $
#

package npg_qc::model::runlog_sax_handler_simple;

use strict;
use warnings;
use English qw(-no_match_vars);
use Carp;
use npg_qc::model::move_z;
use npg_qc::model::run_tile;

use base qw(XML::SAX::Base);

our $VERSION = '0';

my $in_tile = 0;
my $run_tile;

sub start_element {
  my ($self, $data) = @_;

  if($data->{Name} eq 'tile'){
    $in_tile = 1;
    my $arg_refs = {
      id_run   => $data->{Attributes}{'{}id_run'}{Value},
      tile     => $data->{Attributes}{'{}tile'}{Value},
      position => $data->{Attributes}{'{}position'}{Value},
      end      => $data->{Attributes}{'{}end'}{Value},
      row      => $data->{Attributes}{'{}row'}{Value},
      col      => $data->{Attributes}{'{}col'}{Value},
      avg_newz => $data->{Attributes}{'{}avg_newz'}{Value},
    };
    $run_tile = $self->get_run_tile($arg_refs);
    #warn values %{$arg_refs}, "\n";   
  }

  if ($data->{Name} eq 'move_z' ) {
    if($in_tile){
      my $move_z_object = npg_qc::model::move_z->new({
        util        => $self->{util},
        id_run_tile => $run_tile->id_run_tile(),
        cycle       => $data->{Attributes}{'{}cycle'}{Value},
        currentz    => $data->{Attributes}{'{}currentz'}{Value},
        targetz     => $data->{Attributes}{'{}targetz'}{Value},
        newz        => $data->{Attributes}{'{}newz'}{Value},
        start       => $data->{Attributes}{'{}start'}{Value},
        stop        => $data->{Attributes}{'{}stop'}{Value},
        move        => $data->{Attributes}{'{}move'}{Value},
      });

      eval {
        $move_z_object->save();
        1;
      }
      or do {
                croak $EVAL_ERROR;
      };
    }
  }
  return;
}

sub end_element {
  my ($self, $data) = @_;
  if($data->{Name} eq 'tile'){
    $in_tile = 0;
    undef $run_tile;
  }
  return;
}
sub start_document {
  my ($self, $doc) = @_;
  # process document start event
  return;
}

sub end_document {
  my ($self, $doc) = @_;
  #warn "finish the document\n";
  return;
}

sub get_run_tile {
  my ($self, $arg_refs) = @_;
  my $util = $self->{util};

  my $run_tile_object = npg_qc::model::run_tile->new({
    util     => $util,
    id_run   => $arg_refs->{id_run},
    tile     => $arg_refs->{tile},
    position => $arg_refs->{position},
    end      => $arg_refs->{end},
  });

  if (defined $arg_refs->{row} || defined $arg_refs->{col} || defined $arg_refs->{avg_newz}) {

    if (! defined $arg_refs->{row}) {
      $arg_refs->{row} = undef;
    }
    if (! defined $arg_refs->{col}) {
      $arg_refs->{col} = undef;
    }
    if (! defined $arg_refs->{avg_newz}) {
      $arg_refs->{avg_newz} = undef;
    }

    $run_tile_object->row($arg_refs->{row});
    $run_tile_object->col($arg_refs->{col});
    $run_tile_object->avg_newz($arg_refs->{avg_newz});
#    eval {
#      my $dbh = $util->dbh();
       $run_tile_object->save();
#      $dbh->commit();
#    } or do {
#     croak $EVAL_ERROR;
#    };
  }
  return $run_tile_object;
}
1;
__END__
=head1 NAME

npg_qc::model::runlog_sax_handler_simple

=head1 VERSION

$Revision: 8943 $

=head1 SYNOPSIS

  my $oRunlogSaxHandler = npg_qc::api::process::runlog_sax_handler->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2     end_document  - SAX method
=head2     end_element
=head2     get_run_tile - store the data into database
=head2     start_document
=head2     start_element


=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

strict
warnings
npg_qc::model

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

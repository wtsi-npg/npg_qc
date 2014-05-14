#########
# Author:        ajb
# Maintainer:    $Author: jo3 $
# Created:       2008-06-10
# Last Modified: $Date: 2010-03-30 16:40:28 +0100 (Tue, 30 Mar 2010) $
# Id:            $Id: run_config.pm 8943 2010-03-30 15:40:28Z jo3 $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/model/run_config.pm $
#

package npg_qc::model::run_config;
use strict;
use warnings;
use English qw{-no_match_vars};
use Carp;
use base qw(npg_qc::model);

our $VERSION = do { my ($r) = q$Revision: 8943 $ =~ /(\d+)/mxs; $r; };

__PACKAGE__->mk_accessors(__PACKAGE__->fields());

sub fields {
  return qw(
            id_run_config
            id_run
            config_text
          );
}

sub init {
  my ($self) = @_;
  if ($self->id_run() &&
      !$self->id_run_config()) {
    my $query = q(SELECT id_run_config, config_text
                  FROM   run_config
                  WHERE  id_run = ?
                  ORDER BY id_run_config DESC);
    my $ref   = [];
    eval {
      $ref = $self->util->dbh->selectall_arrayref($query, {}, $self->id_run());
      1;
    } or do {
      carp $EVAL_ERROR;
      return;
    };
    if(@{$ref}) {
      $self->{id_run_config} = $ref->[0]->[0];
      $self->{config_text}   = $ref->[0]->[1];
    }
  }
  return 1;
}

sub run_configs {
  my $self = shift;
  return $self->gen_getall();
}

sub text_for_xml {
  my ($self) = @_;
  my $text = $self->config_text();
  $text =~ s/&/&amp;/gxms;
  $text =~ s/>/&gt;/gxms;
  return $text;
}

sub get_from_id_run {
  my ($self, $id_run) = @_;

  if (!$self->{get_from_id_run} || $self->{get_from_id_run}->id_run != $id_run) {

    $self->{get_from_id_run} = npg_qc::model::run_config->new({
      util   => $self->util,
      id_run => $id_run,
    });

  }

  return $self->{get_from_id_run};
}

1;
__END__
=head1 NAME

npg_qc::model::run_config

=head1 VERSION

$Revision: 8943 $

=head1 SYNOPSIS

  my $oRunConfig = npg_qc::model::run_config->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - return array of fields, first of which is the primary key

  my $aFields = $oRunConfig->fields();

=head2 init - on object creation, if provided with an id_run, but no id_run_config, attempts to find corresponding database entry, and populates object

=head2 run_configs - returns array of all run_config objects

  my $aRunConfigs = $oRunConfig->run_configs();

=head2 text_for_xml - returns $oRunConfig->config_text() with > and & replaced by &gt; and &amp; so the xml parses ok

  my $sTextForXML = $oRunConfig->text_for_xml();

=head2 get_from_id_run - returns an object where the id_run has been used to obtain the output

  my $oGetFromIdRun = $oRunConfig->get_from_id_run($id_run);

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

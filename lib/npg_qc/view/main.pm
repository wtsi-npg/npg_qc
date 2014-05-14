#########
# Author:        ajb
# Maintainer:    $Author: mg8 $
# Created:       2008-06-26
# Last Modified: $Date: 2012-04-02 10:00:34 +0100 (Mon, 02 Apr 2012) $
# Id:            $Id: main.pm 15413 2012-04-02 09:00:34Z mg8 $
# Source:        $Source: /repos/cvs/webcore/SHARED_docs/cgi-bin/docrep,v $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/view/main.pm $
#

package npg_qc::view::main;
use strict;
use warnings;
use base qw(npg_qc::view);
use English qw{-no_match_vars};
use Carp;
use npg_qc::model::main;

our $VERSION = do { my ($r) = q$Revision: 15413 $ =~ /(\d+)/mxs; $r; };

sub decor {
  my $self   = shift;
  my $aspect = $self->aspect() || q();

  if ($aspect eq 'graph')  {
    return 0;
  }

  return $self->SUPER::decor();
}

sub content_type {
  my $self   = shift;
  my $aspect = $self->aspect() || q();

  if ($aspect eq 'graph') {
    return 'image/png';
  }

  return $self->SUPER::content_type();
}

sub render {
  my ($self, @args) = @_;
  my $aspect = $self->aspect() || q();

  if ($aspect eq 'graph') {
    return $self->$aspect();
  }

  return $self->SUPER::render(@args);
}

sub list_display {
  my ($self) = @_;
  my $util = $self->util();
  my $cgi = $util->cgi();
  my $display = $cgi->param('display');
  my $id_run = $cgi->param('id_run');
  my $id_run_input = $cgi->param('id_run_input');

  my $model = $self->model();
  if($id_run_input ){
    my ($id_run_checked) = $id_run_input =~/(\d+)/xms;
    if($id_run_checked){
      $model->{id_run} = $id_run_checked;
    }else{
      croak "invalid input $id_run_input";
    }
  }else{

    $model->{id_run} = $id_run;
  }

  if ($display ne 'run_log') {
    my $run_config = npg_qc::model::run_config->new({util => $util, id_run => $model->{id_run}});
    if (!$run_config->id_run_config()) {
      my $id_run_pair = $model->id_run_pair();

      if($id_run_pair){
        $model->{id_run} = $id_run_pair;
      }
    }
  }

  $model->{title}  = $display eq 'summary'       ? 'Illumina Pipeline Summary'
                   : $display eq 'swift_summary' ? 'Swift Pipeline Summary'
                   : $display eq 'config_used'   ? 'Illumina Pipeline Configuration Settings'
                   : $display eq 'run_log'       ? 'Run Log View'
                   :                                q{}
                   ;
  $model->{display_type} = $display;
  if ($display eq 'config_used') {
    $model->{display} = $self->config_used($id_run);
  }

  return;
}

sub list_form_add_ajax {
  my ($self) = @_;
  return;
}

sub config_used {
  my ($self, $id_run) = @_;
  my $util = $self->util();
  my $config_model = npg_qc::model::run_config->new({
    util   => $util,
    id_run => $id_run,
  });
  return q{<pre>} . $config_model->config_text() . q{</pre>};
}

sub list_run_log {
  my ($self) = @_;
  return 1;
}

1;
__END__
=head1 NAME

npg_qc::view::main

=head1 VERSION

$Revision: 15413 $

=head1 SYNOPSIS

  my $oMainView = npg_qc::view::main->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 new - inherited from base class, sets up object, passing into it the arguments given, and determining user

=head2 authorised - inherited from base class, only showing analysis data, at this time all are authorised

=head2 decor - sets decor to 0 if aspect is graph, else default

=head2 content_type - sets content_type to image/png if aspect is graph, else default

=head2 render - renders view, determining the aspect to view

=head2 list_display - handles incoming request for run and required information

=head2 list_form_add_ajax - renders the default form via an ajax request

=head2 config_used - quick handling to display the Gerald config used to process the data

=head2 list_run_log - handles a selector form for selecting run_log data by an id_run

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

strict
warnings
npg_qc::view
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

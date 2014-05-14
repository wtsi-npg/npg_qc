#########
# Author:        ajb
# Maintainer:    $Author$
# Created:       2008-06-26
# Last Modified: $Date$
# Id:            $Id$
# Source:        $Source: /repos/cvs/webcore/SHARED_docs/cgi-bin/docrep,v $
# $HeadURL$
#

package npg_qc::model::main;
use strict;
use warnings;
use base qw(npg_qc::model);
use npg_qc::model::run_config;
use npg_qc::model::run_tile;
use npg_qc::model::run_log;
use English qw(-no_match_vars);
use Carp;

our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/mxs; $r; };

sub run_configs {
  my ($self) = @_;
  if (!$self->{run_configs}) {
    my $run_config = npg_qc::model::run_config->new({
      util => $self->util(),
    });
    $self->{run_configs} = $run_config->run_configs();
  }
  return $self->{run_configs};
}

sub id_runs {
  my ($self) = @_;
  if (!$self->{id_runs}) {
    my $run_tile_obj = npg_qc::model::run_tile->new({util => $self->util()});
    $self->{id_runs} = $run_tile_obj->runs();
  }
  return $self->{id_runs};
}


sub illumina_data_runs {
  my ($self) = @_;

  if (!$self->{illumina_data_runs}) {
    $self->{illumina_data_runs} = [];
    eval {
      my $query = q{
SELECT DISTINCT id_run
FROM cache_query
WHERE type = 'lane_summary'
AND is_current = 1
ORDER BY id_run DESC
                   };
      my $dbh = $self->util->dbh();
      my $id_runs = $dbh->selectall_arrayref($query);
      foreach my $id_run (@{$id_runs}) {
        push @{$self->{illumina_data_runs}}, $id_run->[0];
      }
      1;
    } or do {
      croak 'unable to obtain illumina_data_runs: ' . $EVAL_ERROR;
    };
  }
  return $self->{illumina_data_runs};
}

sub displays {
  my ($self) = @_;
  return qw(
      swift_summary
      summary
      config_used
      move_z
    );
}

sub runs_with_runlog_data {
  my ($self) = @_;
  if (!$self->{runs_with_runlog_data}) {
    my $object = npg_qc::model::run_log->new({ util => $self->util() });
    $self->{runs_with_runlog_data} = $object->runs_with_runlog_data();
  }
  return $self->{runs_with_runlog_data};
}

1;
__END__
=head1 NAME

npg_qc::model::main

=head1 VERSION

$Revision$

=head1 SYNOPSIS

  my $oMain = npg_qc::model::main->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 run_configs - returns an arrayref of run_configs

  my $aRunConfigs = $oMain->run_configs();

=head2 id_runs - returns an arrayref of id_runs from the run_tile table

  my $aIdRuns = $oMain->id_runs();

=head2 displays - returns an array of the displays that we can show

  my @Displays = $oMain->displays();

=head2 runs_with_runlog_data - returns arrayref of id_runs that have run_log data

  my $aRunsWithRunLogData = $oMain->runs_with_runlog_data();

=head2 illumina_data_runs - returns arrayref of id_runs which have a run_config associated

  my $aIlluminaDataRuns = $oMain->illumina_data_runs();

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

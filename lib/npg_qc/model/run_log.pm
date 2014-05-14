#########
# Author:        ajb
# Maintainer:    $Author: jo3 $
# Created:       2008-09-25
# Last Modified: $Date: 2010-03-30 16:40:28 +0100 (Tue, 30 Mar 2010) $
# Id:            $Id: run_log.pm 8943 2010-03-30 15:40:28Z jo3 $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/model/run_log.pm $
#

package npg_qc::model::run_log;
use strict;
use warnings;
use base qw(npg_qc::model);
use Carp;
use English qw(-no_match_vars);
use Readonly;

our $VERSION = do { my ($r) = q$Revision: 8943 $ =~ /(\d+)/mxs; $r; };

__PACKAGE__->mk_accessors(fields());

sub fields {
  return qw(id_run);
}

sub runs_with_runlog_data{
  my ($self) = @_;

  my $util   = $self->util();

  my $run_list = [];
  if(!$self->{runs_with_run_log_data}){
    eval {
      my $dbh = $self->util->dbh();
      my $query  = q{SELECT DISTINCT id_run 
                     FROM cache_query
                     WHERE type='movez_tiles'
                     ORDER BY id_run DESC
                     };

      my $sth = $dbh->prepare($query);
      $sth->execute();

      while (my @row = $sth->fetchrow_array()) {
	     push @{$run_list}, $row[0];
      }

      1;
    } or do {
      croak $EVAL_ERROR;
    };
    $self->{runs_with_runlog_data} = $run_list;
  }

  return $self->{runs_with_runlog_data};
}

sub metrics {
  my ($self) = @_;
  return [
    { module => 'move_z', title => 'Move Z Information', }
  ];
}


1;
__END__
=head1 NAME

npg_qc::model::run_log

=head1 VERSION

$Revision: 8943 $

=head1 SYNOPSIS

  my $oRunLog = npg_qc::model::run_log->new({util => $util});

=head1 DESCRIPTION

Base model to sit under npg_qc::view::run_log

=head1 SUBROUTINES/METHODS

=head2 fields - returns list of fields to be populated as accessors

=head2 metrics - returns an arrayref containing hashes of the different run_log metrics available, for use in constructing links

  my $aMetrics = $oRunLog->metrics();

=head2 runs_with_runlog_data - returns arrayref of id_runs which have run_log data

  my $aRunsWithRunlogData = $oRunLog->runs_with_runlog_data();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

strict
warnings
npg_qc::model
English
Carp
Statistics::Lite
Readonly

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

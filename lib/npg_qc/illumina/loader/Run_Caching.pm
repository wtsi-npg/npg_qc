#########
# Author:        gq1
# Created:       2008-09-30
#
package npg_qc::illumina::loader::Run_Caching;

use Moose;
use Carp;
use English qw{-no_match_vars};
use npg_qc::util;
use npg_qc::model::run_graph;
use npg_qc::model::cache_query;

extends 'npg_qc::illumina::loader::base';

our $VERSION = '0';

has 'npg_qc_util' =>  (isa => q{npg_qc::util},
                       is => q{ro},
                       lazy_build => 1,
                      );
sub _build_npg_qc_util {
  my $self = shift;
  ##no critic (Subroutines::ProtectPrivateSubs)
  return npg_qc::util->new({ configpath => $self->schema->_config_file,});
}

sub cache_run {
  my ($self, $id_run, $is_paired_read) = @_;
  if (!$id_run) {
    croak __PACKAGE__ . '->cache_run needs id_run';
  }
  my $to_update = 1;
  my @ends = qw/1/;
  if ($is_paired_read) {push @ends, 2;}
  foreach my $end ( @ends ) {
    $self->cache_query_lane_summary($id_run, $end, $to_update);
    $self->run_graph($id_run, $end);
    $self->instrument_statistics($id_run, $end);
  }
  return;
}

sub run_all{
  my ($self) = @_;

  eval{
    $self->cache_query_lane_summary();
    1;
  } or do{
    _log("cache_query_lane_summary error: $EVAL_ERROR");
  };

  eval{
    $self->run_graph();
    1;
  } or do{
    _log("run_graph error: $EVAL_ERROR");
  };

  eval{
    $self->instrument_statistics();
    1;
  } or do{
    _log("instrument_statistics error: $EVAL_ERROR");
  };

  return;
}

sub run_graph{
  my ($self, $id_run, $end) = @_;
  if ($id_run) {
    npg_qc::model::run_graph->new({util => $self->npg_qc_util,})->calculate_one_run($id_run, $end);
  } else {
    my $num_runs_done = npg_qc::model::run_graph->new({util => $self->npg_qc_util,})->calculate_all();
    _log("Success: $num_runs_done runs done for run_graph");
  }
  return;
}

sub instrument_statistics{
  my ($self, $id_run, $end) = @_;
  if($id_run){
    npg_qc::model::instrument_statistics->new({
				  util   => $self->npg_qc_util,
				  id_run => $id_run,
				  end    => $end,
			                      })->get_all_field_from_db();
    _log("Success: run($id_run $end) done for instrument_statistics");
  } else {
    my $num_runs_done = npg_qc::model::instrument_statistics->new({util => $self->npg_qc_util,})->calculate_all();
    _log("Success: $num_runs_done runs done for instrument statistics");
  }
  return;
}

sub cache_query_lane_summary{
  my ($self, $id_run, $end, $to_update) = @_;

  if($id_run){
    my $cache_query = npg_qc::model::cache_query->new({
                           util   => $self->npg_qc_util,
                           id_run => $id_run,
                           end    => $end,
                           type   => 'lane_summary',
                                                     });

    if($to_update) {
      $cache_query->update_current_cache();
      _log("Success: cache updated for $id_run end $end");
    }else{
      $cache_query->cache_new_copy_data();
      _log("Success: cache created for $id_run end $end");
    }
  } else {
    my $nums_done = npg_qc::model::cache_query->new({util => $self->npg_qc_util,})->cache_lane_summary_all();
    _log("Success: $nums_done runs done for lane summary");
  }
  return;
}

sub _log {
  my ($m) = shift;
  warn "$m\n";
  return;
}

1;
__END__

=head1 NAME

npg_qc::illumina::loader::Run_Caching

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 cache_list_query_lane_summary - given a list of id_runs, cache each pair of runs for lane summary

=head2 cache_list_query_run_graph - given a list of id_runs, cache each pair of runs for run graph data

=head2 run_graph - send an xml request to the server to run all available run_graph calculate

=head2 cache_query_lane_summary

=head2 run_all

=head2 cache_run

=head2 log - logging routine

=head2 instrument_statistics

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

strict
warnings
Carp
English

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Andy Brown, E<lt>gq1@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Guoying Qi

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut

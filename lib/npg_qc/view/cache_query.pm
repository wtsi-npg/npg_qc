#########
# Author:        ajb
# Maintainer:    $Author$
# Created:       2008-09-26
# Last Modified: $Date$
# Id:            $Id$
# Source:        $Source: /repos/cvs/webcore/SHARED_docs/cgi-bin/docrep,v $
# $HeadURL$
#

package npg_qc::view::cache_query;
use strict;
use warnings;
use base qw(npg_qc::view);
use English qw{-no_match_vars};
use Carp qw(confess cluck carp croak);
use Readonly;
use npg_qc::model::cache_query;
use npg_qc::model::run_graph;
use npg_qc::model::instrument_statistics;

our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/mxs; $r; };

sub posted_content_type {
  my ($self) = @_;

  if (!$self->{posted_content_type}) {
    my $cgi = $self->util->cgi();
    my $pct = $cgi->param('POSTDATA');
    if (!$pct) {
      $pct = $cgi->param('XForms:Model');
    }
    $self->{posted_content_type} = !$pct                                                    ? 'form_data'
                                 : $pct =~ /<[?]xml[ ]version="1[.]0"[ ]encoding="utf-8"[?]>/xms ? 'xml'
                                 :                                                            'form_data'
                                 ;
  }

  return $self->{posted_content_type};
}

sub decor {
  my ($self, @args) = @_;

  if($self->posted_content_type() eq 'xml') {
    return 0;
  }

  return $self->SUPER::decor(@args);
}

sub content_type {
  my ($self, @args) = @_;

  if($self->posted_content_type() eq 'xml') {
    return 'application/xml';
  }

  return $self->SUPER::content_type(@args);
}

sub render {
  my ($self, @args) = @_;

  if($self->posted_content_type() eq 'xml') {
    return $self->create();
  }

  return $self->SUPER::render(@args);
}

sub create {
  my ($self)  = @_;

  my $util    = $self->util();
  my $cgi     = $util->cgi();

  my $content = $cgi->param('POSTDATA');

  if (!$content) {
    $content = $cgi->param('XForms:Model');
  }

  my $parser = $util->parser();

  my $parsed_xml;

  eval {
    $parsed_xml = $parser->parse_string($content);
    1;
  } or do {
    croak 'Not well formed xml';
  };

  my $method = $parsed_xml->getElementsByTagName('method');
  $method = lc$method;

  eval {
    $self->allowed_methods($method);
    1;
  } or do {
    croak $EVAL_ERROR;
  };

  my $id_run = $parsed_xml->getElementsByTagName('id_run');

  if ($id_run) {
    my $to_update = $id_run->[0]->getAttribute('update');
    my $end = $id_run->[0]->getAttribute('end');

    return $self->cache_one_run({id_run => $id_run, method => $method, end => $end, to_update => $to_update});
  }

  if($method eq 'cache_query_movez_tiles'){
    return $self->all_runs_movez_tiles();
  }

  if($method eq 'cache_query_lane_summary'){
    return $self->all_runs_lane_summary();
  }

  if($method eq 'cache_query'){
    return $self->all_runs();
  }
  return;
}

sub allowed_methods {
  my ($self, $method) = @_;

  my $allowed_methods = {
    cache_query_movez_tiles  => 1,
    cache_query_lane_summary => 1,
    cache_query              => 1,
  };

  if (!$allowed_methods->{$method}) {
    croak "This method ($method) is not allowed to be stored";
  }

  return 1;
}

sub response_object {
  my ($self, $response) = @_;

  return qq{<?xml version="1.0" encoding="utf-8"?><response>$response</response>};
}

sub cache_one_run{
  my ($self, $arg_refs) = @_;

  my $id_run = $arg_refs->{id_run};
  my $method= $arg_refs->{method};
  my $end = $arg_refs->{end};
  my $to_update = $arg_refs->{to_update};
  my $from_web = $arg_refs->{from_web};

  if(!$end){
    $end = 1;
  }

  if(!$to_update){
    $to_update = 'no';
  }
  my $response;
  eval{

    if($method eq 'cache_query_movez_tiles'){
      $self->cache_movez_tiles_one($id_run, $end, $to_update);
    }elsif($method eq 'cache_query_lane_summary'){
      $self->cache_lane_summary_one($id_run, $end, $to_update);
    }elsif($method eq 'cache_query'){
      $self->cache_lane_summary_one($id_run, $end, $to_update);
      $self->cache_movez_tiles_one($id_run, $to_update)
    }
    $response .= "success: $method, $id_run, $end, update($to_update)";
    1;
  } or do{
    if ($from_web) {
      croak "fail: $EVAL_ERROR";
    }
    $response = "fail: $EVAL_ERROR";
  };
  if ($from_web) {
    return 1;
  }

  return $self->response_object($response);
}

sub cache_lane_summary_one{
  my ($self, $id_run, $end, $to_update) = @_;
  my $util   = $self->util();

  eval{
     my $cache_query = npg_qc::model::cache_query->new({
                           util   => $util,
                           id_run => $id_run,
                           end    => $end,
                           type   => 'lane_summary',
                     });

     if($to_update && $to_update eq 'yes'){
       $cache_query->update_current_cache();
     }else{
       $cache_query->cache_new_copy_data();
     }

     1;
  }or do{
    croak $EVAL_ERROR;
  };
  return 1;
}

sub cache_movez_tiles_one{
  my ($self, $id_run, $end, $to_update) = @_;
  my $util   = $self->util();

  eval{
     my $cache_query = npg_qc::model::cache_query->new({
                           util   => $util,
                           id_run => $id_run,
                           end    => $end,
                           type   => 'movez_tiles',
                     });

     if($to_update && $to_update eq 'yes'){
       $cache_query->update_current_cache();
     }else{
       $cache_query->cache_new_copy_data();
     }

     1;
  }or do{
    croak $EVAL_ERROR;
  };
  return 1;
}

sub all_runs{
  my ($self, $from_web) = @_;

  my $model = $self->model();
  my $response;
  eval{
    my $nums_done = $model->cache_movez_tiles_all();
    $response = "success: $nums_done runs done for movez tiles";
    1;
  }or do{
    $response = "fail: $EVAL_ERROR";
  };
  eval{
    my $nums_done = $model->cache_lane_summary_all();
    $response .= ", success: $nums_done runs done for lane summary";
    1;
  }or do{
    $response .= " fail: $EVAL_ERROR";
  };
  if ($from_web) {
    if ($response =~ /fail/xms) {
      croak $response;
    }
    return $response;
  }
  return $self->response_object($response);
}

sub all_runs_movez_tiles {
  my ($self) = @_;
  my $model = $self->model();
  my $response;
  eval{
    my $nums_done = $model->cache_movez_tiles_all();
    $response = "success: $nums_done runs done for movez tiles";
    1;
  }or do{
    $response = "fail: $EVAL_ERROR";
  };
  return $self->response_object($response);
}

sub all_runs_lane_summary {
  my ($self) = @_;
  my $model = $self->model();
  my $response;
  eval{
    my $nums_done = $model->cache_lane_summary_all();

    $response = "success: $nums_done runs done for lane summary";
    1;
  }or do{
    $response = "fail: $EVAL_ERROR";
  };
  return $self->response_object($response);
}

sub manual_cache_all {
  my ($self, $run_graph_model, $instrument_statistics_model) = @_;
  my $util   = $self->util();
  my $model  = $self->model();

  eval {

    $model->{number_of_run_graph_datasets_cached} = $run_graph_model->calculate_all();
    $model->{number_of_run_graph_datasets_cached} .= q{ success for run graph data};

    $model->{number_of_instrument_datasets_cached} = $instrument_statistics_model->calculate_all();
    $model->{number_of_instrument_datasets_cached} .= q{ success for instrument statistics};

    $model->{all_runs_response} = $self->all_runs(1);
    1;

  } or do {

    croak 'Problem with All Runs/Datasets Cache: ' . $EVAL_ERROR;

  };

  return 1;
}

sub create_manual_cache {
  my ($self) = @_;

  my $util   = $self->util();
  my $cgi    = $util->cgi();
  my $model  = $self->model();

  my $run_graph_model = npg_qc::model::run_graph->new({util => $util});
  my $instrument_statistics_model = npg_qc::model::instrument_statistics->new({util => $util});

  my $all_or_one      = $cgi->param('all_or_one');

  if ($all_or_one eq 'all') {
    $self->manual_cache_all($run_graph_model, $instrument_statistics_model);
  } else {

    my $id_run = $cgi->param('id_run');
    ($id_run)  = $id_run =~ /(\d+)/xms;
    if (!$id_run) {
      croak 'no id_run provided';
    }

    my $ends    = $cgi->param('end');
    $ends = $ends eq 'both' ? [1,2]
          :                   [$ends]
          ;

    my $to_update = $cgi->param('update') || 'no';

    my @caches = $cgi->param('caches');
    my $caches_reqd;
    foreach my $method (@caches) {
      $caches_reqd->{$method}++;
    }
    my $id_run_pair = $self->model->id_run_pair($id_run);

    if (!$id_run_pair || $id_run == $id_run_pair) {
      $ends = [$ends->[0]];
      if ($ends->[0] == 2) {
        croak q{This is a single ended run, so you can not run anything on read 2};
      }
    }

    if ($id_run_pair && $id_run_pair < $id_run) {
      my $temp = $id_run_pair;
      $id_run_pair = $id_run;
      $id_run = $temp;
    }

    my $rs_runs_done;
    my $mz_runs_done;

    foreach my $end (@{$ends}) {

      if ($caches_reqd->{run_summary}) {
        $self->cache_one_run({id_run => $id_run, method => 'cache_query_lane_summary', end => $end, to_update => $to_update, from_web => 1});
        $rs_runs_done++;
      }

      if ($caches_reqd->{run_graph}) {
        $run_graph_model->calculate_one_run($id_run, $end);
	     $model->{number_of_run_graph_datasets_cached}++;
      }

      if ($caches_reqd->{instrument_sta}) {
        $self->one_run_instrument_statistics($id_run, $end);
	     $model->{number_of_instrument_datasets_cached}++;
      }

      if ($caches_reqd->{move_z}) {
        $self->one_run_cache_query_movez_tiles($id_run, $end, $id_run_pair, $to_update);
	     $mz_runs_done++;
      }

    }

    $model->{all_runs_response} = q{};
    if ($rs_runs_done) {
      $model->{all_runs_response} .= qq{success: $rs_runs_done runs done for lane summary<br />};
    }
    if ($mz_runs_done) {
      $model->{all_runs_response} .= qq{success: $mz_runs_done runs done for movez tiles<br />};
    }

    $model->{used_id_run_r1} = $id_run;
    $model->{used_id_run_r2} = $id_run_pair;

  }

  return 1;
}

sub one_run_instrument_statistics{
  my ($self, $id_run, $end) = @_;
  my $util   = $self->util();
  my $instrument_statistics_model2 = npg_qc::model::instrument_statistics->new({
				                            util => $util,
				                            id_run => $id_run,
				                            end    => $end,
			                    });
  $instrument_statistics_model2->get_all_field_from_db();

  return 1;
}
sub one_run_cache_query_movez_tiles{
    my ($self, $id_run, $end, $id_run_pair, $to_update) = @_;
    if ($end == 1) {
      $self->cache_one_run({id_run => $id_run, method => 'cache_query_movez_tiles', to_update => $to_update, from_web => 1});
    } else {
	  $self->cache_one_run({id_run => $id_run_pair, method => 'cache_query_movez_tiles', to_update => $to_update, from_web => 1});
	}
	return 1;
}
1;
__END__
=head1 NAME

npg_qc::view::cache_query

=head1 VERSION

$Revision$

=head1 SYNOPSIS

  my $o = npg_qc::view::cache_query->new({util => $util});

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 decor - sets decor to 0, as only job is to process and respond with xml

=head2 posted_content_type - checks the posted content type in order to try and determine if it is xml (by xml standard header)

=head2 content_type - sets content_type to 'application/xml'

=head2 render - renders view

=head2 create - overall handler to obtain xml and determine what to do with it

=head2 allowed_methods - returns true if xml requested method is ok

=head2 response_object - returns an xml response object with information in it

=head2 all_runs_lane_summary - handler to run the cache_query stuff for all runs in the database which need them

=head2 all_runs_movez_tiles - handler to run the cache_query stuff for all runs in the database which need them

=head2 one_run_instrument_statistics

=head2 one_run_cache_query_movez_tiles

=head2 all_runs - handler to run the cache_query stuff for all runs in the database which need them

=head2 cache_one_run - handler to run the cache_query stuff for a single run, regenerating if they already exist

=head2 cache_lane_summary_one - given id_run and update or cache another copy, to cache lane_summary and cycle_count 

=head2 cache_movez_tiles_one - given id_run and update or cache another copy, to cache movez_tiles

=head2 create_manual_cache - handler to set of caching manually via a web page

=head2 manual_cache_all - refactor some for create_manual_cache

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

strict
warnings
npg_qc::view

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

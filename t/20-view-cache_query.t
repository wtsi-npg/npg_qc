#########
# Author:        ajb
# Maintainer:    $Author$
# Created:       2008-06-16
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

use strict;
use warnings;
use Test::More tests => 33;
use English qw(-no_match_vars);
use IO::Scalar;
use t::util;
use npg_qc::model::cache_query;

our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/mx; $r; };

use_ok('npg_qc::view::cache_query');


$ENV{NPG_WEBSERVICE_CACHE_DIR} = q[t/data/qc_webcache];

my $util = t::util->new({fixtures => 1});

my $without_id_run = $util->rendered('t/data/rendered/cache_query_without_id_run.xml');
my $without_id_run_movez_tiles = $util->rendered('t/data/rendered/cache_query_without_id_run_movez_tiles.xml');
my $without_id_run_lane_summary = $util->rendered('t/data/rendered/cache_query_without_id_run_lane_summary.xml');
my $badly_formed_xml   = $util->rendered('t/data/rendered/cache_query_badly_formed_xml.xml');
my $not_allowed_method = $util->rendered('t/data/rendered/cache_query_not_allowed_method.xml');


my $model = npg_qc::model::cache_query->new({util => $util});

##
{
  my $cgi = $util->cgi();
  $cgi->param('XForms:Model', $badly_formed_xml);
  my $view = npg_qc::view::cache_query->new({
    util => $util,
    model => $model,
  });
  isa_ok($view, 'npg_qc::view::cache_query', '$view');

  is($view->decor(), 0, '$view->decor() returns 0');
  is($view->content_type(), 'application/xml', '$view->content_type() is application/xml');
  my $render;
  eval { $render = $view->render(); };
  like($EVAL_ERROR, qr{Not\ well\ formed\ xml}, 'croaks - Not well formed xml');
}
##
{
  my $cgi = $util->cgi();
  $cgi->param('XForms:Model', $not_allowed_method);
  my $view = npg_qc::view::cache_query->new({
    util => $util,
    model => $model,
  });
  isa_ok($view, 'npg_qc::view::cache_query', '$view');

  is($view->decor(), 0, '$view->decor() returns 0');
  is($view->content_type(), 'application/xml', '$view->content_type() is application/xml');
  my $render;
  eval { $render = $view->render(); };
  like($EVAL_ERROR, qr{This\ method\ \(not_allowed_method\)\ is\ not\ allowed\ to\ be\ stored}, 'croaks - This method (not_allowed_method) is not allowed to be stored');
}

##
{
  my $cgi = $util->cgi();
  $cgi->param('XForms:Model', $without_id_run_lane_summary);
  my $view = npg_qc::view::cache_query->new({
    util => $util,
    model => $model,
  });
  isa_ok($view, 'npg_qc::view::cache_query', '$view');

  is($view->decor(), 0, '$view->decor() returns 0');
  is($view->content_type(), 'application/xml', '$view->content_type() is application/xml');
  my $render;
  eval { $render = $view->render(); };
  is($EVAL_ERROR, q{}, 'no croak on render for caching lane summary without id_run');
}
##
{
  my $cgi = $util->cgi();
  $cgi->param('XForms:Model', $without_id_run_movez_tiles);
  my $view = npg_qc::view::cache_query->new({
    util => $util,
    model => $model,
  });
  isa_ok($view, 'npg_qc::view::cache_query', '$view');

  is($view->decor(), 0, '$view->decor() returns 0');
  is($view->content_type(), 'application/xml', '$view->content_type() is application/xml');
  my $render;
  eval { $render = $view->render(); };
  is($EVAL_ERROR, q{}, 'no croak on render for movez_tiles without id_run');
}

##
{
  my $cgi = $util->cgi();
  $cgi->param('XForms:Model', $without_id_run);
  my $view = npg_qc::view::cache_query->new({
    util => $util,
    model => $model,
  });
  isa_ok($view, 'npg_qc::view::cache_query', '$view');

  is($view->decor(), 0, '$view->decor() returns 0');
  is($view->content_type(), 'application/xml', '$view->content_type() is application/xml');
  my $render;
  eval { $render = $view->render(); };
  is($EVAL_ERROR, q{}, 'no croak on render for both without id_run');
}

##
{
  my $with_id_run_movez    = $util->rendered('t/data/rendered/cache_query_with_id_run_movez.xml');
  my $cgi = $util->cgi();
  $cgi->param('XForms:Model', $with_id_run_movez);
  my $view = npg_qc::view::cache_query->new({
    util => $util,
    model => $model,
  });
  isa_ok($view, 'npg_qc::view::cache_query', '$view');

  is($view->decor(), 0, '$view->decor() returns 0');
  is($view->content_type(), 'application/xml', '$view->content_type() is application/xml');
  my $render;
  eval { $render = $view->render(); 
  print $render, "\n";
  };
  is($EVAL_ERROR, q{}, 'no croak on render with id_run movez');
}

##
{
  my $with_id_run_lane_summary    = $util->rendered('t/data/rendered/cache_query_with_id_run_lane_summary.xml');
  my $cgi = $util->cgi();
  $cgi->param('XForms:Model',$with_id_run_lane_summary);
  my $view = npg_qc::view::cache_query->new({
    util => $util,
    model => $model,
  });
  isa_ok($view, 'npg_qc::view::cache_query', '$view');

  is($view->decor(), 0, '$view->decor() returns 0');
  is($view->content_type(), 'application/xml', '$view->content_type() is application/xml');
  my $render;
  eval { $render = $view->render();
    print $render, "\n";
  };
  is($EVAL_ERROR, q{}, 'no croak on render with id_run lane summary');
}


##
{
  my $with_id_run    = $util->rendered('t/data/rendered/cache_query_with_id_run.xml');
  my $cgi = $util->cgi();
  $cgi->param('XForms:Model',$with_id_run);
  my $view = npg_qc::view::cache_query->new({
    util => $util,
    model => $model,
  });
  isa_ok($view, 'npg_qc::view::cache_query', '$view');

  is($view->decor(), 0, '$view->decor() returns 0');
  is($view->content_type(), 'application/xml', '$view->content_type() is application/xml');
  my $render;
  eval { $render = $view->render();
    #print $render, "\n";
  };
  is($EVAL_ERROR, q{}, 'no croak on render with id_run lane summary');
}
1;

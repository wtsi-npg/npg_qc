#########
# Author:        gq1
# Created:       2008-06-16
#

use strict;
use warnings;
use Test::More tests => 33;
use English qw(-no_match_vars);
use t::util;
use npg_qc::model::run_graph;

###
use_ok('npg_qc::view::run_graph');

my $util = t::util->new({fixtures => 1});

my $with_id_run    = $util->rendered('t/data/rendered/run_graph_with_id_run.xml');
my $without_id_run = $util->rendered('t/data/rendered/run_graph_without_id_run.xml');
my $badly_formed_xml   = $util->rendered('t/data/rendered/run_graph_badly_formed.xml');
my $not_allowed_method = $util->rendered('t/data/rendered/run_graph_not_allowed_method.xml');

my $model = npg_qc::model::run_graph->new({util => $util});
###
{
  my $cgi = $util->cgi();
  $cgi->param('XForms:Model', $badly_formed_xml);
  my $view = npg_qc::view::run_graph->new({
    util => $util,
    model => $model,
    aspect=>'create_xml',
  });

  isa_ok($view, 'npg_qc::view::run_graph', '$view');

  is($view->decor(), 0, '$view->decor() returns 0');

  is($view->content_type(), 'application/xml', '$view->content_type() is application/xml');

  my $render;
  eval {
    $render = $view->render();
    1;
  } or do{
    print "$EVAL_ERROR\n";
  };
  like($EVAL_ERROR, qr{Not\ well\ formed\ xml}, 'croaks - Not well formed xml');
}
###
{
  my $cgi = $util->cgi();
  $cgi->param('XForms:Model', $not_allowed_method);
  my $view = npg_qc::view::run_graph->new({
    util => $util,
    model => $model,
    aspect=>'create_xml',
  });

  isa_ok($view, 'npg_qc::view::run_graph', '$view');

  is($view->decor(), 0, '$view->decor() returns 0');

  is($view->content_type(), 'application/xml', '$view->content_type() is application/xml');

  my $render;
  eval {
    $render = $view->render();
    print "$render\n";
    1;
  } or do{
    print "$EVAL_ERROR\n";
  };
  like($EVAL_ERROR, qr{This\ method\ \(not_allowed_method\)\ is\ not\ allowed}, 'croaks - This method (not_allowed_method) is not allowed');
}

###
{
  my $cgi = $util->cgi();
  $cgi->param('XForms:Model', $with_id_run);
  my $view = npg_qc::view::run_graph->new({
    util => $util,
    model => $model,
    aspect=>'create_xml',
  });

  isa_ok($view, 'npg_qc::view::run_graph', '$view');

  is($view->decor(), 0, '$view->decor() returns 0');

  is($view->content_type(), 'application/xml', '$view->content_type() is application/xml');

  my $render;
  eval {
    $render = $view->render();
    print "$render\n"; 
    1;
  } or do{
    print "$EVAL_ERROR\n";
  };
  is($EVAL_ERROR, q{}, 'no croak on render with id_run');
}
###
{
  my $cgi = $util->cgi();
  $cgi->param('XForms:Model', $without_id_run);
  my $view = npg_qc::view::run_graph->new({
    util => $util,
    model => $model,
    aspect=>'create_xml',
  });

  isa_ok($view, 'npg_qc::view::run_graph', '$view');

  is($view->decor(), 0, '$view->decor() returns 0');

  is($view->content_type(), 'application/xml', '$view->content_type() is application/xml');

  my $render;
  eval {
    $render = $view->render();
    print "$render\n";
    1;
  } or do{
    print "$EVAL_ERROR\n";
  };
  is($EVAL_ERROR, q{}, 'no croak on render without id_run');
}


###
{
  my $view = npg_qc::view::run_graph->new({
    util => $util,
    model => $model,
    aspect=>'list_yield_by_run_png',
  });

  isa_ok($view, 'npg_qc::view::run_graph', '$view');

  is($view->decor(), 0, '$view->decor() returns 0');

  is($view->content_type(), 'image/png', '$view->content_type() is image/png');

  my $render;
  eval {
    $view->list_yield_by_run_png();
    1;
  } or do{
    print "$EVAL_ERROR\n";
  };
  is($EVAL_ERROR, q{}, 'no croak on list_yield_by_run_png');
}

###
{
  my $view = npg_qc::view::run_graph->new({
    util => $util,
    model => $model,
    aspect =>'list_error_by_run_png',
  });

  isa_ok($view, 'npg_qc::view::run_graph', '$view');

  is($view->decor(), 0, '$view->decor() returns 0');

  is($view->content_type(), 'image/png', '$view->content_type() is image/png');

  my $render;
  eval {
    $view->list_error_by_run_png();
    1;
  } or do{
    print "$EVAL_ERROR\n";
  };
  is($EVAL_ERROR, q{}, 'no croak on list_error_by_run_png');
}

###
{
  my $view = npg_qc::view::run_graph->new({
    util => $util,
    model => $model,
    aspect => 'list_cluster_per_tile_by_run_png'
  });
  
  isa_ok($view, 'npg_qc::view::run_graph', '$view');

  is($view->decor(), 0, '$view->decor() returns 0');

  is($view->content_type(), 'image/png', '$view->content_type() is image/png');
  
  my $render;
  eval {
    $view->list_cluster_per_tile_by_run_png ();
    1;
  } or do{
    print "$EVAL_ERROR\n";
  };
  is($EVAL_ERROR, q{}, 'no croak on list_cluster_per_tile_by_run_png ');
}

###
{
  my $view = npg_qc::view::run_graph->new({
    util => $util,
    model => $model,
    aspect => 'list_cluster_per_tile_by_run_control_png',
  });
  isa_ok($view, 'npg_qc::view::run_graph', '$view');

  is($view->decor(), 0, '$view->decor() returns 0');

  is($view->content_type(), 'image/png', '$view->content_type() is image/png');
  
  my $render;
  eval {
    $view->list_cluster_per_tile_by_run_control_png();
    1;
  } or do{
    print "$EVAL_ERROR\n";
  };
  is($EVAL_ERROR, q{}, 'no croak on list_cluster_per_tile_by_run_control_png');
}
1;

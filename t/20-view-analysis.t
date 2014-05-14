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
use Test::More tests => 8;
use English qw(-no_match_vars);
use IO::Scalar;
use t::util;

our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/mx; $r; };

use_ok('npg_qc::model::analysis');


use_ok('npg_qc::view::analysis');
my $util = t::util->new({fixtures => 1});

my $model = npg_qc::model::analysis->new({
  util => $util,
});

can_ok($model, 'analysis_lanes');

my $analysis_request_xml = $util->rendered('t/data/rendered/analysis_request.xml');

{
  my $cgi = $util->cgi();
  $cgi->param('XForms:Model', $analysis_request_xml);
  my $view = npg_qc::view::analysis->new({
      util => $util,
      model => $model,
      action => q{list},
      aspect => q{list_xml},
    });
  isa_ok($view, 'npg_qc::view::analysis', '$view');

  is($view->decor(), 0, '$view->decor() returns 0');
  is($view->content_type(), 'application/xml', '$view->content_type() is application/xml');
  my $render;
  eval{ $render = $view->render(); };
  is($EVAL_ERROR, q{}, 'no croak on $view->render() for $analysis_request_xml');
  ok($util->test_rendered($render, 't/data/rendered/analysis.xml'), 'render is ok');
}

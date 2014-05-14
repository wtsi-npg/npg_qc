#########
# Author:        ajb
# Maintainer:    $Author$
# Created:       2008-07-22
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
use npg_qc::model::summary;

our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/mx; $r; };

use_ok('npg_qc::view::summary');

$ENV{NPG_WEBSERVICE_CACHE_DIR} = q[t/data/qc_webcache];

my $util  = t::util->new({fixtures => 1});
{
  my $cgi = $util->cgi();
  $cgi->param('id_run', 1);

  my $model = npg_qc::model::summary->new({util => $util});

  my $view  = npg_qc::view::summary->new({
    util   => $util,
    model  => $model,
    action => 'add',
    aspect => 'add_ajax',
  });
  isa_ok($view, 'npg_qc::view::summary', '$view');

  my $render;
  eval { $render = $view->render(); };
  is($EVAL_ERROR, q{}, 'no croak on render add_ajax');

  ok($util->test_rendered($render, 't/data/rendered/html/summary_add_ajax.html'), 'add_ajax rendered ok');
}
{
  my $model = npg_qc::model::summary->new({util => $util});

  my $view  = npg_qc::view::summary->new({
    util   => $util,
    model  => $model,
    action => 'list',
    aspect => 'list_xml',
  });

  my $render;
  eval { $render = $view->render(); };
  is($EVAL_ERROR, q{}, 'no croak on render list_xml');
  ok($util->test_rendered($render, 't/data/rendered/summary_list_xml.xml'), 'list_xml rendered ok');
}
{
  my $model = npg_qc::model::summary->new({util => $util, id_run => 3});

  my $view  = npg_qc::view::summary->new({
    util   => $util,
    model  => $model,
    action => 'read',
    aspect => 'read',
  });

  my $render;
  eval { $render = $view->render(); };
  is($EVAL_ERROR, q{}, 'no croak on render read');
  ok($util->test_rendered($render, 't/data/rendered/html/summary_read.html'), 'read rendered ok');
}

1;

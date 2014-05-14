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
use Test::More tests => 7;
use English qw(-no_match_vars);
use IO::Scalar;
use t::util;
use Carp;
use npg_qc::model::cumulative_errors_by_cycle;

our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/mx; $r; };

use_ok('npg_qc::view::cumulative_errors_by_cycle');

$ENV{NPG_WEBSERVICE_CACHE_DIR} = q[t/data/qc_webcache];

my $util  = t::util->new({fixtures => 1});
{
  my $cgi = $util->cgi();
  $cgi->param('id_run', 1);

  my $model = npg_qc::model::cumulative_errors_by_cycle->new({util => $util});

  my $view  = npg_qc::view::cumulative_errors_by_cycle->new({
    util   => $util,
    model  => $model,
    action => 'list',
    aspect => q{},
  });
  isa_ok($view, 'npg_qc::view::cumulative_errors_by_cycle', '$view');

  my $render;
  eval { $render = $view->render(); };
  is($EVAL_ERROR, q{}, 'no croak on render list');
  ok($util->test_rendered($render, 't/data/rendered/html/cumulative_errors_by_cycle_list.html'), 'list rendered ok');
}
{
  my $cgi = $util->cgi();
  $cgi->param('tile_ref', '1_1_1');
  $cgi->param('score', 'score');

  my $model = npg_qc::model::cumulative_errors_by_cycle->new({util => $util});

  my $view  = npg_qc::view::cumulative_errors_by_cycle->new({
    util   => $util,
    model  => $model,
    action => q{read},
    aspect => q{read_png},
  });

  my $render;
  is($view->authorised, 1, 'all are authorised');
  is($view->decor(), 0, 'decor is 0 for read_png');
  is($view->content_type(), 'image/png', 'content_type is image/png for read_png');
}

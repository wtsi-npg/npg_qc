#########
# Author:        ajb
# Created:       2008-06-16
#

use strict;
use warnings;
use Test::More 'no_plan';#tests => 36;
use English qw(-no_match_vars);
use IO::Scalar;
use t::util;
use npg_qc::model::main;

use_ok('npg_qc::view::main');
my $util = t::util->new({fixtures => 1});

my $model = npg_qc::model::main->new({util => $util});
{
  my $view = npg_qc::view::main->new({
    util   => $util,
    model  => $model,
    action => q{list},
    aspect => q{},
  });
  isa_ok($view, 'npg_qc::view::main', '$view');
  my $render;
  eval { $render = $view->render(); };
  is($EVAL_ERROR, q{}, 'no croak on render list');
  ok($util->test_rendered($render, 't/data/rendered/html/main_list.html'), 'list render is ok');
}

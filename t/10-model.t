#########
# Author:        ajb
# Maintainer:    $Author$
# Created:       2008-07-21
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

use strict;
use warnings;
use Test::More tests => 9;
use English qw(-no_match_vars);
use IO::Scalar;
use t::util;

use_ok('npg_qc::model');

my $util = t::util->new({fixtures =>1});
{
  my $model = npg_qc::model->new({util => $util});
  isa_ok($model, 'npg_qc::model', '$model');
  
  is($model->get_cycle_count_from_recipe(10, 1), 37, "correct cycle number for first end run of run 10");
  is($model->get_cycle_count_from_recipe(10, 2), 2, "correct cycle number for second end run of run 10");

  my $cycle_range = $model->get_read_cycle_range_from_recipe(10,1);
  is($cycle_range->[0], 1, 'first cycle number for run 10 read 1');
  is($cycle_range->[1], 37, 'last cycle number for run 10 read 1');
  
  $cycle_range = $model->get_read_cycle_range_from_recipe(4298);
  is($cycle_range->[1], 108, 'last cycle number for run 4298');
  
  $cycle_range = $model->get_read_cycle_range_from_recipe(4275, 2);
  is($cycle_range->[0], 68, 'first cycle number for run 4275 read 2');

  $cycle_range = $model->get_read_cycle_range_from_recipe(4275, 1);
  is($cycle_range->[1], 54, 'last cycle number for run 4275 read 1');

}

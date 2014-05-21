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
use npg_qc::model::run_tile;

use_ok('npg_qc::model::information_content_by_cycle');
my $util = t::util->new({fixtures =>1});
{
  my $model = npg_qc::model::information_content_by_cycle->new({
    util                            => $util,
    id_information_content_by_cycle => 1,
    id_run_tile                     => 1,
  });
  isa_ok($model, 'npg_qc::model::information_content_by_cycle', '$model');
  isa_ok($model->run_tile(), 'npg_qc::model::run_tile', '$model->run_tile()');
}

{
  my $model = npg_qc::model::information_content_by_cycle->new({
    util => $util,
    id_run_tile     => 10,
    cycle           => 4,
    equiv_info      => 7000,
    align           => 8000,
    total           => 9000,
    rescore         => 1,   
  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 'saving data - rescore 1');  
}

{
  my $model = npg_qc::model::information_content_by_cycle->new({
    util => $util,
    id_run_tile     => 10,
    cycle           => 4,
    equiv_info      => 9000,
    align           => 10000,
    total           => 11000,
    rescore         => 1,   
  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 're-saving data - rescore 1');  
}


{
  my $model = npg_qc::model::information_content_by_cycle->new({
    util => $util,
    id_run_tile     => 10,
    cycle           => 4,
    equiv_info      => 7000,
    align           => 8000,
    total           => 9000,
    rescore         => 0,   
  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 'saving data - rescore 0');  
}

{
  my $model = npg_qc::model::information_content_by_cycle->new({
    util => $util,
    id_run_tile     => 10,
    cycle           => 4,
    equiv_info      => 9000,
    align           => 10000,
    total           => 11000,
    rescore         => 0,   
  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 're-saving data - rescore 0');  
}

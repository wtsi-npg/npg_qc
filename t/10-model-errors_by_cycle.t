#########
# Author:        gq1
# Maintainer:    $Author$
# Created:       2008-11-12
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
use npg_qc::model::errors_by_cycle;

use_ok('npg_qc::model::errors_by_cycle');

my $util = t::util->new({fixtures =>1});
{
  my $model = npg_qc::model::errors_by_cycle->new({util => $util});
  isa_ok($model, 'npg_qc::model::errors_by_cycle', '$model');
}

{
  my $model = npg_qc::model::errors_by_cycle->new({
    util => $util,
    id_run_tile => 20,
  });
  eval { $model->save() };
  like($EVAL_ERROR, qr{Column\ \'cycle\'\ cannot\ be\ null}, 'field cycle in table move_z cannot be null');  
}

{
  my $model = npg_qc::model::errors_by_cycle->new({
    util => $util,
    id_run_tile      => 20,
    cycle            => 4,
    error_percentage => 2,
    blank_percentage => 0.2,
    rescore          => 0,
    
  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 'saving data - rescore 0');  
}


{
  my $model = npg_qc::model::errors_by_cycle->new({
    util => $util,
    id_run_tile      => 20,
    cycle            => 4,
    error_percentage => 2,
    blank_percentage => 0.2,
    rescore          => 1,
    
  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 'saving data - rescore 1');  
}

{
  my $model = npg_qc::model::errors_by_cycle->new({
    util => $util,
    id_run_tile      => 20,
    cycle            => 4,
    error_percentage => 2,
    blank_percentage => 0.5,
    rescore          => 1,
    
  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 'saving data - rescore 1');  
}


{
  my $model = npg_qc::model::errors_by_cycle->new({
    util => $util,
    id_run_tile      => 20,
    cycle            => 4,
    error_percentage => 2,
    blank_percentage => 0.5,
    rescore          => 0,
    
  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 'saving data - rescore 0');  
}

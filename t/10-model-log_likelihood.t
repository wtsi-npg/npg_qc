#########
# Author:        ajb
# Created:       2008-07-22
#

use strict;
use warnings;
use Test::More tests => 7;
use English qw(-no_match_vars);
use IO::Scalar;
use t::util;
use npg_qc::model::run_tile;

use_ok('npg_qc::model::log_likelihood');
my $util = t::util->new({fixtures =>1});
{
  my $model = npg_qc::model::log_likelihood->new({
    util              => $util,
    id_log_likelihood => 1,
    id_run_tile       => 1,
  });
  isa_ok($model, 'npg_qc::model::log_likelihood', '$model');
  isa_ok($model->run_tile(), 'npg_qc::model::run_tile', '$model->run_tile()');
}

{
  my $model = npg_qc::model::log_likelihood->new({
    util => $util,
    id_run_tile      => 20,
    cycle            => 4,
    read_as        => 'T',
    really_a         => -45,
    really_t         => 49,
    really_c         => -45,
    really_g         => -25,
    rescore          => 1,    
  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 'saving data - rescore 1');  
}

{
  my $model = npg_qc::model::log_likelihood->new({
    util => $util,
    id_run_tile      => 20,
    cycle            => 4,
    read_as        => 'T',
    really_a         => -45,
    really_t         => 59,
    really_c         => -35,
    really_g         => -25,
    rescore          => 1,    
  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 'saving data - rescore 1');  
}


{
  my $model = npg_qc::model::log_likelihood->new({
    util => $util,
    id_run_tile      => 20,
    cycle            => 4,
    read_as        => 'T',
    really_a         => -45,
    really_t         => 49,
    really_c         => -45,
    really_g         => -25,
    rescore          => 0,    
  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 'saving data - rescore 0');  
}

{
  my $model = npg_qc::model::log_likelihood->new({
    util => $util,
    id_run_tile      => 20,
    cycle            => 4,
    read_as        => 'T',
    really_a         => -45,
    really_t         => 59,
    really_c         => -35,
    really_g         => -25,
    rescore          => 0,    
  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 'saving data - rescore 0');  
}

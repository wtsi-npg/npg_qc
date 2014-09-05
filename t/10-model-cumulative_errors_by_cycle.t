#########
# Author:        ajb
# Created:       2008-07-21
#

use strict;
use warnings;
use Test::More tests => 15;
use English qw(-no_match_vars);
use IO::Scalar;
use t::util;
use npg_qc::model::run_tile;

use_ok('npg_qc::model::cumulative_errors_by_cycle');

my $util = t::util->new({fixtures =>1});
{
  my $model = npg_qc::model::cumulative_errors_by_cycle->new({
    util                          => $util,
    id_cumulative_errors_by_cycle => 1,
  });
  isa_ok($model, 'npg_qc::model::cumulative_errors_by_cycle', '$model');
  my $run_tile = $model->run_tile();
  isa_ok($run_tile, 'npg_qc::model::run_tile', '$model->run_tile()');
  isa_ok($model->cumulative_errors_score(1,1,1), 'ARRAY', '$model->score(1,1,1)');
  is(scalar@{$model->cumulative_errors_score(1,1,1)}, 0, 'nothing returned in dataset for $model->score(1,1,1)');
  isa_ok($model->cumulative_errors_rescore(1,1,1), 'ARRAY', '$model->rescore(1,1,1)');
  is(scalar@{$model->cumulative_errors_rescore(1,1,1)}, 5, '4 items returned in dataset for $model->rescore(1,1,1)');
}
{
  ### tests if no items are returned for run_tile
  my $model = npg_qc::model::cumulative_errors_by_cycle->new({
    util                          => $util,
    id_cumulative_errors_by_cycle => 3,
  });
  isa_ok($model->cumulative_errors_rescore(2,3,30), 'ARRAY', '$model->rescore(2,3,30)');
  is(scalar@{$model->cumulative_errors_rescore(2,3,30)}, 0, '0 items returned in dataset for $model->rescore(2,3,30)');
}
{
  ### tests when the run_tile has no other end
  my $model = npg_qc::model::cumulative_errors_by_cycle->new({
    util                          => $util,
    id_cumulative_errors_by_cycle => 5,
  });
  isa_ok($model->cumulative_errors_rescore(2,1,30), 'ARRAY', '$model->rescore(2,1,30)');
  is(scalar@{$model->cumulative_errors_rescore(2,1,30)}, 1, '1 item returned in dataset for $model->rescore(2,1,30)');
}

{
  my $model = npg_qc::model::cumulative_errors_by_cycle->new({
    util => $util,
    id_run_tile      => 20,
    cycle            => 4,
    one              => 2,
    two              => 2,
    three            => 2,
    four             => 2,
    five             => 2,
    rescore          => 1,    
  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 'saving data - rescore 1');  
}

{
  my $model = npg_qc::model::cumulative_errors_by_cycle->new({
    util => $util,
    id_run_tile      => 20,
    cycle            => 4,
    one              => 3,
    two              => 3,
    three            => 3,
    four             => 3,
    five             => 3,
    rescore          => 1,    
  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 're-saving data - rescore 1');  
}

{
  my $model = npg_qc::model::cumulative_errors_by_cycle->new({
    util => $util,
    id_run_tile      => 20,
    cycle            => 4,
    one              => 2,
    two              => 2,
    three            => 2,
    four             => 2,
    five             => 2,
    rescore          => 0,    
  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 'saving data - rescore 0');  
}

{
  my $model = npg_qc::model::cumulative_errors_by_cycle->new({
    util => $util,
    id_run_tile      => 20,
    cycle            => 4,
    one              => 3,
    two              => 3,
    three            => 3,
    four             => 3,
    five             => 3,
    rescore          => 0,    
  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 're-saving data - rescore 0');  
}

#########
# Author:        gq1
# Created:       2008-12-5
#

use strict;
use warnings;
use Test::More tests => 7;
use English qw(-no_match_vars);
use IO::Scalar;
use t::util;


use_ok('npg_qc::model::run_timeline');

my $util = t::util->new({fixtures =>1});
{
  my $model = npg_qc::model::run_timeline->new({util => $util});
  isa_ok($model, 'npg_qc::model::run_timeline', '$model');
}

{
  my $model = npg_qc::model::run_timeline->new({
    util => $util,
 
  });
  eval {
    $model->save();
    1;
  };
 
  like($EVAL_ERROR, qr{Column\ \'id_run\'\ cannot\ be\ null}, 'field id_run in table run_timeline cannot be null');  
}


{
  my $model = npg_qc::model::run_timeline->new({
    util => $util,
    id_run => 11,
  
  });
  eval {
    $model->save();
    1;
  };
 
  is($EVAL_ERROR, q{}, 'field start_time in table run_timeline can be null');  
}

{
  my $model = npg_qc::model::run_timeline->new({
    util => $util,
    id_run => 11,
    start_time   =>'2008-12-05 10:01:02',
  
  });
  eval {
    $model->save();
    1;
  };
 
  is($EVAL_ERROR, q{}, 'field complete_time in table run_timeline can be null');  
}


{
  my $model = npg_qc::model::run_timeline->new({
    util => $util,
    id_run => 11,
    start_time   =>'2008-12-05 10:01:02',
    complete_time =>'2008-12-06 11:01:02',
 
  });
  eval {
    $model->save();
    1;
  };
 
  is($EVAL_ERROR, q{}, 'field end_time can be null');  
}

{
  my $model = npg_qc::model::run_timeline->new({
    util => $util,
    id_run => 11,
    start_time   =>'2008-12-05 10:01:02',
    complete_time =>'2008-12-06 11:01:02',
    end_time      =>'2008-12-08 12:01:02',
  
  });
  eval {
    $model->save();
    1;
  };
 
  is($EVAL_ERROR, q{}, 'model run_timeline saving ok');  

}

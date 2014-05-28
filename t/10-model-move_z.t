#########
# Author:        gq1
# Created:       2008-07-16
#

use strict;
use warnings;
use Test::More 'no_plan';#tests => 4;
use English qw(-no_match_vars);
use IO::Scalar;
use t::util;
use npg_qc::model::run_tile;

use_ok('npg_qc::model::move_z');

my $util = t::util->new({fixtures =>1});
{
  my $model = npg_qc::model::move_z->new({util => $util});
  isa_ok($model, 'npg_qc::model::move_z', '$model');
}

{
  my $model = npg_qc::model::move_z->new({
    util => $util,
    id_run_tile => 10,
  });
  eval { $model->save() };
  like($EVAL_ERROR, qr{Column\ \'cycle\'\ cannot\ be\ null}, 'field cycle in table move_z cannot be null');  
}

{
  my $model = npg_qc::model::move_z->new({
    util => $util,
    id_run_tile => 10,
    cycle => 1,
  });
  eval { $model->save() };
  like($EVAL_ERROR, qr{Column\ \'currentz\'\ cannot\ be\ null}, 'field currentz in table move_z cannot be null');  
}


{
  my $model = npg_qc::model::move_z->new({
    util => $util,
    id_run_tile => 10,
    cycle => 1,
    currentz => 100,
  });
  eval { $model->save() };
  like($EVAL_ERROR, qr{Column\ \'targetz\'\ cannot\ be\ null}, 'field targetz in table move_z cannot be null');  
}

{
  my $model = npg_qc::model::move_z->new({
    util => $util,
    id_run_tile => 10,
    cycle       => 1,
    currentz    => 100,
    targetz     =>120,
  });
  eval { $model->save() };
  like($EVAL_ERROR, qr{Column\ \'newz\'\ cannot\ be\ null}, 'field newz in table move_z cannot be null');  
}
{
  my $model = npg_qc::model::move_z->new({
    util => $util,
    id_run_tile => 10,
    cycle       => 1,
    currentz    => 100,
    targetz     => 120,
    newz        => 120,
  
  });
  eval { $model->save() };
  like($EVAL_ERROR, qr{Column\ \'start\'\ cannot\ be\ null}, 'field start in table move_z cannot be null') ;
}
{
  my $model = npg_qc::model::move_z->new({
    util => $util,
    id_run_tile => 10,
    cycle       => 1,
    currentz    => 100,
    targetz     => 120,
    newz        => 120,
    start       => 307971922,
  });
  eval { $model->save() };
  like($EVAL_ERROR, qr{Column\ \'stop\'\ cannot\ be\ null}, 'field stop in table move_z cannot be null') ;
}
{
  my $model = npg_qc::model::move_z->new({
    util => $util,
    id_run_tile => 10,
    cycle       => 1,
    currentz    => 100,
    targetz     => 120,
    newz        => 120,
    start       => 307971922,
    stop        => 307971925,
    
  });
  eval { $model->save() };
  like($EVAL_ERROR, qr{Column\ \'move\'\ cannot\ be\ null}, 'field move in table move_z cannot be null') ;
}

{
  my $model = npg_qc::model::move_z->new({
    util => $util,
    id_run_tile => 1000,
    cycle       => 1,
    currentz    => 100,
    targetz     => 120,
    newz        => 120,
    start       => 307971922,
    stop        => 307971925,
    move        => 0,
  });
  eval { $model->save() };
  like($EVAL_ERROR, qr{a\ foreign\ key\ constraint\ fails}, 'foreign key for move_z not exist') ;
}
{
  my $run_tile = npg_qc::model::run_tile->new({
    util     => $util,
    id_run   => 10,
    position => 1,
    tile     => 1,
    end      => 1,
    row      => 1,
    col      => 1,
  });
  $run_tile->save();
  my $model = npg_qc::model::move_z->new({
    util => $util,
    id_run_tile => 1,
    cycle       => 1,
    currentz    => 100,
    targetz     => 120,
    newz        => 120,
    start       => 307971922,
    stop        => 307971925,
    move        => 0,
  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 'save ok');
}

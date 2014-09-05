#########
# Author:        gq1
# Created:       2008-11-12
#

use strict;
use warnings;
use Test::More 'no_plan';#tests => 4;
use English qw(-no_match_vars);
use IO::Scalar;
use t::util;
use npg_qc::model::signal_mean;

use_ok('npg_qc::model::signal_mean');

my $util = t::util->new({fixtures =>1});
{
  my $model = npg_qc::model::signal_mean->new({util => $util});
  isa_ok($model, 'npg_qc::model::signal_mean', '$model');
}

{
  my $model = npg_qc::model::signal_mean->new({
    util => $util,
    id_run => 10,
  });
  eval { $model->save() };
  like($EVAL_ERROR, qr{Column\ \'position\'\ cannot\ be\ null}, 'field position in table move_z cannot be null');  
}

{
  my $model = npg_qc::model::signal_mean->new({
    util => $util,
    id_run => 10,
    position =>4,
    cycle  => 56,
    all_a  => 1,
    all_t  => 1,
    all_c  =>1,
    all_g  => 1,
    call_a => 1,
    call_t => 1,
    call_c =>1,
    call_g => 1,
    base_a => 1,
    base_t => 1,
    base_c =>1,
    base_g => 1,
    
  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 'saving data');  
}

{
  my $model = npg_qc::model::signal_mean->new({
    util => $util,
    id_run => 10,
    position =>4,
    cycle  => 56,
    all_a  => 2,
    all_t  => 2,
    all_c  =>1,
    all_g  => 1,
    call_a => 1,
    call_t => 1,
    call_c =>1,
    call_g => 1,
    base_a => 1,
    base_t => 2,
    base_c =>1,
    base_g => 1,
    
  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 're -saving data with the same id_run, positon and cycle');  
}

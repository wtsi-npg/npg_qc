#########
# Author:        gq1
# Created:       2009-01-20
#

use strict;
use warnings;
use Test::More tests => 5;
use English qw(-no_match_vars);
use IO::Scalar;
use t::util;
use npg_qc::model::offset;
;

use_ok('npg_qc::model::offset');


my $util = t::util->new({fixtures =>1});


{
  my $model = npg_qc::model::offset->new({util => $util});
  isa_ok($model, 'npg_qc::model::offset', '$model');
}


{
  my $model = npg_qc::model::offset->new({
     util => $util,
     });
  eval { $model->save() };
  like($EVAL_ERROR, qr{Column\ \'id_run\'\ cannot\ be\ null}, 'field id_run in table offset cannot be null');  
  
}

{
  my $model = npg_qc::model::offset->new({
     util => $util,
     id_run => 6,
     lane   => 1,
     tile   => 100,
     cycle  => 20,
     image  => 1,
     x      => 0.02,
     y      => -0.03,
     });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 'no croak when saving data');  
   eval { $model->save() };
  is($EVAL_ERROR, q{}, 'no croak when re-saving data'); 
}

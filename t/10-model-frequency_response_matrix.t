#########
# Author:        gq1
# Maintainer:    $Author$
# Created:       2009-01-19
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

use strict;
use warnings;
use Test::More tests => 5;
use English qw(-no_match_vars);
use IO::Scalar;
use t::util;
use npg_qc::model::frequency_response_matrix;
;

use_ok('npg_qc::model::frequency_response_matrix');


my $util = t::util->new({fixtures =>1});


{
  my $model = npg_qc::model::frequency_response_matrix->new({util => $util});
  isa_ok($model, 'npg_qc::model::frequency_response_matrix', '$model');
}


{
  my $model = npg_qc::model::frequency_response_matrix->new({
     util => $util,
     });
  eval { $model->save() };
  like($EVAL_ERROR, qr{Column\ \'id_run\'\ cannot\ be\ null}, 'field id_run in table frequency_response_matrix cannot be null');  
  
}

{
  my $model = npg_qc::model::frequency_response_matrix->new({
     util => $util,
     id_run => 1,
     cycle  => 2,
     lane   => 1,
     base   => 'A',
     red1   => 0.23,
     red2   => -0.01,
     green1 => 0.02,
     green2 => 0.03,
     });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 'no croak when saving data');  
   eval { $model->save() };
  is($EVAL_ERROR, q{}, 'no croak when re-saving data'); 
}

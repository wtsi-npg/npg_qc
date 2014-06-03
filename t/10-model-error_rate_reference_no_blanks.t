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

use_ok('npg_qc::model::error_rate_reference_no_blanks');
my $util = t::util->new({fixtures =>1});
{
  my $model = npg_qc::model::error_rate_reference_no_blanks->new({
    util                              => $util,
    id_error_rate_reference_no_blanks => 1,
    id_run_tile                       => 1,
  });
  isa_ok($model, 'npg_qc::model::error_rate_reference_no_blanks', '$model');
  isa_ok($model->run_tile(), 'npg_qc::model::run_tile', '$model->run_tile()');
}


{
  my $model = npg_qc::model::error_rate_reference_no_blanks->new({
    util => $util,
    id_run_tile      => 20,
    really           => 'T',
    read_as_a        => 0.5,
    read_as_t        => 95,
    read_as_c        => 0.5,
    read_as_g        => 0.5,
    rescore          => 1,    
  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 'saving data - rescore 1');  
}

{
  my $model = npg_qc::model::error_rate_reference_no_blanks->new({
    util => $util,
    id_run_tile      => 20,
    really           => 'T',
    read_as_a        => 1.5,
    read_as_t        => 98,
    read_as_c        => 1.5,
    read_as_g        => 1.5,
    rescore          => 1,    
  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 're-saving data - rescore 1');  
}

{
  my $model = npg_qc::model::error_rate_reference_no_blanks->new({
    util => $util,
    id_run_tile      => 20,
    really           => 'T',
    read_as_a        => 0.5,
    read_as_t        => 95,
    read_as_c        => 0.5,
    read_as_g        => 0.5,
    rescore          => 0,    
  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 'saving data - rescore 0');  
}

{
  my $model = npg_qc::model::error_rate_reference_no_blanks->new({
    util => $util,
    id_run_tile      => 20,
    really           => 'T',
    read_as_a        => 1.5,
    read_as_t        => 98,
    read_as_c        => 1.5,
    read_as_g        => 1.5,
    rescore          => 0,    
  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 're-saving data - rescore 0');  
}

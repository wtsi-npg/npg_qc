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

use_ok('npg_qc::model::errors_by_cycle_and_nucleotide');
my $util = t::util->new({fixtures =>1});
{
  my $model = npg_qc::model::errors_by_cycle_and_nucleotide->new({
    util                              => $util,
    id_errors_by_cycle_and_nucleotide => 1,
    id_run_tile                       => 1,
  });
  isa_ok($model, 'npg_qc::model::errors_by_cycle_and_nucleotide', '$model');
  isa_ok($model->run_tile(), 'npg_qc::model::run_tile', '$model->run_tile()');
}


{
  my $model = npg_qc::model::errors_by_cycle_and_nucleotide->new({
    util => $util,
    id_run_tile      => 20,
    cycle            => 4,
    read_as        => 'T',
    really_a         => 15,
    really_t         => 498,
    really_c         => 23,
    really_g         => 5,
    rescore          => 1,    
  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 'saving data - rescore 1');  
}

{
  my $model = npg_qc::model::errors_by_cycle_and_nucleotide->new({
    util => $util,
    id_run_tile      => 20,
    cycle            => 4,
    read_as        => 'T',
    really_a         => 25,
    really_t         => 598,
    really_c         => 23,
    really_g         => 5,
    rescore          => 1,    
  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 're-saving data - rescore 1');  
}


{
  my $model = npg_qc::model::errors_by_cycle_and_nucleotide->new({
    util => $util,
    id_run_tile      => 20,
    cycle            => 4,
    read_as        => 'T',
    really_a         => 15,
    really_t         => 498,
    really_c         => 23,
    really_g         => 5,
    rescore          => 0,    
  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 'saving data - rescore 0');  
}

{
  my $model = npg_qc::model::errors_by_cycle_and_nucleotide->new({
    util => $util,
    id_run_tile      => 20,
    cycle            => 4,
    read_as        => 'T',
    really_a         => 25,
    really_t         => 598,
    really_c         => 23,
    really_g         => 5,
    rescore          => 0,    
  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, 're-saving data - rescore 0');  
}

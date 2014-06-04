#########
# Author:        gq1
# Created:       2008-10-23
#

use strict;
use warnings;
use Test::More  tests => 8;
use English qw(-no_match_vars);
use IO::Scalar;
use t::util;
use npg_qc::model::instrument_statistics;

##
use_ok('npg_qc::model::instrument_statistics');

##
my $util = t::util->new({fixtures =>1});

##
{
  my $model = npg_qc::model::instrument_statistics->new({util => $util});
  isa_ok($model, 'npg_qc::model::instrument_statistics', '$model');
}

##
{
  my $model = npg_qc::model::instrument_statistics->new({util => $util});
  eval{
    $model->save();
    1;
  };
  like($EVAL_ERROR, qr{Column\ \'id_run\'\ cannot\ be\ null}, 'id_run can not be null');
}

##
{
  my $model = npg_qc::model::instrument_statistics->new({util => $util,
                                                         id_run =>5,
                                                        });
  eval{
    $model->save();
    1;
  };
  like($EVAL_ERROR, qr{Column\ \'end\'\ cannot\ be\ null}, 'end can not be null');
}

##
{
  my $model = npg_qc::model::instrument_statistics->new({util => $util,
                                                         id_run =>10,
                                                         end    =>1,
                                                        });
  eval{
    $model->save();
    1;
  };
  like($EVAL_ERROR, qr{Column\ \'id_run_actual\'\ cannot\ be\ null}, 'id_run_actual can not be null');
}

##
{
  my $model = npg_qc::model::instrument_statistics->new({util => $util,
                                                         id_run =>10,
                                                         end    =>1,
                                                         id_run_actual =>10,
                                                        });
  eval{
    $model->save();
    1;
  };
  like($EVAL_ERROR, qr{Column\ \'instrument\'\ cannot\ be\ null}, 'instrument can not be null');
}

##
{
  my $model = npg_qc::model::instrument_statistics->new({util => $util,
                                                         id_run =>10,
                                                         end    =>1,
                                                         id_run_actual =>10,
                                                         instrument  => 'IL8',
                                                        });
  eval{
    $model->save();
    1;
  };
  is($EVAL_ERROR, q{}, 'saving ok');

  eval{
    $model->save();
    1;
  };
  is($EVAL_ERROR, q{}, 're-saving ok');
}

#########
# Author:        gq1
# Maintainer:    $Author$
# Created:       2008-11-12
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
use npg_qc::model::run_and_pair;

our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/mx; $r; };

use_ok('npg_qc::model::run_and_pair');

my $util = t::util->new({fixtures =>1});
{
  my $model = npg_qc::model::run_and_pair->new({util => $util});
  isa_ok($model, 'npg_qc::model::run_and_pair', '$model');
}

{
  my $model = npg_qc::model::run_and_pair->new({
    util => $util,
  });
  eval { $model->save() };
  like($EVAL_ERROR, qr{Column\ \'id_run\'\ cannot\ be\ null}, 'field id_run in table run_and_pair cannot be null');  
}

{
  my $model = npg_qc::model::run_and_pair->new({
    util => $util,
    id_run => 3,
  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, "saving data, id_run 3");
}

{
  my $model = npg_qc::model::run_and_pair->new({
    util => $util,
    id_run => 3,
  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, "re-saving data, id_run 3");
}

{
  my $model = npg_qc::model::run_and_pair->new({
    util => $util,
    id_run => 0,
  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, "re-saving data, id_run 0");
}

{
  my $model = npg_qc::model::run_and_pair->new({
    util => $util,
    id_run => 0,
  });
  eval { $model->save() };
  is($EVAL_ERROR, q{}, "re-saving data, id_run 0");
}

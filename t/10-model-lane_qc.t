#########
# Author:        gq1
# Maintainer:    $Author$
# Created:       2008-12-2
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


our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/mx; $r; };

use_ok('npg_qc::model::lane_qc');

my $util = t::util->new({fixtures =>1});
{
  my $model = npg_qc::model::lane_qc->new({util => $util});
  isa_ok($model, 'npg_qc::model::lane_qc', '$model');
}

{
  my $model = npg_qc::model::lane_qc->new({
    util => $util,
    id_run_tile => 11,
    end=>1,
    
  });
  eval {
    $model->save();
    1;
  };
 
  like($EVAL_ERROR, qr{Column\ \'clusters_raw\'\ cannot\ be\ null}, 'field clusters_raw in table lane_qc cannot be null');  
}
 $util->transactions(0);
{
  my $model = npg_qc::model::lane_qc->new({
    util => $util,
    id_run_tile => 11,
    end=>1,
    clusters_raw => 7777,
    av_1st_cycle_int_pf => 77.77,
    av_perc_intensity_after_20_cycles_pf => 88.88,
    perc_pf_clusters => 5.67,    
  });
  eval {
    $model->save();
    1;
  };
 
  is($EVAL_ERROR, q{}, 'saving data to lane_qc table');  
}

{
  my $model = npg_qc::model::lane_qc->new({
    util => $util,
    id_run_tile => 11, 
    clusters_raw => 7777,
    av_1st_cycle_int_pf => 77.77,
    av_perc_intensity_after_20_cycles_pf => 99.88,
    perc_pf_clusters => 5.67,    
  });
  eval {
    $model->save();
    1;
  };
 
  is($EVAL_ERROR, q{}, 're-saving data to lane_qc table'); 
  
  $util->dbh()->commit();
}

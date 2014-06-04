#########
# Author:        gq1
# Created:       2008-09-29
#

use strict;
use warnings;
use Test::More  tests => 34; #'no_plan' ;
use English qw(-no_match_vars);
use IO::Scalar;
use t::util;
use npg_qc::model::run_graph;

##
use_ok('npg_qc::model::run_graph');

$ENV{NPG_WEBSERVICE_CACHE_DIR} = q[t/data/qc_webcache];

##
my $util = t::util->new({fixtures =>1});

##
{
  my $model = npg_qc::model::run_graph->new({util => $util});
  isa_ok($model, 'npg_qc::model::run_graph', '$model');
}
##
{
  my $model = npg_qc::model::run_graph->new({util => $util});
  eval{
    $model->save();
    1;
  };
  like($EVAL_ERROR, qr{Column\ \'id_run\'\ cannot\ be\ null}, 'id_run can not be null');
}

##
{
  my $model = npg_qc::model::run_graph->new({
                                  util => $util,
                                  id_run => 4,
                                  end    => 1,
                                  yield_gb  =>12000,
                                  avg_error =>0.74,
                                  avg_cluster_per_tile =>82311,
                                  avg_cluster_per_tile_raw =>92174,
                                  avg_cluster_per_tile_control =>82000,
                                  avg_cluster_per_tile_raw_control =>92000,
                                  cycle=>37,
                                  });
  eval{
    $model->save();
    1;
  };
  is($EVAL_ERROR, q{}, 'save data to the database');
}

##
{
  my $model = npg_qc::model::run_graph->new({
                                  util => $util,
                                  id_run => 4,
                                  end  => 1,
                                  yield_gb  =>12009,
                                  avg_error =>0.79,
                                  avg_cluster_per_tile =>82319,
                                  avg_cluster_per_tile_raw =>92179,
                                  avg_cluster_per_tile_control =>82009,
                                  avg_cluster_per_tile_raw_control =>92009,
                                  cycle =>37,
                                  });
  eval{
    $model->save();
    1;
  };
  is($EVAL_ERROR, q{}, 'resave data to the database with the same id_run');
}
##
{
  my $model = npg_qc::model::run_graph->new({
                                  util => $util,

                                 });
  my $id_run;
  eval{    
    $id_run = $model->get_actual_id_run(10, 1);
    1;
  };
  is($EVAL_ERROR, q{}, 'get actual id_run if end = 1');
  is($id_run, 10, 'get correct id_run when end =1');
  
}
##
{
  my $model = npg_qc::model::run_graph->new({
                                  util => $util,

                                 });
  my $id_run;
  eval{
    
    $id_run = $model->get_actual_id_run(10, 2);
    1;
  };

  is($id_run, 11, 'get correct id_run when end = 2');
  
}
##
{
  my $model = npg_qc::model::run_graph->new({
                                  util => $util,

                                 });
  my $id_run;
  eval{
    $id_run = $model->get_actual_id_run(12, 2);

    1;
  };

  is($id_run, 12, 'get correct id_run when end = 2 but the pair id not in database');
  
}
##
{
  my $model = npg_qc::model::run_graph->new({
                                  util => $util,
                                  });
                                  
  eval{
    $model->id_run($model->get_actual_id_run(10,1));
    $model->end(1);
    $model->get_total_yield_cluster(10, 1, 36);
    $model->save();
    1;
  };
  is($EVAL_ERROR, q{}, 'get total yield, avg error and avg number of cluster per tile');
  
  eval{
    $model->get_error_cluster_control_lane(10, 1);
    $model->save();
    1;
  };
  is($EVAL_ERROR, q{}, 'get avg number of cluster per tile for control lanes');
}

##
{
  my $model = npg_qc::model::run_graph->new({
                                  util => $util,
                                  });
  eval{                              
    my $runlist = $model->get_runlist_done();
    #print keys %{$runlist}, "\n";
    1;
  };
  is($EVAL_ERROR, q{}, 'get runlist already done');
}

##
{
  my $model = npg_qc::model::run_graph->new({
                                  util => $util,
                               });
  my $runlist; 
  eval{                              
    $runlist = $model->get_runlist_todo();
    #print  $runlist->[0]->[0], "\n";
    #print  $runlist->[0]->[1], "\n";
    #print  $runlist->[1]->[0], "\n";
    #print  $runlist->[1]->[1], "\n";
    1;
  };
  is($EVAL_ERROR, q{}, 'get runlist to do');
  #is(scalar @{$runlist}, 2, 'get correct number runs to do');
}

##
{
  my $model = npg_qc::model::run_graph->new({
                                  util => $util,
                              });
  my $cycle_count;
  eval{
    $cycle_count = $model->get_cycle_count_from_cache(10, 1);
    1;
  };
  is($EVAL_ERROR, q{}, 'get cycle count from cache');
  is($cycle_count, 37, 'get correct cycle count from cache');
} 

##
{
  my $model = npg_qc::model::run_graph->new({
                                  util => $util,
                              });
  my $cycle_count;
  eval{
    $cycle_count = $model->get_cycle_count_direct(3,1);
    1;
  };
  is($EVAL_ERROR, q{}, 'get cycle count directly');
  is($cycle_count, 3, 'get correct cycle count directly');

}

##
{
  my $model = npg_qc::model::run_graph->new({
                                  util => $util,
                              });
  my $cycle_count;
  eval{
    $cycle_count = $model->get_cycle_count_from_db(3, 1,'move_z');
    1;
  };
  is($EVAL_ERROR, q{}, 'get cycle count from table move_z directly');
  is($cycle_count, 4, 'get correct cycle count from table move_z directly');

}
##
{
  my $model = npg_qc::model::run_graph->new({
                                  util => $util,
                              });
  my $cycle_count;
  eval{
    $cycle_count = $model->get_cycle_count(3,1);
    1;
  };
  is($EVAL_ERROR, q{}, 'get cycle count via direct query');
  is($cycle_count, 3, 'get correct cycle count via direct query');
  

}
##
{
  my $model = npg_qc::model::run_graph->new({
                                  util => $util,
                              });
  my $cycle_count;
  eval{
    $cycle_count = $model->get_cycle_count(10,1);
    1;
  };
  is($EVAL_ERROR, q{}, 'get cycle count via cache table');
  is($cycle_count, 37, 'get correct cycle count via cache table');
  

}
##
{
  my $model = npg_qc::model::run_graph->new({
                                  util => $util,
                              });
  my $cycle_count;
  eval{
    $cycle_count = $model->get_cycle_count(55,1);
    1;
  };
  like($EVAL_ERROR, qr{can\ not\ get\ cycle\ count}, 'can not get cycle count');   

}
##
{
  my $model = npg_qc::model::run_graph->new({
                                  util => $util,
                              });
  eval{
    $model->calculate_all();
    1;
  };
  is($EVAL_ERROR, q{}, 'calculate all');
}   

##
{
  my $model = npg_qc::model::run_graph->new({
                                  util => $util,
                              });
  my $yield_by_run;
  eval{
    $yield_by_run = $model->get_yield_by_run(10);
    1;
  };
  is($EVAL_ERROR, q{}, 'get yield by run');
  is(scalar @{$yield_by_run}, 6, 'get correct number of runs');
}                       

##
{
  my $model = npg_qc::model::run_graph->new({
                                  util => $util,
                              });
  my $error_by_run;
  eval{
    $error_by_run = $model->get_avg_error_by_run(10);
    1;
  };
  is($EVAL_ERROR, q{}, 'get average error by run');
  is(scalar @{$error_by_run}, 6, 'get correct number of runs');
}

##
{
  my $model = npg_qc::model::run_graph->new({
                                  util => $util,
                              });
  my $error_by_run;
  eval{
    $error_by_run = $model->get_cluster_per_tile_by_run(10);
    1;
  };
  is($EVAL_ERROR, q{}, 'get average cluster per tile by run');
  is(scalar @{$error_by_run}, 6, 'get correct number of runs');
} 

##
{
  my $model = npg_qc::model::run_graph->new({
                                  util => $util,
                              });
  my $error_by_run;
  eval{
    $error_by_run = $model->get_cluster_per_tile_control_by_run(10);
    1;
  };
  is($EVAL_ERROR, q{}, 'get average cluster per tile by run for control lanes');
  is(scalar @{$error_by_run}, 6, 'get correct number of runs');
} 

##
{
  my $model = npg_qc::model::run_graph->new({
                                  util => $util,
                              });

  eval{
    $model->calculate_one_run(10, 1);
    1;
  };
  is($EVAL_ERROR, q{}, 'calculate all fields just for one run');
 
} 

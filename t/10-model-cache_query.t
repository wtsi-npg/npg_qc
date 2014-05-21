#########
# Author:        gq1
# Maintainer:    $Author$
# Created:       2008-09-23
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

use strict;
use warnings;
use Test::More tests => 42;
use Test::Exception;
use Test::Deep;
use IO::Scalar;
use t::util;
use npg_qc::model::cache_query;

use_ok('npg_qc::model::cache_query');

$ENV{NPG_WEBSERVICE_CACHE_DIR} = q[t/data/qc_webcache];

my $util = t::util->new({fixtures =>1});

{
  my $model = npg_qc::model::cache_query->new({util => $util});
  isa_ok($model, 'npg_qc::model::cache_query', '$model');
}

{
  my $model = npg_qc::model::cache_query->new({
    util => $util,
    ssha_sql => 'GbdhOrKXza98/jXuv9WAzNW0pcQ=',
  });
  throws_ok { $model->save() } qr{Column\ \'id_run\'\ cannot\ be\ null}, 'field id_run in table cache_query cannot be null';  
}

{
  my $model = npg_qc::model::cache_query->new({
    util => $util,
    ssha_sql => 'GbdhOrKXza98/jXuv9WAzNW0pcQ=',
    id_run => 917,
  });
  throws_ok { $model->save() } qr{Column\ \'end\'\ cannot\ be\ null}, 'field end in table cache_query cannot be null';  
}

{
  my $model = npg_qc::model::cache_query->new({
    util => $util,
    ssha_sql => 'GbdhOrKXza98/jXuv9WAzNW0pcQ=',
    id_run => 917,
    end    => 1,
  });
  throws_ok { $model->save() } qr{Column\ \'type\'\ cannot\ be\ null}, 'field type in table cache_query cannot be null';  
}

{
  my $model = npg_qc::model::cache_query->new({
    util => $util,
    ssha_sql => 'GbdhOrKXza98/jXuv9WAzNW0pcQ=',
    id_run => 917,
    end    => 1,
    type   => 'num_tiles_z_alert',
  });
  throws_ok { $model->save() } qr{Column\ \'results\'\ cannot\ be\ null}, 'field results in table cache_query cannot be null';  
}

{
  my $model = npg_qc::model::cache_query->new({
    util => $util,
    ssha_sql => 'GbdhOrKXza98/jXuv9WAzNW0pcQ=',
    id_run => 917,
    end    => 1,
    type   => 'num_tiles_z_alert',
    results => 'aaa',
  });
  throws_ok { $model->save() } qr{Column\ \'is_current\'\ cannot\ be\ null}, 'field is_current in table cache_query cannot be null';  
}

{
  my $model = npg_qc::model::cache_query->new({
    util => $util,
    ssha_sql => 'GbdhOrKXza98/jXuv9WAzNW0pcQ=',
    id_run => 917,
    end    => 1,
    type   => 'num_tiles_z_alert',
    results => 'aaa',
    is_current => 1,
  });
  lives_ok { $model->save() } 'save ok';
}

{
  my $model = npg_qc::model::cache_query->new({
    util => $util,
    });
  my $sql = "SELECT rt.position AS lane,
                         lqc.end AS end,
                         ROUND(SUM(lqc.clusters_raw*lqc.perc_pf_clusters*?/?)) AS lane_yield,
                         ROUND(AVG(lqc.clusters_raw*lqc.perc_pf_clusters/?)) AS clusters_pf,
                         ROUND(STD(lqc.clusters_raw*lqc.perc_pf_clusters/?)) AS clusters_pf_sd,
                         ROUND(AVG(lqc.clusters_raw)) AS clusters_raw,
                         ROUND(STD(lqc.clusters_raw)) AS clusters_raw_sd,
                         ROUND(AVG(lqc.av_1st_cycle_int_pf)) AS first_cycle_int,
                         ROUND(STD(lqc.av_1st_cycle_int_pf)) AS first_cycle_int_sd,
                         ROUND(AVG(lqc.av_perc_intensity_after_20_cycles_pf),2) AS perc_int_20_cycles,
                         ROUND(STD(lqc.av_perc_intensity_after_20_cycles_pf),2) AS perc_int_20_cycles_sd,
                         ROUND(AVG(lqc.perc_pf_clusters),2) AS perc_pf_clusters,
                         ROUND(STD(lqc.perc_pf_clusters),2) AS perc_pf_clusters_sd,
                         ROUND(AVG(lqc.perc_align_pf),2) AS perc_pf_align,
                         ROUND(STD(lqc.perc_align_pf),2) AS perc_pf_align_sd,
                         ROUND(AVG(lqc.av_alignment_score_pf),2) AS align_score,
                         ROUND(STD(lqc.av_alignment_score_pf),2) AS align_score_sd,
                         ROUND(AVG(lqc.perc_error_rate_pf),2) AS perc_error_rate,
                         ROUND(STD(lqc.perc_error_rate_pf),2) AS perc_error_rate_sd
                   FROM  lane_qc lqc, run_tile rt
                   WHERE rt.id_run = ?
                   AND   rt.id_run_tile = lqc.id_run_tile
                   AND   lqc.end = ?
                   GROUP BY rt.position, lqc.end
                   ORDER BY position";
  $model->generate_ssha($sql);
  is($model->generate_ssha($sql), 'GbdhOrKXza98/jXuv9WAzNW0pcQ=' , 'get correct ssha key');
}

{
  my $model = npg_qc::model::cache_query->new({
    util => $util,
    id_run => 3,
    end    => 1,
    type   => 'movez_tiles',
  });
  lives_ok { $model->cache_movez_tiles() } 'cache movez tiles';
  lives_ok { $model->get_cache_by_id_type_end()} 'get cache movez tiles';  
  is($model->get_cache_by_id_type_end()->[0][0], 3, 'get correct cache movez tiles');
}

{
  my $model = npg_qc::model::cache_query->new({
    util => $util,
    id_run => 3,
    end    => 1,
    type   => 'cycle_count',
  });
  lives_ok { $model->cache_cycle_count() } 'cache cycle count lives';
  lives_ok { $model->get_cache_by_id_type_end()} 'get cache cycle count lives';
  is($model->get_cache_by_id_type_end()->[0][0], 3, 'get correct cache cycle count');
}

{
  my $model = npg_qc::model::cache_query->new({
     util => $util,
     id_run =>3,
     type   => 'cycle_count',
     end    => 1,
     });
  my $id_runs = $model->check_cycle_count(); 
}

{
  my $model = npg_qc::model::cache_query->new({
    util => $util,
    id_run => 3,
    end    => 1,
    type   => 'lane_summary',
  });
  lives_ok { $model->cache_lane_summary(37) } 'cache lane summary lives';
  my $rows_ref;
  lives_ok { $rows_ref = $model->get_cache_by_id_type_end() } 'get lane summary lives';
  is_deeply($rows_ref, [{'clusters_pf' => '66598','lane_yield' => '7392','perc_pf_clusters_sd' => '0.00','perc_pf_align_sd' => undef,'clusters_pf_sd' => '0','perc_pf_clusters' => '79.88','align_score' => undef,'perc_pf_align' => undef,'perc_error_rate' => undef,'first_cycle_int_sd' => '0','perc_error_rate_sd' => undef,'clusters_raw_sd' => '0','perc_int_20_cycles_sd' => '0.00','first_cycle_int' => '159','lane' => '1','clusters_raw' => '83372','end' => '1','perc_int_20_cycles' => '99.06','align_score_sd' => undef},{'clusters_pf' => '66598','lane_yield' => '2464','perc_pf_clusters_sd' => '0.00','perc_pf_align_sd' => undef,'clusters_pf_sd' => '0','perc_pf_clusters' => '79.88','align_score' => undef,'perc_pf_align' => undef,'perc_error_rate' => undef,'first_cycle_int_sd' => '0','perc_error_rate_sd' => undef,'clusters_raw_sd' => '0','perc_int_20_cycles_sd' => '0.00','first_cycle_int' => '159','lane' => '2','clusters_raw' => '83372','end' => '1','perc_int_20_cycles' => '99.06','align_score_sd' => undef}] , 'get correct cache summary');
}

{
  my $model = npg_qc::model::cache_query->new({util => $util});
  my $id_runs = $model->get_runs_cache_movez_tiles();
  is (scalar @{$id_runs}, 3, 'get id_runs for caching movez_tiles');
  lives_ok { $model->cache_movez_tiles_all()} 'cache movez tiles all lives';
}

{
  my $model = npg_qc::model::cache_query->new({util => $util});
  my $id_runs = $model->get_runs_cache_lane_summary();
  ok($id_runs, 'get id_runs and ends for caching lane summary');
  lives_ok { $model->cache_lane_summary_all()} 'cache lane summary all lives';

  $id_runs = $model->get_runs_cache_lane_summary();
  is(scalar @{$id_runs}, 2, 'get id_runs and ends for caching lane summary');

  $model->id_run(3);
  $model->end(1);
  $model->type('lane_summary');

  my $rows_ref;
  lives_ok { $rows_ref = $model->get_cache_by_id_type_end()} 'get lane summary lives';
  is(scalar@{$rows_ref}, 2, 'correct number of elements in returned array');
  isa_ok($rows_ref->[0], 'HASH', 'first element');
  my $keys_string = join ':', sort keys %{$rows_ref->[0]};
  is($keys_string, 'align_score:align_score_sd:clusters_pf:clusters_pf_sd:clusters_raw:clusters_raw_sd:end:first_cycle_int:first_cycle_int_sd:lane:lane_yield:perc_error_rate:perc_error_rate_sd:perc_int_20_cycles:perc_int_20_cycles_sd:perc_pf_align:perc_pf_align_sd:perc_pf_clusters:perc_pf_clusters_sd', 'keys are correct in first element hash');
}

{
  my $model = npg_qc::model::cache_query->new({
    util => $util,
    id_run => 3,
    end    => 1,
    type   => 'lane_summary',
  });
  
  my $cached;
  lives_ok { $cached = $model->is_current_cached()} 'check cached or not lives';
  is($cached, 1, 'query already cached');
  $model->id_run(111);
  is($model->is_current_cached(), 0, 'query not current cached');
}

{
  my $model = npg_qc::model::cache_query->new({
    util => $util,
    id_run => 3,
    end    => 1,
    type   => 'lane_summary',
  });
  
  my $updated;
  lives_ok { $updated = $model->set_to_not_current() } 'set_to_not_current';
  is($updated, 1, '1 row updated');
  is($model->is_current_cached(), 0, 'query not current cached');
}

{
  my $model = npg_qc::model::cache_query->new({
    util => $util,
    id_run => 3,
    end    => 1,
    type   => 'movez_tiles',
  });
  is($model->id_cache_query(), 5, 'get current cache primary key');

}

{
  my $model = npg_qc::model::cache_query->new({
    util => $util,
    id_run => 3,
    end    => 1,
    type   => 'movez_tiles',
  });
  lives_ok { $model->update_current_cache() } 'update current cache movez_tiles lives';
}

{
  my $model = npg_qc::model::cache_query->new({
    util => $util,
    id_run => 3,
    end    => 1,
    type   => 'lane_summary',
  });
  lives_ok { $model->update_current_cache() } 'update current cache lane_summary lives';
}

{
  my $model = npg_qc::model::cache_query->new({
    util => $util,
    id_run => 3,
    end    => 1,
    type   => 'movez_tiles',
  });
  lives_ok { $model->cache_new_copy_data() } 'save new copy of cache movez_tiles lives';
}

{
  my $model = npg_qc::model::cache_query->new({
    util => $util,
    id_run => 3,
    end    => 1,
    type   => 'lane_summary',
  });
  lives_ok { $model->cache_new_copy_data() } 'save new copy of cache lane_summary';
}

{
  my $model = npg_qc::model::cache_query->new({
    util => $util,
  });
  is($model->complete_lane_qc_data(10, 1), 8, 'correct number of complete lanes for lane qc table for run 10');
}

{
  my $model = npg_qc::model::cache_query->new({
    util => $util,
  });
  is($model->complete_signal_mean_data(11), 0, 'correct number of complete lanes for signal mean table for run 11');
}

{
  my $model = npg_qc::model::cache_query->new({
    util => $util,
  });
  is($model->complete_errors_by_cycle_data(3, 1), 1, 'correct number of complete data for errors_by_cycle table for run 3');
}

{
  my $model = npg_qc::model::cache_query->new({
    util => $util,
    id_run =>3,
    end => 1,
  });
  ok(!$model->complete_qc_data_one_run(), 'run 3 data not complete');
}

1;

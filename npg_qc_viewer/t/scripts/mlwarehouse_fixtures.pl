use strict;
use warnings;
use WTSI::DNAP::Warehouse::Schema;
use t::util;

my $util = t::util->new();
my $path = q[t/data/fixtures/mlwarehouse];
my $real = WTSI::DNAP::Warehouse::Schema->connect();
my $tname;
my $rs;

{
  ############   iseq_product_metrics  #######################
  my $run_ids = [1272, 3323, 3500, 3965, 4025, 4950];
  $tname = q[IseqProductMetric];
  $rs = $real->resultset($tname)->search(
              { 'id_run' => $run_ids},
  );
  $util->rs_list2fixture(q[300-].$tname, [$rs], $path);

  ############   iseq_flowcell  #######################
  $tname = q[IseqFlowcell];
  $rs = $real->resultset($tname)->search(
              { 'iseq_product_metrics.id_run' => $run_ids},
              {  join                        => ['iseq_product_metrics'],
              }
  );
  $util->rs_list2fixture(q[400-].$tname, [$rs], $path);
  
  ############   iseq_run_lane_metrics  #######################
  $tname = q[IseqRunLaneMetric];
  $rs = $real->resultset($tname)->search(
              { 'iseq_product_metrics.id_run' => $run_ids},
              {  join                        => ['iseq_product_metrics'],
              }
  );
  $util->rs_list2fixture(q[400-].$tname, [$rs], $path);
}

1;

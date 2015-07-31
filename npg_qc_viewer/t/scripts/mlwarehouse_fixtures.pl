use strict;
use warnings;
use npg_warehouse::Schema;
use t::util;

my $util = t::util->new();
my $path = q[t/data/fixtures/mlwarehouse];
my $real = WTSI::DNAP::Warehouse::Schema->connect();
my $tname;
my $rs;

############   iseq_flowcell  #######################
$tname = q[IseqFlowcell];
my $run_ids = [3500, 3323, 3965, 4025, 1272, 4950];
$rs = $real->resultset($tname)->search(
            {id_run => $run_ids}
);
$util->rs_list2fixture($tname, [$rs], $path);

1;
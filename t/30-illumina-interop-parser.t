use strict;
use warnings;
use Test::More tests => 7;
use Test::Exception;

use_ok('npg_qc::illumina::interop::parser');

{
  my $p = npg_qc::illumina::interop::parser->new(
    runfolder_path => 't/data/autoqc',
  );
  throws_ok { $p->parse() }
    qr/InterOp files directory t\/data\/autoqc\/InterOp does not exist/,
    'error when InterOp directory does not exist';

  $p = npg_qc::illumina::interop::parser->new(
    interop_path => 't/data/autoqc',
  );
  throws_ok { $p->parse() }
    qr/t\/data\/autoqc\/TileMetricsOut.bin does not exist/,
    'error when InterOp directory does not exist';  
}

{
  my $p = npg_qc::illumina::interop::parser->new(
    runfolder_path => 't/data/autoqc/180626_A00538_0008_AH5HJ5DSXX'
  );
  isa_ok($p, 'npg_qc::illumina::interop::parser');
  lives_ok { $p->parse() } 'parsing is OK';

  $p = npg_qc::illumina::interop::parser->new(
    interop_path => 't/data/autoqc/180626_A00538_0008_AH5HJ5DSXX/InterOp'
  );
  my $data;
  lives_ok { $data = $p->parse() } 'parsing is OK';
 
  my %lane_metrics = ();
  $lane_metrics{'aligned_mean'}->{1}->{1}        = 0.731618344783783;
  $lane_metrics{'aligned_mean'}->{1}->{4}        = 0.724208116531372;
  $lane_metrics{'aligned_stdev'}->{1}->{1}       = 0;
  $lane_metrics{'aligned_stdev'}->{1}->{4}       = 0;
  $lane_metrics{'cluster_count_mean'}->{1}       = 4091904;
  $lane_metrics{'cluster_count_pf_mean'}->{1}    = 2875527;
  $lane_metrics{'cluster_count_pf_stdev'}->{1}   = 0;
  $lane_metrics{'cluster_count_pf_total'}->{1}   = 2875527;
  $lane_metrics{'cluster_count_stdev'}->{1}      = 0;
  $lane_metrics{'cluster_count_total'}->{1}      = 4091904;
  $lane_metrics{'cluster_density_mean'}->{1}     = 2961263.95700836;
  $lane_metrics{'cluster_density_pf_mean'}->{1}  = 2080985.88395631;
  $lane_metrics{'cluster_density_pf_stdev'}->{1} = 0;
  $lane_metrics{'cluster_density_stdev'}->{1}    = 0;
  $lane_metrics{'cluster_pf_mean'}->{1}          = 70.2735694679054;
  $lane_metrics{'cluster_pf_stdev'}->{1}         = 0;
  $lane_metrics{'occupied_mean'}->{1}            = 76.2887887887888;
  $lane_metrics{'occupied_stdev'}->{1}           = 0;

  is_deeply($data, \%lane_metrics, 'result for a paired run');
}

1;




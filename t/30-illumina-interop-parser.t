use strict;
use warnings;
use Test::More tests => 5;
use Test::Exception;

use npg_qc::autoqc::results::illumina_analysis;

use_ok('npg_qc::autoqc::checks::illumina_analysis');

{
  my $check = npg_qc::autoqc::checks::illumina_analysis->new(
    rpt_list  => '26261:1;26261:2;26261:3;26261:4',
    path      => 't/data/autoqc/180626_A00538_0008_AH5HJ5DSXX'
  );
  isa_ok($check, 'npg_qc::autoqc::checks::illumina_analysis');
  lives_ok {$check->execute()} 'executing is OK';
 
  my $e = npg_qc::autoqc::checks::illumina_analysis->new(
    qc_in       => 't/data/autoqc/180626_A00538_0008_AH5HJ5DSXX',
    rpt_list    => '26261:1;26261:2;26261:3;26261:4',
    input_files => [qw(t/data/autoqc/180626_A00538_0008_AH5HJ5DSXX/InterOp/TileMetricsOut.bin
                       t/data/autoqc/180626_A00538_0008_AH5HJ5DSXX/InterOp/ExtendedTileMetricsOut.bin)],
  );

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

  $e->result->lane_metrics(\%lane_metrics);
  is_deeply($check->result, $e->result, 'result object for a paired run');
}

{
  my $check = npg_qc::autoqc::checks::illumina_analysis->new(
    position  => 1,
    qc_in     => 't/data/autoqc/181218_MS8_27801_A_MS7510412-300V2',
    id_run    => 27801, 
  );
  throws_ok {$check->execute}
    qr/t\/data\/autoqc\/181218_MS8_27801_A_MS7510412-300V2\/InterOp\/TileMetricsOut.bin does not exist at/,
    'error when input not found';
}

1;




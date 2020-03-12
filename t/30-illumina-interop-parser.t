use strict;
use warnings;
use Test::More tests => 8;
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

{
  my $data = npg_qc::illumina::interop::parser->new(
    interop_path => 't/data/autoqc/200114_HS40_32710_A_H72VGBCX3//InterOp'
  )->parse();

  my $expected = {
          'aligned_stdev' => {
                               '2' => {
                                        '4' => '0.925762434191217',
                                        '1' => '0.635884419339578'
                                      },
                               '1' => {
                                        '4' => '0.920239873819165',
                                        '1' => '0.70644559859785'
                                      }
                             },
          'aligned_mean' => {
                              '2' => {
                                       '1' => '29.9058274030685',
                                       '4' => '28.7443390488625'
                                     },
                              '1' => {
                                       '4' => '28.7805494368076',
                                       '1' => '29.8132521212101'
                                     }
                            },
          'cluster_pf_stdev' => {
                                  '1' => '0.767446115466015',
                                  '2' => '0.842222836938437'
                                },
          'cluster_density_pf_stdev' => {
                                          '2' => '57843.5445597774',
                                          '1' => '56319.2818033671'
                                        },
          'cluster_pf_mean' => {
                                 '1' => '89.3431932013788',
                                 '2' => '88.8107128348017'
                               },
          'cluster_count_stdev' => {
                                     '1' => '194232.546545831',
                                     '2' => '200791.066382471'
                                   },
          'cluster_density_pf_mean' => {
                                         '1' => '538884.636230469',
                                         '2' => '558776.424316406'
                                       },
          'cluster_density_mean' => {
                                      '1' => '603599.771972656',
                                      '2' => '629635.858398438'
                                    },
          'cluster_count_total' => {
                                     '2' => '116611547',
                                     '1' => '111789540'
                                   },
          'cluster_density_stdev' => {
                                       '1' => '67119.67769162',
                                       '2' => '69386.0654817665'
                                     },
          'cluster_count_mean' => {
                                    '1' => '1746711.5625',
                                    '2' => '1822055.421875'
                                  },
          'cluster_count_pf_mean' => {
                                       '2' => '1617000.734375',
                                       '1' => '1559437.375'
                                     },
          'cluster_count_pf_total' => {
                                        '1' => '99803992',
                                        '2' => '103488047'
                                      },
          'cluster_count_pf_stdev' => {
                                        '2' => '167389.050383036',
                                        '1' => '162978.117109493'
                                      }
        };

  is_deeply($data, $expected, 'result for multiple tiles');
}

1;

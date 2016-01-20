use strict;
use warnings;
use Test::More tests => 39;
use Test::Exception;
use File::Temp qw/tempdir/;
use File::Path qw/make_path/;
use Test::Warn;

use t::util;

BEGIN {
  local $ENV{'HOME'} = 't/data';
  use_ok('npg_qc_viewer::Util::FileFinder'); #we need to get listing of staging areas from a local conf file
}

my $util = t::util->new();
local $ENV{CATALYST_CONFIG} = $util->config_path;
local $ENV{TEST_DIR}        = $util->staging_path;

my $schemas;
lives_ok { $schemas = $util->test_env_setup()}  'test db created and populated';
use_ok 'Test::WWW::Mechanize::Catalyst', 'npg_qc_viewer';
my $mech = Test::WWW::Mechanize::Catalyst->new;

#This prefix impacts the javascript part of the application. Update as 
#necessary.
my $title_prefix = qq[NPG SeqQC v${npg_qc_viewer::VERSION}: ];

my $qc_schema = $schemas->{'qc'};
$qc_schema->resultset('TagMetrics')->create({
  id_run => 4950,
  position =>1,
  path => 'some path',
  reads_pf_count=>'{"11":53,"21":750446,"7":1580,"2":89,"17":144186,"22":1383279,"1":299626,"18":10582,"0":349419,"13":3601072,"16":93071,"23":1057688,"6":895140,"3":356213,"9":116,"12":1180579,"15":1366955,"14":965235,"20":1044190,"8":190608,"4":433648,"24":560261,"10":965361,"19":1647412,"5":122}'
});

{
  my $base = tempdir(UNLINK => 1);
  my $path = $base . q[/archive];
  my $run_folder = q[150621_MS6_04099_A_MS2023387-050V2];
  make_path $path.q[/].$run_folder;
  
  my $npg   = $schemas->{'npg'};
  
  foreach my $id_run ( 4950 ) {
    my $values = { id_run               => $id_run,
                   batch_id             => 4178,
                   folder_name          => $run_folder,
                   folder_path_glob     => $path, 
                   id_instrument        => 30,
                   id_instrument_format => 4,
                   is_paired            => 1,
                   priority             => 1,
                   team                 => '"joint"' 
    };
    
    my $row = $npg->resultset("Run")->create($values); #Insert new entity
    $row->set_tag(7, 'staging');
  }
}

{
  my $url = q[http://localhost/checks/runs/4025];
  warning_like{$mech->get_ok($url)} qr/Use of uninitialized value \$id in exists/,
                                      'Expected warning for id found';
  $mech->title_is($title_prefix . q[Results for run 4025 (current run status: qc complete)]);
  $mech->content_contains('Back to Run 4025');
  $mech->content_contains(152);  # num cycles
  $mech->content_contains('NT28560W'); #library name
  $mech->content_contains('run 4025 lane 1'); #side menu link
  $mech->content_contains('Run annotations');
  $mech->content_contains('Lane annotations');
  $mech->content_contains('NPG QC');
  $mech->content_contains('20,442,728'); #for total qxYield

  $schemas->{npg}->resultset('RunStatus')->search({id_run => 4025, iscurrent => 1},)->update({ id_user => 64, id_run_status_dict => 26, });
  warning_like{$mech->get_ok($url)} qr/Use of uninitialized value \$id in exists/,
                                      'Expected warning for id found';
  $mech->title_is($title_prefix . q[Results for run 4025 (current run status: qc in progress, taken by mg8)]);
}

subtest 'Test for page title - this affects javascript part too.' => sub {
  plan tests => 6;

  #This tests is linked with the javascript part of the application
  #which uses the title of the page to check if manual qc GUI should
  #be shown. 
  my $url = q[http://localhost/checks/runs/10107];
  warnings_like{$mech->get_ok($url)} [ { carped => qr/run 10107 no longer on staging/ }, 
                                                    qr/Use of uninitialized value \$id in exists/, ],
                                        'Expected warning for run folder found';
  $mech->title_is($title_prefix . q[Results for run 10107 (current run status: qc in progress, taken by melanie)]);
  $schemas->{npg}->resultset('RunStatus')->search({id_run => 10107, iscurrent => 1},)->update({ id_user => 50, id_run_status_dict => 25, });
  warnings_like{$mech->get_ok($url)} [ { carped => qr/run 10107 no longer on staging/ }, 
                                                    qr/Use of uninitialized value \$id in exists/, ],
                                        'Expected warning for run folder found';
  $mech->title_is($title_prefix . q[Results for run 10107 (current run status: qc on hold, taken by melanie)]);
};

subtest 'Test for summary table id - affects export to CSV.' => sub {
  plan tests => 4;

  my $url = q[http://localhost/checks/runs/10107];

  warnings_like{$mech->get_ok($url)} [ { carped => qr/run 10107 no longer on staging/ }, 
                                                    qr/Use of uninitialized value \$id in exists/, ],
                                        'Expected warning for run folder found';
  $mech->content_contains(q[<table id="results_summary"]);
  $mech->content_like(qr/.+<a [^>]+ id=\'summary_to_csv\' [^>]+>[\w\s]+<\/a>.+/mxi);
};

subtest 'Run 4025 Lane 1' => sub {
  plan tests => 10;
  my $url = q[http://localhost/checks/runs?run=4025&lane=1];
  warning_like{$mech->get_ok($url)} qr/Use of uninitialized value \$id in exists/,
                                        'Expected warning for id found';
  $mech->title_is($title_prefix . q[Results (lanes) for runs 4025 lanes 1]);
  $mech->content_contains(152);  # num cycles
  $mech->content_contains('NT28560W'); #library name
  $mech->content_lacks('NA18623pd2a 1');
  $mech->content_contains('run 4025 lane 1'); #side menu link
  $mech->content_lacks('run 4025 lane 2'); #side menu link
  $mech->content_lacks('Run annotations');
  $mech->content_lacks('Lane annotations');
};

subtest 'Library links for run + lane SE' => sub {
  plan tests => 6;

  my $where = { 'iseq_product_metrics.id_run' => 4025, 'me.id_pool_lims' => 'NT28560W'};
  my $rs = $schemas->{'mlwh'}->resultset('IseqFlowcell')->search($where, { join => 'iseq_product_metrics', });

  while (my $flowcell = $rs->next ) {
    $flowcell->update({'legacy_library_id' => 111111,});
  }

  my $url = q[http://localhost/checks/runs?run=4025&lane=1];
  warning_like{$mech->get_ok($url)} qr/Use of uninitialized value \$id in exists/,
                                        'Expected warning for id found';
  $mech->content_contains(152);  # num cycles
  $mech->content_contains('NT28560W'); #library name
  $mech->content_contains('assets/111111'); #SE link
  $mech->content_contains('libraries?id=NT28560W'); #seqqc link for library
};

subtest 'Library links lane Clarity' => sub {
  plan tests => 5;

  my $where = { 'iseq_product_metrics.id_run' => 4025, 'me.id_pool_lims' => 'NT28560W'};
  my $rs = $schemas->{'mlwh'}->resultset('IseqFlowcell')->search($where, { join => 'iseq_product_metrics', });

  while (my $flowcell = $rs->next ) {
    $flowcell->update({'legacy_library_id' => 111111, 'id_lims' => 'C_GCLP'});
  }

  my $url = q[http://localhost/checks/runs?run=4025&lane=1];
  warning_like{$mech->get_ok($url)} qr/Use of uninitialized value \$id in exists/,
                                        'Expected warning for id found';
  $mech->content_contains(152);  # num cycles
  $mech->content_contains('NT28560W'); #library name
  $mech->content_contains('search?scope=Container&query=NT28560W'); #SE link
};

subtest 'Page title for run + show all' =>  sub {
  plan tests => 3;
  my $url = q[http://localhost/checks/runs?run=4025&show=all];
  warning_like{$mech->get_ok($url)} qr/Use of uninitialized value \$id in exists/,
                                       'Expected warning for id found';
  $mech->title_is($title_prefix . q[Results (all) for runs 4025]);
};

{
  my $url = q[http://localhost/checks/runs?run=4025&show=plexes];
  warning_like{$mech->get_ok($url)} qr/Use of uninitialized value \$id in exists/,
                                       'Expected warning for id found';
  $mech->title_is($title_prefix . q[Results (plexes) for runs 4025]);
  $mech->content_lacks(152);  # num cycles
  $mech->content_lacks('NT28560W'); #library name
}


{
  my $url = q[http://localhost/checks/runs?run=4950&lane=1&show=lanes];
  warnings_like{$mech->get_ok($url)} [ { carped => qr/Failed to get runfolder location/ }, 
                                                    qr/Use of uninitialized value \$id in exists/, ],
                                        'Expected warning for run folder found';
  $mech->title_is($title_prefix . q[Results (lanes) for runs 4950 lanes 1]);
  $mech->content_contains(224);  # num cycles
  $mech->content_contains('NT207849B'); #library name
  $mech->content_contains('run 4950 lane 1'); #side menu link
  $mech->content_lacks('run 4950 lane 2'); #side menu link
}

subtest 'Test for run + lane + plexes' => sub {
  plan tests => 10;
  my $url = q[http://localhost/checks/runs?run=4950&lane=1&show=plexes];
  warnings_like{$mech->get_ok($url)} [ { carped => qr/Failed to get runfolder location/ }, 
                                                    qr/Use of uninitialized value \$id in exists/, ],
                                        'Expected warning for run folder found';
  $mech->title_is($title_prefix . q[Results (plexes) for runs 4950 lanes 1]);
  $mech->content_contains(224);  # num cycles
  $mech->content_contains('Help'); #side menu link
  $mech->content_contains('NT207825Q'); #library name for tag 1
  $mech->content_contains('ATCACGTT'); #tag sequence
  $mech->content_contains('Tag'); #column name
  $mech->content_lacks('NT207849B'); #library name for lane
  $mech->content_unlike(qr/run\ 4950\ lane\ 1$/);
};

subtest 'Test for run + lane + show all' => sub {
  plan tests => 16;
  my $url = q[http://localhost/checks/runs?run=4950&lane=1&show=all];
  warnings_like{$mech->get_ok($url)} [ { carped => qr/Failed to get runfolder location/ }, 
                                                    qr/Use of uninitialized value \$id in exists/, ],
                                        'Expected warning for run folder found';
  $mech->title_is($title_prefix . q[Results (all) for runs 4950 lanes 1]);
  $mech->content_contains('Page Top');
  $mech->content_contains('Back to Run 4950');
  $mech->content_contains(224);  # num cycles
  $mech->content_contains('NT207849B'); #library name for lane
  $mech->content_contains('ATCACGTT'); #tag sequence
  $mech->content_contains('Tag'); #column name
  $mech->content_contains('NT207825Q'); #library name for tag 1

  my @menu = (
              'Page Top',
              '20',
              '0'
             );
  foreach my $menu_item (@menu) {
    warnings_like{ $mech->follow_link_ok({text => $menu_item}, qq[follow '$menu_item' menu item]) } 
      [ { carped => qr/Failed to get runfolder location/ }, 
                    qr/Use of uninitialized value \$id in exists/, ],
                      'Expected warning for run folder found';  
  }
};

subtest 'Tag metrics as first check in summary table' =>  sub {
  plan tests => 29;
  for my $i (6 .. 8) {
    $qc_schema->resultset(q[TagMetrics])->create({
      id_run=>4025,
      position=>$i,
      path=>'some path',
      metrics_file=>'some other path',
      barcode_tag_name=>'BC',
      tags=>'{"33":"GGACTCCTGCGTAAGA","32":"TCCTGAGCCTAAGCCT","90":"GTAGAGGACTCTCTAT","63":"CAGAGAGGAAGGAGTA","21":"AGGCAGAAGTAAGGAG","71":"GCTACGCTAAGGAGTA","7":"TAAGGCGAAAGGAGTA","80":"CGAGGCTGCTAAGCCT","26":"TCCTGAGCCTCTCTAT","18":"AGGCAGAACTCTCTAT","72":"GCTACGCTCTAAGCCT","16":"CGTACTAGCTAAGCCT","44":"TAGGCATGAGAGTAGA","55":"CTCTCTACAAGGAGTA","84":"AAGAGGCAAGAGTAGA","74":"CGAGGCTGCTCTCTAT","27":"TCCTGAGCTATCCTCT","95":"GTAGAGGAAAGGAGTA","57":"CAGAGAGGGCGTAAGA","61":"CAGAGAGGGTAAGGAG","20":"AGGCAGAAAGAGTAGA","92":"GTAGAGGAAGAGTAGA","89":"GTAGAGGAGCGTAAGA","10":"CGTACTAGCTCTCTAT","31":"TCCTGAGCAAGGAGTA","35":"GGACTCCTTATCCTCT","11":"CGTACTAGTATCCTCT","91":"GTAGAGGATATCCTCT","78":"CGAGGCTGACTGCATA","48":"TAGGCATGCTAAGCCT","87":"AAGAGGCAAAGGAGTA","93":"GTAGAGGAGTAAGGAG","77":"CGAGGCTGGTAAGGAG","65":"GCTACGCTGCGTAAGA","29":"TCCTGAGCGTAAGGAG","50":"CTCTCTACCTCTCTAT","39":"GGACTCCTAAGGAGTA","64":"CAGAGAGGCTAAGCCT","58":"CAGAGAGGCTCTCTAT","41":"TAGGCATGGCGTAAGA","12":"CGTACTAGAGAGTAGA","15":"CGTACTAGAAGGAGTA","81":"AAGAGGCAGCGTAAGA","52":"CTCTCTACAGAGTAGA","60":"CAGAGAGGAGAGTAGA","56":"CTCTCTACCTAAGCCT","73":"CGAGGCTGGCGTAAGA","66":"GCTACGCTCTCTCTAT","45":"TAGGCATGGTAAGGAG","86":"AAGAGGCAACTGCATA","76":"CGAGGCTGAGAGTAGA","19":"AGGCAGAATATCCTCT","62":"CAGAGAGGACTGCATA","54":"CTCTCTACACTGCATA","67":"GCTACGCTTATCCTCT","70":"GCTACGCTACTGCATA","68":"GCTACGCTAGAGTAGA","17":"AGGCAGAAGCGTAAGA","2":"TAAGGCGACTCTCTAT","1":"TAAGGCGAGCGTAAGA","88":"AAGAGGCACTAAGCCT","30":"TCCTGAGCACTGCATA","82":"AAGAGGCACTCTCTAT","25":"TCCTGAGCGCGTAAGA","28":"TCCTGAGCAGAGTAGA","83":"AAGAGGCATATCCTCT","75":"CGAGGCTGTATCCTCT","40":"GGACTCCTCTAAGCCT","14":"CGTACTAGACTGCATA","69":"GCTACGCTGTAAGGAG","59":"CAGAGAGGTATCCTCT","49":"CTCTCTACGCGTAAGA","24":"AGGCAGAACTAAGCCT","53":"CTCTCTACGTAAGGAG","79":"CGAGGCTGAAGGAGTA","22":"AGGCAGAAACTGCATA","42":"TAGGCATGCTCTCTAT","0":"NNNNNNNNNNNNNNNN","46":"TAGGCATGACTGCATA","23":"AGGCAGAAAAGGAGTA","13":"CGTACTAGGTAAGGAG","96":"GTAGAGGACTAAGCCT","6":"TAAGGCGAACTGCATA","85":"AAGAGGCAGTAAGGAG","36":"GGACTCCTAGAGTAGA","3":"TAAGGCGATATCCTCT","94":"GTAGAGGAACTGCATA","9":"CGTACTAGGCGTAAGA","51":"CTCTCTACTATCCTCT","47":"TAGGCATGAAGGAGTA","8":"TAAGGCGACTAAGCCT","38":"GGACTCCTACTGCATA","4":"TAAGGCGAAGAGTAGA","34":"GGACTCCTCTCTCTAT","37":"GGACTCCTGTAAGGAG","43":"TAGGCATGTATCCTCT","5":"TAAGGCGAGTAAGGAG"}',
      reads_count=>'{"33":"119376","32":"142193","90":"132583","63":"186664","21":"153060","71":"166921","7":"145199","80":"117465","26":"133030","18":"111433","72":"151956","16":"133147","44":"150986","55":"190582","84":"102667","74":"109584","27":"168685","95":"150676","57":"127996","61":"174887","20":"115955","92":"119791","89":"128491","10":"113253","31":"59427","35":"205115","11":"129996","91":"125664","78":"90247","48":"169","87":"143257","93":"150735","77":"143490","65":"111339","29":"132549","50":"178184","39":"162015","64":"146314","58":"113773","41":"136800","12":"97765","15":"133034","81":"111522","52":"236427","60":"178442","56":"129990","73":"105406","66":"162282","45":"181955","86":"138899","76":"114356","19":"143457","62":"172766","54":"208157","67":"114485","70":"179849","68":"154810","17":"99934","2":"109893","1":"89436","88":"83253","30":"207167","82":"117448","25":"107407","28":"158302","83":"130622","75":"114135","40":"124558","14":"129524","69":"157266","59":"168893","49":"88734","24":"129420","53":"204679","79":"132134","22":"173884","42":"143489","0":"218304","46":"187218","23":"142374","13":"138087","96":"126950","6":"136562","85":"159416","36":"160525","3":"124640","94":"141206","9":"110615","51":"136508","47":"184300","8":"100966","38":"199177","4":"100374","34":"141453","37":"185272","43":"206581","5":"135309"}',
      reads_pf_count=>'{"33":"119376","32":"142193","90":"132583","63":"186664","21":"153060","71":"166921","7":"145199","80":"117465","26":"133030","18":"111433","72":"151956","16":"133147","44":"150986","55":"190582","84":"102667","74":"109584","27":"168685","95":"150676","57":"127996","61":"174887","20":"115955","92":"119791","89":"128491","10":"113253","31":"59427","35":"205115","11":"129996","91":"125664","78":"90247","48":"169","87":"143257","93":"150735","77":"143490","65":"111339","29":"132549","50":"178184","39":"162015","64":"146314","58":"113773","41":"136800","12":"97765","15":"133034","81":"111522","52":"236427","60":"178442","56":"129990","73":"105406","66":"162282","45":"181955","86":"138899","76":"114356","19":"143457","62":"172766","54":"208157","67":"114485","70":"179849","68":"154810","17":"99934","2":"109893","1":"89436","88":"83253","30":"207167","82":"117448","25":"107407","28":"158302","83":"130622","75":"114135","40":"124558","14":"129524","69":"157266","59":"168893","49":"88734","24":"129420","53":"204679","79":"132134","22":"173884","42":"143489","0":"218304","46":"187218","23":"142374","13":"138087","96":"126950","6":"136562","85":"159416","36":"160525","3":"124640","94":"141206","9":"110615","51":"136508","47":"184300","8":"100966","38":"199177","4":"100374","34":"141453","37":"185272","43":"206581","5":"135309"}',
      perfect_matches_count=>'{"33":"112113","32":"139678","90":"129771","63":"175503","21":"144003","71":"157064","7":"137306","80":"115566","26":"130773","18":"109174","72":"149188","16":"130667","44":"140999","55":"179228","84":"95953","74":"107860","27":"165144","95":"141261","57":"120224","61":"165039","20":"107516","92":"110911","89":"120080","10":"111155","31":"54895","35":"200773","11":"126921","91":"122484","78":"85314","48":"120","87":"135347","93":"141679","77":"135735","65":"104574","29":"124385","50":"174869","39":"152621","64":"143448","58":"111272","41":"128622","12":"91047","15":"125137","81":"104982","52":"220315","60":"166808","56":"127602","73":"99169","66":"159557","45":"171767","86":"131231","76":"106858","19":"139923","62":"162968","54":"196268","67":"111712","70":"169655","68":"144338","17":"93341","2":"108505","1":"84364","88":"81937","30":"195671","82":"115750","25":"100855","28":"147713","83":"128252","75":"111679","40":"122215","14":"122150","69":"148472","59":"164866","49":"83074","24":"126710","53":"193333","79":"124679","22":"163519","42":"141076","0":"0","46":"176674","23":"133479","13":"130309","96":"124351","6":"129569","85":"150833","36":"149769","3":"122590","94":"132627","9":"103785","51":"133282","47":"173449","8":"99562","38":"188070","4":"94029","34":"138922","37":"175104","43":"202379","5":"128520"}',
      perfect_matches_pf_count=>'{"33":"112113","32":"139678","90":"129771","63":"175503","21":"144003","71":"157064","7":"137306","80":"115566","26":"130773","18":"109174","72":"149188","16":"130667","44":"140999","55":"179228","84":"95953","74":"107860","27":"165144","95":"141261","57":"120224","61":"165039","20":"107516","92":"110911","89":"120080","10":"111155","31":"54895","35":"200773","11":"126921","91":"122484","78":"85314","48":"120","87":"135347","93":"141679","77":"135735","65":"104574","29":"124385","50":"174869","39":"152621","64":"143448","58":"111272","41":"128622","12":"91047","15":"125137","81":"104982","52":"220315","60":"166808","56":"127602","73":"99169","66":"159557","45":"171767","86":"131231","76":"106858","19":"139923","62":"162968","54":"196268","67":"111712","70":"169655","68":"144338","17":"93341","2":"108505","1":"84364","88":"81937","30":"195671","82":"115750","25":"100855","28":"147713","83":"128252","75":"111679","40":"122215","14":"122150","69":"148472","59":"164866","49":"83074","24":"126710","53":"193333","79":"124679","22":"163519","42":"141076","0":"0","46":"176674","23":"133479","13":"130309","96":"124351","6":"129569","85":"150833","36":"149769","3":"122590","94":"132627","9":"103785","51":"133282","47":"173449","8":"99562","38":"188070","4":"94029","34":"138922","37":"175104","43":"202379","5":"128520"}',
      one_mismatch_matches_count=>'{"33":"7263","32":"2515","90":"2812","63":"11161","21":"9057","71":"9857","7":"7893","80":"1899","26":"2257","18":"2259","72":"2768","16":"2480","44":"9987","55":"11354","84":"6714","74":"1724","27":"3541","95":"9415","57":"7772","61":"9848","20":"8439","92":"8880","89":"8411","10":"2098","31":"4532","35":"4342","11":"3075","91":"3180","78":"4933","48":"49","87":"7910","93":"9056","77":"7755","65":"6765","29":"8164","50":"3315","39":"9394","64":"2866","58":"2501","41":"8178","12":"6718","15":"7897","81":"6540","52":"16112","60":"11634","56":"2388","73":"6237","66":"2725","45":"10188","86":"7668","76":"7498","19":"3534","62":"9798","54":"11889","67":"2773","70":"10194","68":"10472","17":"6593","2":"1388","1":"5072","88":"1316","30":"11496","82":"1698","25":"6552","28":"10589","83":"2370","75":"2456","40":"2343","14":"7374","69":"8794","59":"4027","49":"5660","24":"2710","53":"11346","79":"7455","22":"10365","42":"2413","0":"0","46":"10544","23":"8895","13":"7778","96":"2599","6":"6993","85":"8583","36":"10756","3":"2050","94":"8579","9":"6830","51":"3226","47":"10851","8":"1404","38":"11107","4":"6345","34":"2531","37":"10168","43":"4202","5":"6789"}',
      one_mismatch_matches_pf_count=>'{"33":"7263","32":"2515","90":"2812","63":"11161","21":"9057","71":"9857","7":"7893","80":"1899","26":"2257","18":"2259","72":"2768","16":"2480","44":"9987","55":"11354","84":"6714","74":"1724","27":"3541","95":"9415","57":"7772","61":"9848","20":"8439","92":"8880","89":"8411","10":"2098","31":"4532","35":"4342","11":"3075","91":"3180","78":"4933","48":"49","87":"7910","93":"9056","77":"7755","65":"6765","29":"8164","50":"3315","39":"9394","64":"2866","58":"2501","41":"8178","12":"6718","15":"7897","81":"6540","52":"16112","60":"11634","56":"2388","73":"6237","66":"2725","45":"10188","86":"7668","76":"7498","19":"3534","62":"9798","54":"11889","67":"2773","70":"10194","68":"10472","17":"6593","2":"1388","1":"5072","88":"1316","30":"11496","82":"1698","25":"6552","28":"10589","83":"2370","75":"2456","40":"2343","14":"7374","69":"8794","59":"4027","49":"5660","24":"2710","53":"11346","79":"7455","22":"10365","42":"2413","0":"0","46":"10544","23":"8895","13":"7778","96":"2599","6":"6993","85":"8583","36":"10756","3":"2050","94":"8579","9":"6830","51":"3226","47":"10851","8":"1404","38":"11107","4":"6345","34":"2531","37":"10168","43":"4202","5":"6789"}',
      matches_percent=>'{"33":"0.008749","32":"0.010421","90":"0.009716","63":"0.01368","21":"0.011217","71":"0.012233","7":"0.010641","80":"0.008608","26":"0.009749","18":"0.008166","72":"0.011136","16":"0.009758","44":"0.011065","55":"0.013967","84":"0.007524","74":"0.008031","27":"0.012362","95":"0.011042","57":"0.00938","61":"0.012817","20":"0.008498","92":"0.008779","89":"0.009417","10":"0.0083","31":"0.004355","35":"0.015032","11":"0.009527","91":"0.009209","78":"0.006614","48":"0.000012","87":"0.010499","93":"0.011047","77":"0.010516","65":"0.00816","29":"0.009714","50":"0.013058","39":"0.011873","64":"0.010723","58":"0.008338","41":"0.010025","12":"0.007165","15":"0.009749","81":"0.008173","52":"0.017327","60":"0.013077","56":"0.009526","73":"0.007725","66":"0.011893","45":"0.013335","86":"0.010179","76":"0.008381","19":"0.010513","62":"0.012661","54":"0.015255","67":"0.00839","70":"0.01318","68":"0.011345","17":"0.007324","2":"0.008054","1":"0.006554","88":"0.006101","30":"0.015182","82":"0.008607","25":"0.007871","28":"0.011601","83":"0.009573","75":"0.008364","40":"0.009128","14":"0.009492","69":"0.011525","59":"0.012377","49":"0.006503","24":"0.009485","53":"0.015","79":"0.009684","22":"0.012743","42":"0.010516","0":"0.015999","46":"0.01372","23":"0.010434","13":"0.01012","96":"0.009304","6":"0.010008","85":"0.011683","36":"0.011764","3":"0.009134","94":"0.010348","9":"0.008106","51":"0.010004","47":"0.013507","8":"0.007399","38":"0.014597","4":"0.007356","34":"0.010366","37":"0.013578","43":"0.015139","5":"0.009916"}',
      matches_pf_percent=>'{"33":"0.008749","32":"0.010421","90":"0.009716","63":"0.01368","21":"0.011217","71":"0.012233","7":"0.010641","80":"0.008608","26":"0.009749","18":"0.008166","72":"0.011136","16":"0.009758","44":"0.011065","55":"0.013967","84":"0.007524","74":"0.008031","27":"0.012362","95":"0.011042","57":"0.00938","61":"0.012817","20":"0.008498","92":"0.008779","89":"0.009417","10":"0.0083","31":"0.004355","35":"0.015032","11":"0.009527","91":"0.009209","78":"0.006614","48":"0.000012","87":"0.010499","93":"0.011047","77":"0.010516","65":"0.00816","29":"0.009714","50":"0.013058","39":"0.011873","64":"0.010723","58":"0.008338","41":"0.010025","12":"0.007165","15":"0.009749","81":"0.008173","52":"0.017327","60":"0.013077","56":"0.009526","73":"0.007725","66":"0.011893","45":"0.013335","86":"0.010179","76":"0.008381","19":"0.010513","62":"0.012661","54":"0.015255","67":"0.00839","70":"0.01318","68":"0.011345","17":"0.007324","2":"0.008054","1":"0.006554","88":"0.006101","30":"0.015182","82":"0.008607","25":"0.007871","28":"0.011601","83":"0.009573","75":"0.008364","40":"0.009128","14":"0.009492","69":"0.011525","59":"0.012377","49":"0.006503","24":"0.009485","53":"0.015","79":"0.009684","22":"0.012743","42":"0.010516","0":"0.015999","46":"0.01372","23":"0.010434","13":"0.01012","96":"0.009304","6":"0.010008","85":"0.011683","36":"0.011764","3":"0.009134","94":"0.010348","9":"0.008106","51":"0.010004","47":"0.013507","8":"0.007399","38":"0.014597","4":"0.007356","34":"0.010366","37":"0.013578","43":"0.015139","5":"0.009916"}',
      max_mismatches_param=>'1',
      min_mismatch_delta_param=>'1',
      max_no_calls_param=>'2',
      pass=>'1',
      info=>'{"Check":"npg_qc::autoqc::checks::tag_metrics","Check_version":"59.6"}',
      tag_index=>-1
    });
  }

  for my $i (-1 .. 50) {
    for my $j (6 .. 8) {
      my $obj = $qc_schema->resultset(q[QXYield])->update_or_new({
        id_run=>4025,
        position=>$j,
        path=>q[some path],
        filename1=>q[some filename],
        filename2=>q[other filename],
        threshold_quality=>'20',
        yield1=>'1952450',
        yield2=>'1891079',
        comments=>'Unrecognised instrument model',
        info=>'{"Check":"npg_qc::autoqc::checks::qX_yield","Check_version":"59.6"}',
        tag_index=>$i
      });
      if (!$obj->in_storage) {
        $obj->insert;
      }
    }
  }

  my $url = q[http://localhost/checks/runs?db_lookup=1&run=4025&lane=8&show=all];
  warning_like{$mech->get_ok($url)} qr/Use of uninitialized value \$id in exists/,
                                       'Expected warning for id found';
  $mech->title_is($title_prefix . q[Results (all) for runs 4025 lanes 8]);
  $mech->content_contains(q[<th rowspan="2">Tag</th><th>tag<br />metrics<br/>], q[Tag metrics next to tag column]); 
  $mech->content_contains(q[<td class="tag_info"><a href="#4025:8"></a></td> <td class="check_summary passed"><a href="#tmc_4025:8">98.40</a><br />], 
                          q[Original content for tag metrics for lane level]);
  $mech->content_contains(q[<a href="#4025:8:1">1</a></td>          <td class="check_summary outcome_unknown">0.66], q[Tag metrics for tag 1]);
  $mech->content_contains(q[<a href="#4025:8:47">47</a></td>          <td class="check_summary outcome_unknown">1.35], q[Tag metrics for tag 47]);
  $mech->content_contains(q[<a href="#4025:8:48">48</a></td>          <td class="check_summary failed">0.00], q[Tag metrics for tag 48]);
  $mech->content_contains(q[<a href="#4025:8:49">49</a></td>          <td class="check_summary outcome_unknown">0.65], q[Tag metrics for tag 49]);
  $mech->content_contains(q[<a href="#4025:8:0">0</a></td>          <td class="check_summary outcome_unknown">1.60], q[Tag metrics for tag 0]);
  
  $url = q[http://localhost/checks/runs?db_lookup=1&run=4025&lane=6&lane=7&lane=8&show=all];
  warning_like{$mech->get_ok($url)} qr/Use of uninitialized value \$id in exists/,
                                         'Expected warning for id found';
  $mech->title_is($title_prefix . q[Results (all) for runs 4025 lanes 6 7 8]);
  $mech->content_contains(q[<th rowspan="2">Tag</th><th>tag<br />metrics<br/>], q[Tag metrics next to tag column]);
  for my $i (6 .. 8) {
    $mech->content_contains(qq[<td class="tag_info"><a href="#4025:$i"></a></td> <td class="check_summary passed"><a href="#tmc_4025:$i">98.40</a><br />], 
                            q[Original content for tag metrics for lane level]);
    $mech->content_contains(qq[<th rowspan="2">Tag</th><th>tag<br />metrics<br/>], q[Tag metrics next to tag column]);
    $mech->content_contains(qq[<a href="#4025:$i:1">1</a></td>          <td class="check_summary outcome_unknown">0.66], qq[Tag metrics for lane $i tag 1]);
    $mech->content_contains(qq[<a href="#4025:$i:48">48</a></td>          <td class="check_summary failed">0.00], qq[Tag metrics for lane $i tag 48]);
    $mech->content_contains(qq[<a href="#4025:$i:0">0</a></td>          <td class="check_summary outcome_unknown">1.60], qq[Tag metrics for lane $i tag 0]);
  }
};

subtest 'R&D' => sub {
  plan tests => 4;
  my $where = { 'iseq_product_metrics.id_run' => 4025, };
  my $rs = $schemas->{'mlwh'}->resultset('IseqFlowcell')->search($where, { join => 'iseq_product_metrics', });
  
  while (my $flowcell = $rs->next ) {
    $flowcell->update({'is_r_and_d' => 1,});
  }

  my $url = q[http://localhost/checks/runs/4025];
  warnings_like{$mech->get_ok($url)} [ qr/Use of uninitialized value \$id in exists/, ],
                                        'Expected warning for id found';
  $mech->content_contains('9272">random_sample_name</a></span><span class="watermark">R&amp;D</span>'); #library name with R&D watermark
  $mech->content_contains('9286">random_sample_name</a></span><span class="watermark">R&amp;D</span>'); #library name with R&D watermark
};

1;



use strict;
use warnings;
use Test::More tests => 51;
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
$util->modify_logged_user_method();

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
$qc_schema->resultset('TagMetrics')->create({id_run => 4950, position =>1, path => 'some path'});

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
  $mech->get_ok($url);
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
  $mech->get_ok($url);
  $mech->title_is($title_prefix . q[Results for run 4025 (current run status: qc in progress, taken by mg8)]);
}

subtest 'Test for page title - this affects javascript part too.' => sub {
  plan tests => 6;

  #This tests is linked with the javascript part of the application
  #which uses the title of the page to check if manual qc GUI should
  #be shown. 
  my $url = q[http://localhost/checks/runs/10107];
  warnings_like{$mech->get_ok($url)} [ { carped => qr/run 10107 no longer on staging/ } ],
                                        'Expected warning for run folder found';
  $mech->title_is($title_prefix . q[Results for run 10107 (current run status: qc in progress, taken by melanie)]);
  $schemas->{npg}->resultset('RunStatus')->search({id_run => 10107, iscurrent => 1},)
                 ->update({ id_user => 50, id_run_status_dict => 25, });
  warnings_like{$mech->get_ok($url)} [ { carped => qr/run 10107 no longer on staging/ }, ],
                                        'Expected warning for run folder found';
  $mech->title_is($title_prefix . q[Results for run 10107 (current run status: qc on hold, taken by melanie)]);
};

subtest 'Test for summary table id - affects export to CSV.' => sub {
  plan tests => 4;

  my $url = q[http://localhost/checks/runs/10107];
  warnings_like{$mech->get_ok($url)} [ { carped => qr/run 10107 no longer on staging/ } ],
                                        'Expected warning for run folder found';
  $mech->content_contains(q[<table id="results_summary"]);
  $mech->content_like(qr/.+<a [^>]+ id=\'summary_to_csv\' [^>]+>[\w\s]+<\/a>.+/mxi);
};

subtest 'Run 4025 Lane 1' => sub {
  plan tests => 9;
  my $url = q[http://localhost/checks/runs?run=4025&lane=1];
  $mech->get_ok($url);
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
  plan tests => 5;

  my $where = { 'iseq_product_metrics.id_run' => 4025, 'me.id_pool_lims' => 'NT28560W'};
  my $rs = $schemas->{'mlwh'}->resultset('IseqFlowcell')
                             ->search($where, { join => 'iseq_product_metrics', });
  while (my $flowcell = $rs->next ) {
    $flowcell->update({'legacy_library_id' => 111111,});
  }

  my $url = q[http://localhost/checks/runs?run=4025&lane=1];
  $mech->get_ok($url);
  $mech->content_contains(152);  # num cycles
  $mech->content_contains('NT28560W'); #library name
  $mech->content_contains('assets/111111'); #SE link
  $mech->content_contains('libraries?id=NT28560W'); #seqqc link for library
};

subtest 'Library links lane Clarity' => sub {
  plan tests => 4;

  my $where = { 'iseq_product_metrics.id_run' => 4025, 'me.id_pool_lims' => 'NT28560W'};
  my $rs = $schemas->{'mlwh'}->resultset('IseqFlowcell')
                   ->search($where, { join => 'iseq_product_metrics', });
  while (my $flowcell = $rs->next ) {
    $flowcell->update({'legacy_library_id' => 111111, 'id_lims' => 'C_GCLP'});
  }

  my $url = q[http://localhost/checks/runs?run=4025&lane=1];
  $mech->get_ok($url);
  $mech->content_contains(152);  # num cycles
  $mech->content_contains('NT28560W'); #library name
  $mech->content_contains('search?scope=Container&query=NT28560W'); #link to Clarity LIMs
};

subtest 'Page title for run + show all' =>  sub {
  plan tests => 2;
  my $url = q[http://localhost/checks/runs?run=4025&show=all];
  $mech->get_ok($url);
  $mech->title_is($title_prefix . q[Results (all) for runs 4025]);
};

{
  my $url = q[http://localhost/checks/runs?run=4025&show=plexes];
  $mech->get_ok($url);
  $mech->title_is($title_prefix . q[Results (plexes) for runs 4025]);
  $mech->content_lacks(152);  # num cycles
  $mech->content_lacks('NT28560W'); #library name
}

{
  my $url = q[http://localhost/checks/runs?run=4950&lane=1&show=lanes];
  warnings_like{$mech->get_ok($url)} [ { carped => qr/Failed to get runfolder location/ } ],
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
  warnings_like{$mech->get_ok($url)} [ { carped => qr/Failed to get runfolder location/ } ],
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

{
  my $url = q[http://localhost/checks/runs?run=4950&lane=1&show=all];
  warnings_like{$mech->get_ok($url)} [ { carped => qr/Failed to get runfolder location/ } ],
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
      [ { carped => qr/Failed to get runfolder location/ } ],
                      'Expected warning for run folder found';  
  }
}

subtest 'R&D visual cue' => sub {
  plan tests => 3;
  my $where = { 'iseq_product_metrics.id_run' => 4025, };
  my $rs = $schemas->{'mlwh'}->resultset('IseqFlowcell')->search($where, { join => 'iseq_product_metrics', });
  while (my $flowcell = $rs->next ) {
    $flowcell->update({'is_r_and_d' => 1,});
  }

  my $url = q[http://localhost/checks/runs/4025];
  $mech->get_ok($url);
  $mech->content_contains('9272">random_sample_name</a></span><span class="watermark">R&amp;D</span>'); #library name with R&D watermark
  $mech->content_contains('9286">random_sample_name</a></span><span class="watermark">R&amp;D</span>'); #library name with R&D watermark
};

subtest 'Displaying user info' => sub {
  plan tests => 8;

  my $url = q[http://localhost/checks/runs/4025];
  $mech->get_ok($url);
  $mech->content_contains('Not logged in');
  $mech->content_lacks('(mqc)');
 
  $mech->get_ok($url . '?user=tiger&password=secret');
  $mech->content_contains('Logged in as tiger');
  $mech->content_lacks('(mqc)');

  $mech->get_ok($url . '?user=cat&password=secret');
  $mech->content_contains('Logged in as cat (mqc)');
};

1;



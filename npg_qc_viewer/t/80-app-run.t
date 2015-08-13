use strict;
use warnings;
use Test::More tests => 75;
use Test::Exception;
use File::Temp qw/tempdir/;
use File::Path qw/make_path/;
use Test::Warn;

use Test::WWW::Mechanize::Catalyst;

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

{
  my $base = tempdir(UNLINK => 1);
  my $path = $base . q[/archive];
  my $run_folder = q[150621_MS6_04099_A_MS2023387-050V2];
  make_path $path.q[/].$run_folder;
  
  my $npg   = $schemas->{npg};
  
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
                                      'Expected warning for run folder found';
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
                                      'Expected warning for run folder found';
  $mech->title_is($title_prefix . q[Results for run 4025 (current run status: qc in progress, taken by mg8)]);
}

{ #This tests is linked with the javascript part of the application
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
}

{
  my $url = q[http://localhost/checks/runs?run=4025&lane=1];
  warning_like{$mech->get_ok($url)} qr/Use of uninitialized value \$id in exists/,
                                        'Expected warning for run folder found';
  $mech->title_is($title_prefix . q[Results (lanes) for runs 4025 lanes 1]);
  $mech->content_contains(152);  # num cycles
  $mech->content_contains('NT28560W'); #library name
  $mech->content_lacks('NA18623pd2a 1');
  $mech->content_contains('run 4025 lane 1'); #side menu link
  $mech->content_lacks('run 4025 lane 2'); #side menu link
  $mech->content_lacks('Run annotations');
  $mech->content_lacks('Lane annotations');
}

{
  my $url = q[http://localhost/checks/runs?run=4025&show=all];
  warning_like{$mech->get_ok($url)} qr/Use of uninitialized value \$id in exists/,
                                       'Expected warning for run folder found';
  $mech->title_is($title_prefix . q[Results (all) for runs 4025]);
}

{
  my $url = q[http://localhost/checks/runs?run=4025&show=plexes];
  warning_like{$mech->get_ok($url)} qr/Use of uninitialized value \$id in exists/,
                                       'Expected warning for run folder found';
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

{
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
}

{
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
}

subtest 'R&D' => sub {
  plan tests => 5;
  my $where = { 'iseq_product_metrics.id_run' => 4025, };
  my $rs = $schemas->{'mlwh'}->resultset('IseqFlowcell')->search($where, { join => 'iseq_product_metrics', });
  
  while (my $flowcell = $rs->next ) {
    $flowcell->update({'is_r_and_d' => 1,});
  }

  my $url = q[http://localhost/checks/runs/4025];
  warnings_like{$mech->get_ok($url)} [ qr/Use of uninitialized value \$id in exists/, ],
                                        'Expected warning for run folder found';
  $mech->content_contains('NT28560W</span></a> <span class="watermark">R&amp;D</span>'); #library name with R&D watermark
  $mech->content_contains('NT28561A</span></a> <span class="watermark">R&amp;D</span>'); #library name with R&D watermark
  $mech->content_lacks('Illumina phiX</span></a> <span class="watermark">R&amp;D</span>');
};

1;



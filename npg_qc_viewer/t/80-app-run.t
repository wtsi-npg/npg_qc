use strict;
use warnings;
use Test::More tests => 60;
use Test::Exception;

use Test::WWW::Mechanize::Catalyst;

use t::util;

my $util = t::util->new();
local $ENV{CATALYST_CONFIG} = $util->config_path;
local $ENV{TEST_DIR}        = $util->staging_path;

my $schemas;
lives_ok { $schemas = $util->test_env_setup()}  'test db created and populated';
use_ok 'Test::WWW::Mechanize::Catalyst', 'npg_qc_viewer';
my $mech = Test::WWW::Mechanize::Catalyst->new;

lives_ok {$schemas->{wh}->resultset('NpgInformation')->search({id_run => 3323, position => [5, 6]},)->update({ is_dev => 1, }) }
   'is_dev column successfully updated - test prerequisite';

{
  my $url = q[http://localhost/checks/runs/4025];
  $mech->get_ok($url);
  $mech->title_is(q[Results for run 4025 (current run status: qc complete)]);
  $mech->content_contains('Back to Run 4025');
  $mech->content_contains(152);  # num cycles
  $mech->content_contains('B1267_Exp4 1'); #library name
  $mech->content_contains('run 4025 lane 1'); #side menu link
  $mech->content_contains('Run annotations');
  $mech->content_contains('Lane annotations');
  $mech->content_contains('NPG QC');

  $schemas->{npg}->resultset('RunStatus')->search({id_run => 4025, iscurrent => 1},)->update({ id_user => 64, id_run_status_dict => 26, });
  $mech->get_ok($url);
  $mech->title_is(q[Results for run 4025 (current run status: qc in progress, taken by mg8)]);
}

{
  my $url = q[http://localhost/checks/runs?run=4025&lane=1];
  $mech->get_ok($url);
  $mech->title_is(q[Results (lanes) for runs 4025 lanes 1]);
  $mech->content_contains(152);  # num cycles
  $mech->content_contains('B1267_Exp4 1'); #library name
  $mech->content_lacks('NA18623pd2a 1');
  $mech->content_contains('run 4025 lane 1'); #side menu link
  $mech->content_lacks('run 4025 lane 2'); #side menu link
  $mech->content_lacks('Run annotations');
  $mech->content_lacks('Lane annotations');
}

{
  my $url = q[http://localhost/checks/runs?run=4025&show=all];
  $mech->get_ok($url);
  $mech->title_is(q[Results (all) for runs 4025]);
}

{
  my $url = q[http://localhost/checks/runs?run=4025&show=plexes];
  $mech->get_ok($url);
  $mech->title_is(q[Results (plexes) for runs 4025]);
  $mech->content_lacks(152);  # num cycles
  $mech->content_lacks('B1267_Exp4 1'); #library name
}


{
  my $url = q[http://localhost/checks/runs?run=4950&lane=1&show=lanes];
  $mech->get_ok($url);
  $mech->title_is(q[Results (lanes) for runs 4950 lanes 1]);
  $mech->content_contains(224);  # num cycles
  $mech->content_contains('24plex_1000Genomes-B1-FIN-6.6.10'); #library name
  $mech->content_contains('run 4950 lane 1'); #side menu link
  $mech->content_lacks('run 4950 lane 2'); #side menu link
}

{
  my $url = q[http://localhost/checks/runs?run=4950&lane=1&show=plexes];
  $mech->get_ok($url);
  $mech->title_is(q[Results (plexes) for runs 4950 lanes 1]);
  $mech->content_contains(224);  # num cycles
  $mech->content_contains('Help'); #side menu link
  $mech->content_contains('HG00367-B 400398'); #library name
  $mech->content_contains('ATCACGTT'); #tag sequence
  $mech->content_contains('Tag'); #column name
  $mech->content_lacks('24plex_1000Genomes-B1-FIN-6.6.10'); #library name
  $mech->content_unlike(qr/run\ 4950\ lane\ 1$/);
}

{
  my $url = q[http://localhost/checks/runs?run=4950&lane=1&show=all];
  $mech->get_ok($url);
  $mech->title_is(q[Results (all) for runs 4950 lanes 1]);
  $mech->content_contains('Page Top');
  $mech->content_contains('Back to Run 4950');
  $mech->content_contains(224);  # num cycles
  $mech->content_contains('HG00367-B 400398'); #library name
  $mech->content_contains('ATCACGTT'); #tag sequence
  $mech->content_contains('Tag'); #column name
  $mech->content_contains('24plex_1000Genomes-B1-FIN-6.6.10'); #library name

  my @menu = (
              'Page Top',
              '20',
              '0'
             );
  foreach my $menu_item (@menu) {
    $mech->follow_link_ok({text => $menu_item}, qq[follow '$menu_item' menu item]);  
  }
}

{
  my $url = q[http://localhost/checks/runs/3323];
  $mech->get_ok($url);
  $mech->content_contains('PH25-C_300 1</span></a><span class="watermark">R&amp;D</span>'); #library name with R&D watermark
  $mech->content_contains('PD71-C_300 1</span></a><span class="watermark">R&amp;D</span>'); #library name with R&D watermark
  $mech->content_lacks('Illumina phiX</span></a><span class="watermark">R&amp;D</span>');
}

1;



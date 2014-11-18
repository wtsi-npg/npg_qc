use strict;
use warnings;
use Test::More tests => 13;
use Test::Exception;

use Test::WWW::Mechanize::Catalyst;

use t::util;

my $util = t::util->new();
local $ENV{CATALYST_CONFIG} = $util->config_path;
local $ENV{TEST_DIR}        = $util->staging_path;

my $mech;


{
  lives_ok { $util->test_env_setup()}  'test db created and populated';
  use_ok 'Test::WWW::Mechanize::Catalyst', 'npg_qc_viewer';
  $mech = Test::WWW::Mechanize::Catalyst->new;
}


{
  my $url = q[http://localhost/checks/studies];
  $mech->get_ok($url);
  $mech->title_is(q[List of studies]);
  my @projects =  (
                    '1000Genomes-B1-CHB',
                    '1000Genomes-B1-LWK',
                    'CGP Exome Resequencing',
                    'HumanEvolution2',
                    'ICR Exome Resequencing',
                    'Plasmodium ovale genome sequencing',
                    'Renal Cancer Exome',
                    'Anopheles gambiae genome variation 1',
                    '1000Genomes-B1-FIN'
                  );


  foreach my $project (@projects) {
      $mech->content_contains($project);
  }
}

use strict;
use warnings;
use Test::More tests => 18;
use Test::Exception;
use Carp;

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
  my $url = q[http://localhost/checks/libraries];
  $mech->get_ok($url);
  $mech->title_is(q[List of libraries]);
  my @libs      = ( 
               'AC0001C 1',
               'AKR_J_SLX_500_DSS_2',
               'B1267_Exp4 1',
               'B3006_Exp4 1',
               'B3009_Exp4 1',
               'Exp2_PD2126a_WGA 1',
               'Exp2_PD2126b_WGA 1',
               'NA18545pd2a 1',
               'NA18563pd2a 1',
               'NA18623pd2a 1',
               'NA18633pda 1',
               'OX008_dscDNA 1',
               'phiX CT1462-2 1',
               'AC0001C 1'
                  );


  foreach my $lib (@libs) {
      $mech->content_contains($lib);
  }
}



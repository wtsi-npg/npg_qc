use strict;
use warnings;
use Test::More tests => 6;
use Test::Exception;
use Test::Warn;

use Test::WWW::Mechanize::Catalyst;

local $ENV{'HOME'}='t/data';
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
  my $sample_id = 9184;
  my $url = qq[http://localhost/checks/samples/$sample_id];
  warnings_like{$mech->get_ok($url)} [qr/Use of uninitialized value \$id in exists/,], 
                                    'Expected warning for runfolder location';
  $mech->title_is(q[Sample 'Exp2_PD2126a_WGA']);
  $mech->content_contains(q[Exp2_PD2126a_WGA 1 &lt;&lt; Exp2_PD2126a_WGA &lt;&lt; Renal Cancer Exome]);
}

1;


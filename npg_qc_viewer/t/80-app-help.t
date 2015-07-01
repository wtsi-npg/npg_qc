use strict;
use warnings;
use Test::More tests => 8;
use Test::Exception;
use Test::WWW::Mechanize::Catalyst;
use Test::Warn;

use t::util;

my $util = t::util->new();
local $ENV{CATALYST_CONFIG} = $util->config_path;

my $mech;

{
  lives_ok { $util->test_env_setup() }  'test db created and populated';
  use_ok 'Test::WWW::Mechanize::Catalyst', 'npg_qc_viewer';
  $mech = Test::WWW::Mechanize::Catalyst->new;
}

{
  my $url = qq[http://localhost/checks];
  warning_like{$mech->get_ok($url)} qr/Use of uninitialized value \$id in exists/, 
                                    'Expected warning for non initialised id';
  $mech->title_is(q[NPG SeqQC - visualization and datamining for sequence quality control]);
}

{
  my $url = qq[http://localhost/checks/about];
  warning_like{$mech->get_ok($url)} qr/Use of uninitialized value \$id in exists/, 
                                    'Expected warning for non initialised id';
  $mech->title_is(q[NPG SeqQC: about QC checks]);
}

1;


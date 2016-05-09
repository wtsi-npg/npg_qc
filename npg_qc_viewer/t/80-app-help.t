use strict;
use warnings;
use lib 't/lib';
use Test::More tests => 6;
use Test::Exception;
use Test::WWW::Mechanize::Catalyst;

use t::util;
my $util = t::util->new();
$util->modify_logged_user_method();
local $ENV{CATALYST_CONFIG} = $util->config_path;

{
  lives_ok { $util->test_env_setup() }  'test db created and populated';
  use_ok 'Test::WWW::Mechanize::Catalyst', 'npg_qc_viewer';
  my $mech = Test::WWW::Mechanize::Catalyst->new;

  $mech->get_ok(q[http://localhost/checks]);
  $mech->title_is(qq[NPG SeqQC v${npg_qc_viewer::VERSION}]);

  $mech->get_ok(q[http://localhost/checks/about]);
  $mech->title_is(qq[NPG SeqQC v${npg_qc_viewer::VERSION}: about QC checks]);
}

1;


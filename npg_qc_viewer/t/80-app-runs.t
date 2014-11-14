use strict;
use warnings;
use Test::More tests => 5;
use Test::Exception;

use Test::WWW::Mechanize::Catalyst;

use t::util;

my $util = t::util->new();
local $ENV{CATALYST_CONFIG} = $util->config_path;
local $ENV{TEST_DIR}        = $util->staging_path;

lives_ok { $util->test_env_setup()}  'test db created and populated';
use_ok 'Test::WWW::Mechanize::Catalyst', 'npg_qc_viewer';
my $mech = Test::WWW::Mechanize::Catalyst->new;

{
  my $url = q[http://localhost/checks/runs];
  $mech->get_ok($url);
  $mech->title_is(q[List of runs]);
  my @runs =  qw(4025 );

  foreach my $run (@runs) {
      $mech->content_contains($run);
  }
}

1;

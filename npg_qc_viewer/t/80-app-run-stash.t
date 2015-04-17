use strict;
use warnings;
use Test::More tests => 24;
use Test::Exception;
use HTTP::Headers;
use HTTP::Request::Common;

use t::util;

my $util = t::util->new();
local $ENV{CATALYST_CONFIG} = $util->config_path;
local $ENV{TEST_DIR}        = $util->staging_path;

my @keys = qw/4025:1 4025:2 4025:3 4025:4 4025:5 4025:6 4025:7 4025:8/;

{
  my $schemas;
  lives_ok { $schemas = $util->test_env_setup()}  'test db created and populated';
  my $npgqc = $schemas->{qc};
  is($npgqc->resultset('QXYield')->count, 42);
  use_ok 'Catalyst::Test', 'npg_qc_viewer';
}

{
  my @urls = (q[/checks/runs/4025], q[/checks/runs-from-staging/4025]);

       foreach my $url (@urls) {

  my $req = GET($url);
  my ($res, $c) = ctx_request($req);
  ok ($res, $req->uri . q[ requested]);
  ok ($res->is_success, 'request succeeded');
  my $rl_map = $c->stash->{rl_map};
  my $count = 0;

  foreach my $key (keys %{$rl_map}) {
    $count += $rl_map->{$key}->size();
  }

  my $expected_count = $url eq q[/checks/runs/4025] ? 48 : 54;
  is($count, $expected_count, qq[$expected_count result objects in stash for run 4025]);
  is (join(' ', sort keys %{$rl_map}), join(' ', @keys), 'keys in the rl map');

  			}	
}

{
  my @urls = (q[/checks/runs?run=4025&show=all], q[/checks/runs?run=4025&show=lanes]);
       foreach my $url (@urls) {
  my $req = GET($url);
  my ($res, $c) = ctx_request($req);
  ok ($res, $req->uri . q[ requested]);
  ok ($res->is_success, 'request succeeded');
  my $rl_map = $c->stash->{rl_map};
  is (join(' ', sort keys %{$rl_map}), join(' ', @keys), 'keys in the rl map');
  			}	
}

{
  my $req = GET(q[/checks/runs?run=4025&show=plexes]);
  my ($res, $c) = ctx_request($req);
  ok ($res, $req->uri . q[ requested]);
  ok ($res->is_success, 'request succeeded');
  ok ($c->stash->{rl_map}, 'rl map defined');
  is (scalar keys %{$c->stash->{rl_map}}, 0, 'rl map empty');	
}

{
  my $req = GET(q[/checks/runs/4099]);
  my ($res, $c) = ctx_request($req);
  ok ($res, $req->uri . q[ requested]);
  ok ($res->is_success, 'request succeeded');
  my $rl_map = $c->stash->{rl_map};
  my $count = 0;
  foreach my $key (keys %{$rl_map}) {
    $count += $rl_map->{$key}->size();
  }
  is($count, 48, '48 result objects in stash for run 4099');
}

1;



  


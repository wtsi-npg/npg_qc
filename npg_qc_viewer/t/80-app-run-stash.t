use strict;
use warnings;
use lib 't/lib';
use Test::More tests => 24;
use Test::Exception;
use HTTP::Request::Common;
use File::Temp qw/tempdir/;
use File::Path qw/make_path/;

use t::util;

my $schemas;

my $util = t::util->new();
$util->modify_logged_user_method();

lives_ok { $schemas = $util->test_env_setup()}  'test db created and populated';
local $ENV{'CATALYST_CONFIG'} = $util->config_path;
local $ENV{'TEST_DIR'}        = $util->staging_path;
local $ENV{'HOME'}            = 't/data';

use_ok 'Catalyst::Test', 'npg_qc_viewer';

my @keys = qw/4025:1 4025:2 4025:3 4025:4 4025:5 4025:6 4025:7 4025:8/;

{
  my $base = tempdir(UNLINK => 1);
  my $path = $base . q[/archive];
  my $run_folder = q[150621_MS6_04099_A_MS2023387-050V2];
  make_path $path.q[/].$run_folder;
  
  my $npgqc = $schemas->{qc};
  my $npg   = $schemas->{npg};
  
  my $values = { id_run               => 4099,
                 batch_id             => 4178,
                 folder_name          => $run_folder,
                 folder_path_glob     => $path, 
                 id_instrument        => 30,
                 id_instrument_format => 4,
                 is_paired            => 1,
                 priority             => 1,
                 team                 => '"joint"'};
  my $row = $npg->resultset("Run")->create($values); #Insert new entity
  $row->set_tag(7, 'staging');
  
  is($npgqc->resultset('QXYield')->count, 42);
}

{
  my @urls = qw(/checks/runs/4025 /checks/runs-from-staging/4025);
  foreach my $url (@urls) {
    my ($res, $c) = ctx_request(GET($url));
    ok ($res, qq[$url requested]);
    ok ($res->is_success, 'request succeeded');
    my $rl_map = $c->stash->{rl_map};
    my $count = 0;
    foreach my $key (keys %{$rl_map}) {
      $count += $rl_map->{$key}->size();
    }
    my $expected_count = $url eq q[/checks/runs/4025] ? 40 : 46;
    is($count, $expected_count, qq[$expected_count result objects in stash for run 4025]);
    is (join(' ', sort keys %{$rl_map}), join(' ', @keys), 'keys in the rl map');
  }	
}

{
  my @urls = qw(/checks/runs?run=4025&show=all /checks/runs?run=4025&show=lanes);
       foreach my $url (@urls) {
  my ($res, $c) = ctx_request(GET($url));
  ok ($res, qq[$url requested]);
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
  is($count, 40, '40 result objects in stash for run 4099');
}

1;



  


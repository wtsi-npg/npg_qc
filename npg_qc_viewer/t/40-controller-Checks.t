use strict;
use warnings;
use Test::More tests => 47;
use Test::Exception;
use t::util;
use Test::Warn;
use File::Temp qw/tempdir/;
use File::Path qw/make_path/;

my $util = t::util->new();
local $ENV{CATALYST_CONFIG} = $util->config_path;
local $ENV{TEST_DIR}        = $util->staging_path;

my $schemas;
use_ok 'npg_qc_viewer::Controller::Checks';
lives_ok { $schemas = $util->test_env_setup()}  'test db created and populated';
use_ok 'Catalyst::Test', 'npg_qc_viewer';

{
  my $base = tempdir(UNLINK => 1);
  my $path = $base . q[/archive];
  my $run_folder = q[150621_MS6_04099_A_MS2023387-050V2];
  make_path $path.q[/].$run_folder;
  
  my $npgqc = $schemas->{qc};
  my $npg   = $schemas->{npg};
  
  my $values = { id_run               => 4099,
                 actual_cycle_count   => 76,
                 batch_id             => 4178,
                 expected_cycle_count => 76,
                 folder_name          => $run_folder,
                 folder_path_glob     => $path, 
                 id_instrument        => 30,
                 id_instrument_format => 4,
                 id_run_pair          => 0,
                 is_paired            => 1,
                 priority             => 1,
                 team                 => '"joint"'};
  my $row = $npg->resultset("Run")->create($values); #Insert new entity
  $row->set_tag(7, 'staging');
  
  my @urls = ();
  push @urls,  '/checks';
  push @urls,  '/checks/about';
  push @urls,  '/checks/runs/4025';
  push @urls,  '/checks/runs?run=4025';
  push @urls,  '/checks/runs?run=4025&lane=1&lane=4';
  push @urls,  '/checks/runs?run=4025&run=4099&lane=1&lane=4';
  push @urls,  '/checks/runs?run=4025&lane=1&show=all';
  push @urls,  '/checks/runs?run=4025&lane=1&show=lanes';
  push @urls,  '/checks/runs?run=4025&lane=1&show=plexes';
  push @urls,  '/checks/runs-from-staging/4025';
  push @urls,  '/checks/path?path=t/data/staging/IL2/analysis/123456_IL2_1234/Latest_Summary/archive/qc';
  push @urls,  '/checks/samples/3055';
  push @urls,  '/checks/libraries?name=AC0001C+1';
  push @urls,  '/checks/studies/544';

  foreach my $url (@urls) {
    ok( request($url)->is_success, qq[$url request succeeds] );
  }
}

{
  my @urls = ();
  push @urls,  '/checks/runs/hgdjhgjgh';
  push @urls,  '/checks/runs/0';
  push @urls,  '/checks/runs/0.8';
  push @urls,  '/checks/runs/1.8';
  push @urls,  '/checks/runs/-7';
  push @urls,  '/checks/samples/dfsfs';
  push @urls,  '/checks/studies/dfsfs';
  push @urls,  '/checks/runs-from-staging/dfsfs';

  my $responce;
  foreach my $url (@urls) {
    lives_ok { $responce = request($url) } qq[$url request] ;
    ok( $responce->is_error, qq[responce is an error] );
    is( $responce->code, 404, 'error code is 404' );
  }
}

{
  my @urls = ();
  push @urls,  '/checks/samples/1';
  push @urls,  '/checks/studies/25';
  my $responce;
  foreach my $url (@urls) {
    lives_ok { $responce = request($url) } qq[$url request] ;
    ok( $responce->is_error, qq[responce is an error] );
    is( $responce->code, 404, 'error code is 404' );
  }
}

1;




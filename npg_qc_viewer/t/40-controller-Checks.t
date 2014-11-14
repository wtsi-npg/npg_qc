use strict;
use warnings;
use Test::More tests => 63;
use Test::Exception;
use t::util;

my $util = t::util->new();
local $ENV{CATALYST_CONFIG} = $util->config_path;
local $ENV{TEST_DIR}        = $util->staging_path;

use_ok 'npg_qc_viewer::Controller::Checks';
lives_ok { $util->test_env_setup()}  'test db created and populated';
use_ok 'Catalyst::Test', 'npg_qc_viewer';

{
  my @urls = ();
  push @urls,  '/checks';
  push @urls,  '/checks/about';
  push @urls,  '/checks/runs';
  push @urls,  '/checks/runs/4025';
  push @urls,  '/checks/runs?run=4025';
  push @urls,  '/checks/runs?run=4025&lane=1&lane=4';
  push @urls,  '/checks/runs?run=4025&run=4099&lane=1&lane=4';
  push @urls,  '/checks/runs?run=4025&lane=1&show=all';
  push @urls,  '/checks/runs?run=4025&lane=1&show=lanes';
  push @urls,  '/checks/runs?run=4025&lane=1&show=plexes';
  push @urls,  '/checks/runs-from-staging/4025';
  push @urls,  '/checks/path?path=t/data/staging/IL2/analysis/123456_IL2_1234/Latest_Summary/archive/qc';
  push @urls,  '/checks/studies';
  push @urls,  '/checks/samples/3055';
  push @urls,  '/checks/libraries';
  push @urls,  '/checks/libraries?name=AC0001C+1';
  push @urls,  '/checks/week';
  push @urls,  '/checks/weeks/3';
  push @urls,  '/checks/samples';
  push @urls,  '/checks/studies/544';
  push @urls,  '/checks/people';
  push @urls,  q[/checks/people?weeks=1];
  push @urls,  q[/checks/people?name=none&name=some];
  push @urls,  q[/checks/people?name=aef&weeks=3];

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
  push @urls,  '/checks/weeks/dfsfs';
  push @urls,  '/checks/people?weeks=dfsfs';

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




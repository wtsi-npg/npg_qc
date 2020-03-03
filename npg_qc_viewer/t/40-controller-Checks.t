use strict;
use warnings;
use lib 't/lib';
use Test::More tests => 8;
use Test::Exception;
use File::Temp qw/tempdir/;
use File::Path qw/make_path/;

use t::util;

BEGIN {
  local $ENV{'HOME'} = 't/data';
}

my $util = t::util->new();
$util->modify_logged_user_method();

local $ENV{CATALYST_CONFIG} = $util->config_path;

my $schemas;
use_ok 'npg_qc_viewer::Controller::Checks';

subtest 'Basic url checks' => sub {
  plan tests => 4;
  throws_ok { npg_qc_viewer::Controller::Checks::_base_url_no_port()}
    qr/Need base url/, 'error if no arg supplied';
  is (npg_qc_viewer::Controller::Checks::_base_url_no_port('http://some.dot.com'),
    'http://some.dot.com', 'no port, no slash - no change');
  is (npg_qc_viewer::Controller::Checks::_base_url_no_port('http://some.dot.com/'),
    'http://some.dot.com', 'no port - just strip last slash');
  is (npg_qc_viewer::Controller::Checks::_base_url_no_port('http://some.dot.com:8080/'),
    'http://some.dot.com', 'have port - strip port and slash');
};

subtest 'Testing titles' => sub {
  plan tests => 2;
  my $prefix = qq[NPG SeqQC v${npg_qc_viewer::Controller::Checks::VERSION}];
  is (npg_qc_viewer::Controller::Checks::_get_title(), $prefix, 'simple title');
  is (npg_qc_viewer::Controller::Checks::_get_title('for this and that'),
    $prefix . ': for this and that', 'custom title');
};

lives_ok { $schemas = $util->test_env_setup()}  'test db created and populated';
use_ok 'Catalyst::Test', 'npg_qc_viewer';

my $warn_no_paths      = qr/No paths to run folder/; 
my $warn_recalibrated  = qr/Could not find usable recalibrated directory/;

subtest 'All combinations for checks controller' => sub {
  plan tests => 14;
  
  my $base = tempdir(UNLINK => 1);
  my $path = $base . q[/archive];
  my $run_folder = q[150621_MS6_04099_A_MS2023387-050V2];
  make_path $path.q[/].$run_folder;
  
  my $npgqc = $schemas->{'qc'};
  my $npg   = $schemas->{'npg'};
  
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
  push @urls,  '/checks/libraries?id=NT28560W';
  push @urls,  '/checks/pools/NT28560W';
  
  for my $url (@urls) {
    ok(request($url)->is_success, qq[$url request succeeds]);
  }
};

subtest 'All expected 404' => sub {
  plan tests => 24;
  my @urls = ();
  push @urls,  '/checks/runs/hgdjhgjgh';
  push @urls,  '/checks/runs/0';
  push @urls,  '/checks/runs/0.8';
  push @urls,  '/checks/runs/1.8';
  push @urls,  '/checks/runs/-7';
  push @urls,  '/checks/samples/dfsfs';
  push @urls,  '/checks/runs-from-staging/dfsfs';
  push @urls,  '/checks/samples/1';

  my $response;
  foreach my $url (@urls) {
    lives_ok { $response = request($url) } qq[$url request];
    ok( $response->is_error, qq[response is an error] );
    is( $response->code, 404, 'error code is 404' );
  }
};

subtest 'interop files are excluded' => sub {
  plan tests => 5;

  ok(-e 't/data/interop/22833_1.interop.json', 'result exists');
  my $response = request('/checks/path?path=t/data/interop');
  is( $response->code, 200, 'no error' );
  is( $response->content_type, q[text/html], 'HTML content type');
  my $content = $response->content();
  like( $content, qr/Run\ Id/, 'Run header column is present');
  unlike( $content, qr/Run 22833/, 'Result is not present'); 
};

1;




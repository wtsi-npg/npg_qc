use strict;
use warnings;
use Test::More tests => 13;
use Test::Exception;
use Test::MockObject;
use HTTP::Response;
use t::util;

my $util = t::util->new(db_connect => 0, config_path => 't/data/test_app_no_proxy_conf.conf');
local $ENV{CATALYST_CONFIG} = $util->config_path;

{
  use_ok 'Catalyst::Test', 'npg_qc_viewer';
  use_ok 'npg_qc_viewer::Controller::AjaxProxy';
}

{
  my $url = '/ajaxproxy?url=checks';
  my $response;
  lives_ok { $response = request($url) }  qq[$url request] ;
  ok( $response->is_error, q[responce is an error] );
  is( $response->code, 400, q[error code is 400] );
  like ($response->content, qr/URL must be absolute/, 'URL must be absolute error');
}

{
  my $url = '/ajaxproxy?url=http://localhost:90000/checks';
  my $response;
  lives_ok { $response = request($url) }  qq[$url request] ;
  ok( $response->is_error, q[responce is an error] );
  is( $response->code, 500, q[error code is 500] );
  like ($response->content, qr/Can't connect to localhost:90000/, 'cannot connect error');
}

{
  my $content = q[All is well];

  my $mockUA = Test::MockObject->new();
  $mockUA->fake_new(q{LWP::UserAgent});
  $mockUA->set_always('agent', 'NpgSeqQC');
  my $fake_response = HTTP::Response->new(200, '200 Ok', undef, "$content");
  $mockUA->set_always('request', $fake_response);

  my $url = '/ajaxproxy?url=http://mysite/checks';
  my $response;
  lives_ok { $response = request($url) }  qq[$url request] ;
  is( $response->code, 200, q[code is 200] );
  like ($response->content, qr/$content/, 'expected content returned'); 
}

1;



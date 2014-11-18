use strict;
use warnings;
use Test::More tests => 22;
use Test::Exception;
use t::util;

my $util = t::util->new(db_connect => 0);
local $ENV{CATALYST_CONFIG} = $util->config_path;

{
  use_ok 'Catalyst::Test', 'npg_qc_viewer';
  use_ok 'npg_qc_viewer::Controller::AjaxProxy';
}

{
  my $url = '/ajaxproxy';
  my $response;
  lives_ok { $response = request($url) }  qq[$url request] ;
  ok( $response->is_error, q[responce is an error] );
  is( $response->code, 500, q[error code is 500] );
  like ($response->content, qr/url parameter is missing in the request/, 'absent url parameter error');
}

{
  my $url = '/ajaxproxy?url=http:/cvxcv/sanger';
  my $response;
  lives_ok { $response = request($url) }  qq[$url request] ;
  ok( $response->is_error, q[responce is an error] );
  is( $response->code, 403, q[error code is 403] );
  like ($response->content, qr/Wrong URL format/, 'wrong format url  error');
}

{
  my $url = '/ajaxproxy?url=intweb.sanger.ac.uk';
  my $response;
  lives_ok { $response = request($url) }  qq[$url request] ;
  ok( $response->is_error, q[responce is an error] );
  is( $response->code, 403, q[error code is 403] );
  like ($response->content, qr/Wrong URL format/, 'wrong format url error');
}


{
  my $url = '/ajaxproxy?url=http://dodo.com/dodo';
  my $response;
  lives_ok { $response = request($url) }  qq[$url request] ;
  ok( $response->is_error, q[responce is an error] );
  is( $response->code, 403, q[error code is 403] );
  like ($response->content, qr/Cannot proxy to http:\/\/dodo.com\/dodo/, 'cannot proxy error');
}

{
  my $url = '/ajaxproxy?url=ftp://www.npgtest.dodo';
  my $response;
  lives_ok { $response = request($url) }  qq[$url request] ;
  ok( $response->is_error, q[responce is an error] );
  is( $response->code, 403, q[error code is 403] );
  like ($response->content, qr/Cannot proxy to ftp:\/\/www.npgtest.dodo/, 'cannot proxy error');
}

1;



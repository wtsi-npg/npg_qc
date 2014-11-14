use strict;
use warnings;
use Test::More tests => 24;
use Test::Exception;
use t::util;

my $util = t::util->new(db_connect => 0);
local $ENV{CATALYST_CONFIG} = $util->config_path;
local $ENV{TEST_DIR}        = $util->staging_path;

{
  use_ok 'Catalyst::Test', 'npg_qc_viewer';
  use_ok 'npg_qc_viewer::Controller::Root';
}


{
  my $url = '/autocrud/site/admin';
  my $response;
  lives_ok { $response = request($url) }  qq[$url request] ;
  ok( $response->is_error, q[responce is an error] );
  is( $response->code, 401, q[error code is 401] );
  like ($response->content, qr/Login failed/, 'please log in error');
}


{
  my $url = '/autocrud/site/admin?user=dog&password=known';
  my $response;
  lives_ok { $response = request($url) }  qq[$url request] ;
  ok( $response->is_error, q[responce is an error] );
  is( $response->code, 401, q[error code is 401] );
  like ($response->content, qr/Login failed/, 'login failed error');
}


{
  my $url = '/autocrud/site/admin?user=tiger&password=secret';
  my $response;
  lives_ok { $response = request($url) }  qq[$url request] ;
  ok( $response->is_error, q[responce is an error] );
  is( $response->code, 401, q[error code is 401] );
  like ($response->content, qr/User tiger is not a member of admin/, 'not admin error');
}


{
  my $url = '/autocrud/site/admin?user=dog&password=secret@realm=wrong';
  my $response;
  lives_ok { $response = request($url) }  qq[$url request] ;
  ok( $response->is_error, q[responce is an error] );
  is( $response->code, 401, q[error code is 401, ie authorisation was OK] );
  like ($response->content, qr/Login failed/, 'login failed error');
}


{
  my $url = '/autocrud/site/admin?user=dog&password=secret';
  my $response;
  lives_ok { $response = request($url) }  qq[$url request] ;
  ok( $response->is_error, q[responce is an error] );
  is( $response->code, 404, q[error code is 404, ie authorisation was OK] );
}


{
  my $url = '/autocrud/site/admin?user=cat&password=secret';
  my $response;
  lives_ok { $response = request($url) }  qq[$url request] ;
  ok( $response->is_error, q[responce is an error] );
  is( $response->code, 404, q[error code is 404, ie authorisation was OK] );
}


1;



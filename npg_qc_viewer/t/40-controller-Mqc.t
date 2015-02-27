use strict;
use warnings;
use Test::More tests => 13;
use Test::Exception;
use HTTP::Request::Common;
use t::util;

my $util = t::util->new();
local $ENV{CATALYST_CONFIG} = $util->config_path;
local $ENV{TEST_DIR}        = $util->staging_path;

use_ok 'npg_qc_viewer::Controller::Mqc';
lives_ok { $util->test_env_setup()}  'test db created and populated';
use_ok 'Catalyst::Test', 'npg_qc_viewer';

#{
#  my $response;
#  lives_ok { $response = request(HTTP::Request->new('GET', '/mqc/log' )) } 'get request lives';
#  ok( $response->is_error, qq[response is an error] );
#  is( $response->code, 405, 'error code is 405' );
#  is( $response->header('Allow'), 'POST', 'Allow response header is set to POST');
#  like ($response->content, qr/only POST requests are allowed/, 'correct error message');
#}

{#Update
  my $response;
  #TODO move to POST
  lives_ok { $response = request(HTTP::Request->new('GET', '/mqc/update_outcome' )) } 'update run_id + position + outcome + user lives';
  ok($response->is_error, q[update response is error]);
#  is( $response->code, 401, 'error code is 401' );
#  like ($response->content, qr/Login failed/, 'correct error message');
}

{#Current outcome
  my $response;
  lives_ok { $response = request(HTTP::Request->new('GET', '/mqc/get_current_outcome')) } 'get current outcome run_id + position lives';
  ok($response->is_error, q[get_current_outcome response is error]);
# is( $response->code, 401, 'error code is 401' );
#  like ($response->content, qr/Login failed/, 'correct error message');
}

{#All outcomes for id_run
  my $response;
  lives_ok { $response = request(HTTP::Request->new('GET', '/mqc/get_all_outcomes')) } 'get all outcomes run_id';
  ok($response->is_error, q[get_all_outcomes response is error]);
#  is( $response->code, 401, 'error code is 401' );
#  like ($response->content, qr/Login failed/, 'correct error message');
}

{#Test true
  my $response;
  lives_ok { $response = request(HTTP::Request->new('GET', '/mqc/dummy_true')) } 'test true lives';
  is( $response->code, 200, 'dummy_true uccesful request' );
}

#{
#  my $response;
#  lives_ok { $response = request(POST '/mqc/log' ) } 'post request lives';
#  ok( $response->is_error, qq[response is an error] );
#  is( $response->code, 401, 'error code is 401' );
#  like ($response->content, qr/Login failed/, 'correct error message');
#
#  lives_ok { $response = request(POST '/mqc/log?user=frog' ) } 'post request lives';
#  is( $response->code, 401, 'error code is 401' );
#  like ($response->content, qr/Login failed\./, 'correct error message');
#
#  lives_ok { $response = request(POST '/mqc/log?user=tiger&password=secret' ) } 'post request lives';
#  is( $response->code, 401, 'error code is 401' );
#  like ($response->content, qr/User tiger is not a member of manual_qc/, 'correct error message');
#
#  lives_ok { $response = request(POST '/mqc/log?user=cat' ) } 'post request lives';
#  is( $response->code, 401, 'error code is 401' );
#  like ($response->content, qr/Login failed\./, 'correct error message');
#}
#
#{
#  my $url = '/mqc/log?user=cat&password=secret';
#  my $rurl = 'http://seqqc/checks/runs/4025';
#  my $response;
#
#  lives_ok { $response = request(POST $url)}
#    'post request without referer header lives';
#  is( $response->code, 400, 'error code is 400' );
#  like ($response->content, qr/referrer header should be set/, 'correct error message');
#
#  lives_ok { $response = request(POST $url, Referer => 'http://seqqc/checks/runs') }
#    'post request lives';
#  is( $response->code, 500, 'error code is 500' );
#  like ($response->content, qr/failed to get id_run from referrer url/, 'correct error message');
#
#  lives_ok { $response = request(POST $url, Referer => $rurl) }
#    'post request lives';
#  is( $response->code, 400, 'error code is 400' );
#  like ($response->content, qr/status should be defined/, 'correct error message status should be defined');
#
#  lives_ok { $response = request(POST $url, ['status' => 'X' ], Referer => $rurl) }
#    'post request lives with body param';
#  is( $response->code, 400, 'code is 400' );
#  like ($response->content, qr/invalid status X/, 'correct error message "invalid status X"');
# 
#  lives_ok { $response = request(POST $url, ['status' => 'fail'], Referer => $rurl)  }
#    'post request lives with body param';
#  is( $response->code, 400, 'error code is 400' );
#  like ($response->content, qr/lims_object_id should be defined/,
#    'correct error message lims_object_id should be defined');
#
#  lives_ok { $response = request(POST $url, ['status' => 'failed','lims_object_id' => 20 ], Referer => $rurl)  }
#    'post request lives with body param';
#  is( $response->code, 400, 'error code is 400' );
#  like ($response->content, qr/lims_object_type should be defined/,
#    'correct error message lims_object_type should be defined');
#
#  $url = '/mqc/log?user=pipeline&password=secret';
#
#  lives_ok { $response = request(POST $url,
#    [status => 'pass',lims_object_id=>20,lims_object_type=>'lib',batch_id=>4965 ],
#    Referer => $rurl)  } 'post request lives with body param';
#  is( $response->code, 500, 'code is 500' );
#  like ($response->content, qr/One of \(user id, pass-fail decision, position, run id\) is not given/,
#    'correct error message id_run_lane unable to be obtained when no position');
#
#  lives_ok { $response = request(POST $url,
#    [status => 'pass',lims_object_id=>20,lims_object_type=>'lib',batch_id=>4965,position=>1 ],
#    Referer => $rurl)  } 'post request lives with body param';
#  is( $response->code, 200, 'code is 200' );
#  like ($response->content, qr/Manual QC 1 for lib 20 logged by NPG/, 'correct confirmation message');
#}

1;

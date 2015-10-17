use strict;
use warnings;
use Test::More tests => 58;
use Test::Exception;
use HTTP::Request::Common;
use t::util;
use Test::Warn;

my $util = t::util->new();
local $ENV{CATALYST_CONFIG} = $util->config_path;
local $ENV{TEST_DIR}        = $util->staging_path;

use_ok 'npg_qc_viewer::Controller::Mqc';
my $schemas;
lives_ok { $schemas = $util->test_env_setup()}  'test db created and populated';
use_ok 'Catalyst::Test', 'npg_qc_viewer';

{
  my $response;
  lives_ok { $response = request(HTTP::Request->new('GET', '/mqc/update_outcome_lane' )) }
    'update get request lives';
  ok($response->is_error, q[update response is error]);
  is( $response->code, 405, 'error code is 405' );
  like ($response->content, qr/Only POST requests are allowed/, 'correct error message');
}

{
  my $response;
  warning_like{
    lives_ok { $response = request(POST '/mqc/update_outcome_lane' ) } 'post request lives';
  } qr[uninitialized value \$id in exists],
    'Expected warning';
  ok( $response->is_error, qq[response is an error] );
  is( $response->code, 401, 'error code is 401' );
  like ($response->content, qr/Login failed/, 'correct error message');

  lives_ok { $response = request(POST '/mqc/update_outcome_lane?user=frog' ) } 'post request lives';
  is( $response->code, 401, 'error code is 401' );
  like ($response->content, qr/Login failed/, 'correct error message');

  lives_ok { $response = request(POST '/mqc/update_outcome_lane?user=tiger&password=secret' ) } 'post request lives';
  is( $response->code, 401, 'error code is 401' );
  like ($response->content, qr/User tiger is not a member of manual_qc/, 'correct error message');

  lives_ok { $response = request(POST '/mqc/update_outcome_lane?user=cat' ) } 'post request lives';
  is( $response->code, 401, 'error code is 401' );
  like ($response->content, qr/Login failed/, 'correct error message');
}

{
  my $response;
  my $url = '/mqc/update_outcome_lane?user=cat&password=secret';

  lives_ok { $response = request(POST $url)}
    'post request without params lives';
  is( $response->code, 400, 'error code is 400' );
  like ($response->content, qr/id_run should be defined/, 'correct error message');

  lives_ok { $response = request(POST $url, ['id_run' => '1234']) }
    'post request lives with body param';
  is( $response->code, 400, 'code is 400' );
  like ($response->content, qr/position should be defined/, 'correct error message');

  lives_ok { $response = request(POST $url, ['id_run' => '1234', 'position' => '4'])  }
    'post request lives with body param';
  is( $response->code, 400, 'error code is 400' );
  like ($response->content, qr/new_oc should be defined/,
   'correct error message');

  lives_ok { $response = request(POST $url,
    ['id_run' => '1234', 'position' => '4', 'new_oc' => 'some'])  }
    'post request lives with body param';
  is( $response->code, 500, 'error code is 500' );
  like ($response->content,
    qr/No LIMs data for run 1234 position 4/,
    'error when no lims data available');

  $url = '/mqc/update_outcome_lane?user=pipeline&password=secret';
  
  my $expected = 'manual qc complete';
  my $original = 'analysis complete';
  my $rl=$schemas->{npg}->resultset('RunLane')->find({id_run=>4025, position=>4});
  $rl->update_status($original);
  
  #Test preliminary outcomes does not modify the status in tracking
  foreach my $status (('Accepted preliminary', 'Rejected preliminary', 'Undecided')) {
    lives_ok { $response = request(POST $url, ['id_run' => '4025', 'position' => '4', 'new_oc' => $status ]) } 
      'post request lives with body param';
    is( $response->code, 200, 'response code is 200' );
    is($rl->current_run_lane_status->description, $original, 'lane status has not changed in tracking');
  } 

  lives_ok { $response = request(POST $url,
    ['id_run' => '4025', 'position' => '4', 'new_oc' => 'Accepted final' ])  }
   'post request lives with body param';
  is( $response->code, 200, 'response code is 200' );
  
  #Test final outcome modify the status in tracking
  is($rl->current_run_lane_status->description, $expected, 'changed lane status'); 
  
  my $content = $response->content;
  like ($content,
    qr/Manual QC Accepted final for run 4025, position 4 saved/,
    'correct confirmation message');

  lives_ok { $response = request(POST $url,
    ['id_run' => '4025', 'position' => '1', 'new_oc' => 'Accepted final' ])  }
   'post request lives with body param';
  is( $response->code, 200, 'response code is 200' );
  $content = $response->content;
  like ($content,
    qr/Manual QC Accepted final for run 4025, position 1 saved/,
    'correct confirmation message');
  unlike ($content,
    qr/Error: Problem while updating lane status/,
    'error updating lane status is absent');
}

{
  my $response;
  lives_ok { $response = request(HTTP::Request->new('GET', '/mqc/get_current_outcome')) }
    'get current outcome lives';
  ok($response->is_error, q[get_current_outcome response is error]);
  is( $response->code, 400, 'error code is 400' );
  like ($response->content, qr/id_run should be defined/, 'correct error message');

  lives_ok { $response = request(HTTP::Request->new(
   'GET', '/mqc/get_current_outcome?id_run=1234')) } 'get current outcome lives';
  ok($response->is_error, q[get_current_outcome response is error]);
  is( $response->code, 400, 'error code is 400' );
  like ($response->content, qr/position should be defined/, 'correct error message');
}

1;

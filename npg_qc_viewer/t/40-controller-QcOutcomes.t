use strict;
use warnings;
use lib 't/lib';
use Test::More tests => 8;
use Test::Exception;
use URI::Escape qw(uri_escape);
use JSON::XS;
use HTTP::Request;
use List::MoreUtils qw/uniq/;

use npg_tracking::glossary::rpt;
use npg_tracking::glossary::composition::factory::rpt_list;
use t::util;

use_ok('npg_qc_viewer::Controller::QcOutcomes');

my $util = t::util->new();
my $schemas;
lives_ok { $schemas = $util->test_env_setup()}
  'test db created and populated';
my $qc_schema = $schemas->{'qc'};
my $wh_schema = $schemas->{'mlwh'};

local $ENV{CATALYST_CONFIG} = $util->config_path;
use_ok 'Catalyst::Test', 'npg_qc_viewer';

my $base_url = '/qcoutcomes';

sub _message {
  my ($request, $rpt) = @_;
  return sprintf q[%s %s%s],
      $request->method,
      $request->method eq 'GET' ? q() :
      q[ with content '] . $request->content . q['],
      $rpt ? qq[ ($rpt)] : q();
}

sub _new_post_request {
  my $request = HTTP::Request->new('POST', '/qcoutcomes');
  $request->header( 'Content-type' => 'application/json' );
  return $request;
}

sub _get_url {
  my @list = @_;
  if (!@list) {
    die 'Need input';
  }
  my $params = join q[&], map {'rpt_list=' . uri_escape($_)} @list;
  return join q[?], '/qcoutcomes', $params;
}

subtest 'retrieving data via GET and POST' => sub {
  plan tests => 72;

  my $r1 = HTTP::Request->new('GET', '/qcoutcomes');
  my $r2 = _new_post_request();
  for my $request ($r1, $r2) {
    my $response = request($request);
    my $m = _message($request);
    ok($response->is_error, qq[response for $m is an error]);
    is($response->code, 400, 'error code is 400 - bad request' );
    is($response->header('Content-type'), 'application/json', 'json content type');
    is($response->content, '{"error":"rpt list not defined!"}',
      'rpt list not defined - error');
  }

  $r1 = HTTP::Request->new('GET',  '/qcoutcomes?rpt_list=wrong');
  $r2 = _new_post_request();
  $r2->content('{"wrong":{}}');
  for my $request ($r1, $r2) {
    my $response = request($request);
    my $m = _message($request);
    ok($response->is_error, qq[response for $m is an error]);
    is($response->code, 400, 'error code is 400 - bad request' );
    like($response->content, qr/isn't numeric/, 'malformed rpt list - error');
  }

  my $empty_response = {"lib"=>{},"seq"=>{},"uqc"=>{}};
  my $rpt_list = '5:3:7';
  $r1 = HTTP::Request->new('GET',  _get_url($rpt_list));
  $r2 = HTTP::Request->new('POST', $base_url);
  $r2->header( 'Content-type' => 'application/json' );
  $r2->content(qq[{"$rpt_list":{}}]);
  for my $request ($r1, $r2) {
    my $response = request($request);
    ok($response->is_success, 'success');
    is($response->code, 200, 'response code 200 for ' . _message($request, $rpt_list));
    is($response->header('Content-type'), 'application/json', 'json content type');
    is_deeply(decode_json($response->content),
      $empty_response, 'response when data not available, single component');
  }

  $rpt_list = '5:3:7;5:3:5';
  my $url = _get_url($rpt_list);
  $r1 = HTTP::Request->new('GET', $url);
  $r2 = _new_post_request();
  $r2->content(qq[{"$rpt_list":{}}]);
  for my $request ($r1, $r2) {
    my $response = request($request);
    my $m = _message($request, $rpt_list);
    ok(!$response->is_error, qq[response for $m is not an error]);
    is($response->code, 200, 'response code is 200' );
    is_deeply(decode_json($response->content),
      $empty_response,'response when data not available, multiple components');
  }

  my $lrs = $qc_schema->resultset('MqcLibraryOutcomeEnt');
  my $c = npg_tracking::glossary::composition::factory::rpt_list
            ->new(rpt_list => $rpt_list)->create_composition();
  my $seq_c = $lrs->find_or_create_seq_composition($c);
  my $values = {};
  $values->{'id_seq_composition'} = $seq_c->id_seq_composition();
  $values->{'id_mqc_outcome'} = 3; # Accepted final
  $values->{'username'} = 'dog';
  $lrs->create($values);
  delete $values->{'id_mqc_outcome'};
  $values->{'id_uqc_outcome'} = 2; # Rejected
  $values->{'modified_by'} = 'cat';
  $values->{'rationale'} = 'my ticket';
  $qc_schema->resultset('UqcOutcomeEnt')->create($values);

  my $expected = {"lib" => {"5:3:5;5:3:7" => {"mqc_outcome" => "Accepted final"}},
                  "uqc" => {"5:3:5;5:3:7" => {"uqc_outcome" => "Rejected"}},
                  "seq" => {}};
  for my $request ($r1, $r2) {
    my $response = request($request);
    my $m = _message($request, $rpt_list);
    is($response->code, 200, 'response code is 200' );
    is_deeply(decode_json($response->content), $expected,
      'responce for multi-component composition');
  }

  my $rs = $qc_schema->resultset('MqcOutcomeEnt');
  my $fkeys = {}; 
  my @rpt_lists = qw(
                 5:1
                 5:2
                 5:3 5:3:2 5:3:3 5:3:4 5:3:5 5:3:6 5:3:7
                 5:4
                 5:5 );
  foreach my $l (@rpt_lists) {
    my $c = npg_tracking::glossary::composition::factory::rpt_list
            ->new(rpt_list => $l)->create_composition();
    my $seq_c = $rs->find_or_create_seq_composition($c);
    $fkeys->{$l} =  $seq_c->id_seq_composition();
  }

  $values = {id_run => 5, username => 'u1'};
  for my $i (1 .. 5) {
    $values->{'position'} = $i;
    $values->{'id_mqc_outcome'} = $i;
    $values->{'id_seq_composition'} = $fkeys->{join q[:], 5, $i};
    $qc_schema->resultset('MqcOutcomeEnt')->create($values);
  }

  $expected = {"lib"=>{},
               "uqc"=>{},
               "seq"=>{"5:3"=>{"mqc_outcome"=>"Accepted final"}}};
  $rpt_list = '5:3:7';
  $r1 = HTTP::Request->new('GET', _get_url($rpt_list));
  $r2 = _new_post_request();
  $r2->content(qq[{"$rpt_list":{}}]);
  for my $request ($r1, $r2) {
    my $response = request($request);
    is($response->code, 200, 'response code 200 for ' . _message($request, $rpt_list));
    is_deeply(decode_json($response->content), $expected, 'response content');
  }
  $rpt_list = '5:3';
  my $r3 = HTTP::Request->new('GET', _get_url($rpt_list));
  my $r4 = _new_post_request();
  $r4->content(qq[{"$rpt_list":{}}]);
  for my $request ($r3, $r4) {
    my $response = request($request);
    is($response->code, 200, 'response code 200 for ' . _message($request, $rpt_list));
    is_deeply(decode_json($response->content), $expected, 'response content');
  }

  $values = {id_run => 5, position => 3, username => 'u1'};
  for my $i (2 .. 7) {
    $values->{'tag_index'} = $i;
    $values->{'id_mqc_outcome'} = $i-1;
    $values->{'id_seq_composition'} = $fkeys->{join q[:], 5, 3, $i};
    $qc_schema->resultset('MqcLibraryOutcomeEnt')->create($values);
  }

  $expected = {"lib"=>{"5:3:2"=>{"mqc_outcome"=>"Accepted preliminary"},
                       "5:3:3"=>{"mqc_outcome"=>"Rejected preliminary"},
                       "5:3:4"=>{"mqc_outcome"=>"Accepted final"},
                       "5:3:5"=>{"mqc_outcome"=>"Rejected final"},
                       "5:3:6"=>{"mqc_outcome"=>"Undecided"},
                       "5:3:7"=>{"mqc_outcome"=>"Undecided final"}},
               "seq"=>{"5:3"  =>{"mqc_outcome"=>"Accepted final"}},
               "uqc"=>{}};
  for my $request ($r1, $r2, $r3, $r4) {
    my $response = request($request);
    is($response->code, 200, 'response code 200');
    is_deeply(decode_json($response->content), $expected, 'response content');
  }

  $qc_schema->resultset('MqcLibraryOutcomeEnt')->create(
        {id_run             => 5,
         position           => 4,
         id_seq_composition => $fkeys->{'5:4'},
         id_mqc_outcome     => 1,
         username           => 'u1'});

  $rpt_list = '5:4';
  $expected = {"lib"=>{"5:4"=>{"mqc_outcome"=>"Accepted preliminary"}},
               "seq"=>{"5:4"=>{"mqc_outcome"=>"Rejected final"}},
               "uqc"=>{}};
  $r1 = HTTP::Request->new('GET', _get_url($rpt_list));
  $r2 = _new_post_request();
  $r2->content(qq[{"$rpt_list":{}}]);
  for my $request ($r1, $r2) {
    my $response = request($request);
    is($response->code, 200, 'response code 200 for ' . _message($request, $rpt_list));
    is_deeply(decode_json($response->content), $expected, 'response content');
  }

  $expected = {"lib"=>{"5:3:2"=>{"mqc_outcome"=>"Accepted preliminary"},
                       "5:3:3"=>{"mqc_outcome"=>"Rejected preliminary"},
                       "5:3:4"=>{"mqc_outcome"=>"Accepted final"},
                       "5:3:5"=>{"mqc_outcome"=>"Rejected final"},
                       "5:3:6"=>{"mqc_outcome"=>"Undecided"},
                       "5:3:7"=>{"mqc_outcome"=>"Undecided final"},
                       "5:4"  =>{"mqc_outcome"=>"Accepted preliminary"}},
               "seq"=>{"5:3"  =>{"mqc_outcome"=>"Accepted final"},
                       "5:4"  =>{"mqc_outcome"=>"Rejected final"}},
               "uqc"=>{}};
  $r1 = HTTP::Request->new('GET', _get_url(qw/5:4 5:3/));
  $r2 = _new_post_request();
  $r2->content(qq[{"5:4":{},"5:3":{}}]);
  for my $request ($r1, $r2) {
    my $response = request($request);
    is($response->code, 200, 'response code 200 for ' . _message($request, '5:4 5:3'));
    is_deeply(decode_json($response->content), $expected, 'response content');
  }

  $r1 = HTTP::Request->new('GET', _get_url(qw/5:4 5:3:7/));
  $r2 = _new_post_request();
  $r2->content(qq[{"5:4":{},"5:3:7":{}}]);
  for my $request ($r1, $r2) {
    my $response = request($request);
    is($response->code, 200, 'response code 200 for ' . _message($request, '5:4 5:3:7'));
    is_deeply(decode_json($response->content), $expected, 'response content');
  }

  $r1 = HTTP::Request->new('GET', _get_url(qw/5:4 5:3:7 5:3/));
  $r2 = _new_post_request();
  $r2->content(qq[{"5:4":{},"5:3:7":{},"5:3":{}}]);
  for my $request ($r1, $r2) {
    my $response = request($request);
    is($response->code, 200, 'response code 200 for ' . _message($request, '5:4 5:3:7 5:3'));
    is_deeply(decode_json($response->content), $expected, 'response content');
  }

  $expected->{'seq'}->{'5:1'}= {'mqc_outcome'=>'Accepted preliminary'};
  $r1 = HTTP::Request->new('GET', _get_url(qw/5:4 5:3 5:1/));
  $r2 = _new_post_request();
  $r2->content(qq[{"5:4":{},"5:3":{},"5:1":{}}]);
  for my $request ($r1, $r2) {
    my $response = request($request);
    is($response->code, 200, 'response code 200 for ' . _message($request, '5:4 5:3 5:1'));
    is_deeply(decode_json($response->content), $expected, 'response content');
  }

  $values = {'id_seq_composition' => $fkeys->{'5:3:5'},
             'id_uqc_outcome'     => 1,
             'username'           => 'user',
             'modified_by'        => 'user',
             'rationale'          => 'rationale something'};
  $qc_schema->resultset('UqcOutcomeEnt')->create($values);
  $values->{'id_seq_composition'} = $fkeys->{'5:3:7'};
  $values->{'id_uqc_outcome'} = 2;
  $qc_schema->resultset('UqcOutcomeEnt')->create($values);

  delete $expected->{'lib'}->{'5:4'};
  delete $expected->{'seq'}->{'5:1'};
  delete $expected->{'seq'}->{'5:4'};
  $expected->{'uqc'} = {"5:3:7"=>{"uqc_outcome"=>"Rejected"},
                        "5:3:5"=>{"uqc_outcome"=>"Accepted"}};

  $r1 = HTTP::Request->new('GET', _get_url(qw/5:3:5 5:3:7/));
  $r2 = _new_post_request();
  $r2->content(qq[{"5:3:5":{},"5:3:7":{}}]);
  for my $request ($r1, $r2) {
    my $response = request($request);
    is($response->code, 200, 'response code 200 for ' . _message($request, '5:3:5 5:3:7'));
    is_deeply(decode_json($response->content), $expected, 'response content');
  }
};

subtest 'authentication and authorisation for an update' => sub {
  plan tests => 7;

  my $error_code = 403;

  my $request = _new_post_request();
  $request->content('{"Action":"UPDATE"}');
  my $response = request($request);
  ok( $response->is_error, qq[response is an error] );
  is( $response->code, $error_code, "error code is $error_code" );
  like ($response->content, qr/Login failed/, 'no user credentials - error');

  $request = _new_post_request();
  $request->content('{"Action":"UPDATE","user":"frog","password":"public"}');
  $response = request($request);
  is( $response->code, $error_code, "error code is $error_code" );
  like ($response->content, qr/Login failed/, 'frog is not authenticated');

  $request = _new_post_request();
  $request->content('{"Action":"UPDATE","user":"tiger","password":"secret"}');
  $response = request($request);
  is( $response->code, $error_code, "error code is $error_code" );
  like ($response->content, qr/User tiger is not authorised for manual qc/,
    'tiger is not authorised');
};

subtest 'data validation for update requests' => sub {
  plan tests => 10;

  my $data = {'Action'   => 'UPDATE',
              'user'     => 'cat',
              'password' => 'secret',
              'lib'      => {},
              'seq'      => {},
              'other'    => {}};
  my $error_code = 400;

  my $request = _new_post_request();
  $request->content(encode_json($data));
  my $response = request($request);
  is($response->code, $error_code, "error code is $error_code");
  like ($response->content, qr/One of outcome types is unknown/,
    'unknown outcome type present - error');

  delete $data->{'other'};
  $data->{'lib'} = {'1:2' => {'mqc_outcome' => 'Undecided'}, '1:4' => {'mqc_outcome' => ''}};
  $request = _new_post_request();
  $request->content(encode_json($data));
  $response = request($request);
  is($response->code, $error_code, "error code is $error_code");
  like ($response->content, qr/Error saving outcome for 1:4 - Outcome description is missing/,
    'outcome description should be present');

  $data->{'lib'} = {'1:2' => {'mqc_outcome' => 'Undecided'}, '1:4' => {'qc_outcome' => ''}};
  $request = _new_post_request();
  $request->content(encode_json($data));
  $response = request($request);
  is($response->code, $error_code, "error code is $error_code");
  like ($response->content, qr/Error saving outcome for 1:4 - Outcome description is missing/,
    'outcome description should not be empty');

  delete $data->{'lib'};
  $data->{'uqc'} = {'1:2' => {'uqc_outcome' => 'Undecided',
                              'rationale'   => 'something'},
                    '1:4' => {'uqc_outcome' => ''}};
  $request = _new_post_request();
  $request->content(encode_json($data));
  $response = request($request);
  is($response->code, $error_code, "error code is $error_code");
  like ($response->content,
    qr/Error saving outcome for 1:4 - Outcome description is missing/,
    'outcome description for uqc should be present for 1:4');

  $data->{'uqc'} = {'1:2' => {'uqc_outcome' => 'Accepted'}};
  $request = _new_post_request();
  $request->content(encode_json($data));
  $response = request($request);
  is($response->code, $error_code, "error code is $error_code for uqc");
  like ($response->content, qr/Rationale required/,
    'Rationale description should be present');
};


subtest 'conditionally get wh info about tags' => sub {
  plan tests => 4;

  my $data = {'Action'   => 'UPDATE',
              'user'     => 'cat',
              'password' => 'secret',
              'seq' =>  {'1234:4' => {'mqc_outcome' => 'some'}}
             };
  my $error_code = 400;

  my $request = _new_post_request();
  $request->content(encode_json($data));
  my $response = request($request);
  is($response->code, $error_code, "error code is $error_code");
  like ($response->content,
    qr/No NPG mlwarehouse data for run 1234 position 4/,
    'error when no lims data available for a lane');

  delete $data->{'seq'};
  $data->{'lib'} = {'1234:4' => {'mqc_outcome' => 'Undecided'}};
  $request = _new_post_request();
  $request->content(encode_json($data));
  $response = request($request);
  ok($response->is_success, 'response received for updating a lib entity');

  $wh_schema->resultset('IseqRunLaneMetric')->create({
    cancelled =>  0,
    cycles => 76,
    id_run => 1234,
    instrument_model => 'HK',
    instrument_name => 'IL6',
    paired_read => 1,
    pf_bases => 912144,
    pf_cluster_count => 120019,
    position => 4,});

  $wh_schema->resultset('IseqProductMetric')->create({
    id_run => 1234, position => 4, id_iseq_flowcell_tmp => 2514299
  });

  delete $data->{'lib'};
  $data->{'seq'} = {'1234:4' => {'mqc_outcome' => 'Rejected final'}};
  $request = _new_post_request();
  $request->content(encode_json($data));
  $response = request($request);
  ok($response->is_success, 'response received for updating a seq entity');
};

subtest 'Conditional update of run/lane status in tracking' => sub {
  plan tests => 9;

  my $original = 'analysis complete';
  my $rl=$schemas->{'npg'}->resultset('RunLane')->find({id_run=>4025, position=>4});
  $rl->update_status($original);
  is($rl->current_run_lane_status->description, $original,
    "lane status is set to $original");

  my $data = {'Action'   => 'UPDATE',
              'user'     => 'pipeline',
              'password' => 'secret'};

  my @prelims = ('Accepted preliminary', 'Rejected preliminary', 'Undecided');
  foreach my $mqc_outcome (@prelims) {
    my $request = _new_post_request();
    $data->{'seq'} = {'4025:4' => {'mqc_outcome' => $mqc_outcome}};
    $request->content(encode_json($data));
    my $response = request($request);
    ok($response->is_success, "updated to '$mqc_outcome'") ||
      diag 'RESPONSE: ' . $response->content;

    is($rl->current_run_lane_status->description, $original,
      'lane status has not changed');
  }

  my $mqc_outcome = 'Rejected final';
  $data->{'seq'} = {'4025:4' => {'mqc_outcome' => $mqc_outcome}};
  my $request = _new_post_request();
  $request->content(encode_json($data));
  my $response = request($request);
  ok($response->is_success, "updated to '$mqc_outcome'") ||
    diag 'RESPONSE: ' . $response->content;
  my $expected_lane_status = 'manual qc complete';
  is($rl->current_run_lane_status->description, $expected_lane_status,
    "lane status changed to $expected_lane_status");
};

1;


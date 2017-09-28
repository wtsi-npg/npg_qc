use strict;
use warnings;
use lib 't/lib';
use t::autoqc_util;
use Test::More tests => 8;
use Test::Exception;
use URI::Escape qw(uri_escape);
use JSON::XS;
use HTTP::Request;
use DateTime;
#use Data::Dumper;
#$Data::Dumper::Maxdepth=1;

use npg_tracking::glossary::rpt;
use t::util;

use_ok('npg_qc_viewer::Controller::QcOutcomes');

my $util = t::util->new();
my $schemas;
lives_ok { $schemas = $util->test_env_setup()}
  'test db created and populated';
my $qc_schema = $schemas->{'qc'};
my $wh_schema = $schemas->{'mlwh'};

local $ENV{CATALYST_CONFIG} = $util->config_path;
use_ok ('Catalyst::Test', 'npg_qc_viewer');

my $base_url = '/qcoutcomes';

sub _message {
  my ($request, $rpt) = @_;
  return sprintf q[%s on '%s'%s%s],
      $request->method, $request->uri,
      $request->method eq 'GET' ? q() :
      q[ with content '] . $request->content . q['],
      $rpt ? qq[ ($rpt)] : q();
}

sub _new_post_request {
  my $request = HTTP::Request->new('POST', $base_url);
  $request->header( 'Content-type' => 'application/json' );
  return $request;
}

subtest 'retrieving data via GET and POST' => sub {
  plan tests => 68;

 my @urls = qw(
    5:3:7
    5:3
    5:3:7
    5:3
    5:4
    5:4;5:3
    5:4;5:3;5:1
    5:4;5:3:7
    5:4;5:3:7;5:3
    5:3:5;5:3:7
  );

  my $jsons = [
    '{"lib":{},"seq":{"5:3":{"mqc_outcome":"Accepted final"}},"uqc":{}}',
    '{"lib":{},"seq":{"5:3":{"mqc_outcome":"Accepted final"}},"uqc":{}}',
    '{"lib":{"5:3:7":{"mqc_outcome":"Undecided final"}},"seq":{"5:3":{"mqc_outcome":"Accepted final"}},"uqc":{}}',
    '{"lib":{"5:3:6":{"mqc_outcome":"Undecided"},"5:3:3":{"mqc_outcome":"Rejected preliminary"},"5:3:7":{"mqc_outcome":"Undecided final"},"5:3:5":{"mqc_outcome":"Rejected final"},"5:3:4":{"mqc_outcome":"Accepted final"},"5:3:2":{"mqc_outcome":"Accepted preliminary"}},"seq":{"5:3":{"mqc_outcome":"Accepted final"}},"uqc":{}}',
    '{"lib":{"5:4":{"mqc_outcome":"Accepted preliminary"}},"seq":{"5:4":{"mqc_outcome":"Rejected final"}},"uqc":{}}',
    '{"lib":{"5:3:6":{"mqc_outcome":"Undecided"},"5:4":{"mqc_outcome":"Accepted preliminary"},"5:3:3":{"mqc_outcome":"Rejected preliminary"},"5:3:7":{"mqc_outcome":"Undecided final"},"5:3:5":{"mqc_outcome":"Rejected final"},"5:3:4":{"mqc_outcome":"Accepted final"},"5:3:2":{"mqc_outcome":"Accepted preliminary"}},"seq":{"5:4":{"mqc_outcome":"Rejected final"},"5:3":{"mqc_outcome":"Accepted final"}},"uqc":{}}',
    '{"lib":{"5:3:6":{"mqc_outcome":"Undecided"},"5:4":{"mqc_outcome":"Accepted preliminary"},"5:3:3":{"mqc_outcome":"Rejected preliminary"},"5:3:7":{"mqc_outcome":"Undecided final"},"5:3:5":{"mqc_outcome":"Rejected final"},"5:3:4":{"mqc_outcome":"Accepted final"},"5:3:2":{"mqc_outcome":"Accepted preliminary"}},"seq":{"5:4":{"mqc_outcome":"Rejected final"},"5:3":{"mqc_outcome":"Accepted final"},"5:1":{"mqc_outcome":"Accepted preliminary"}},"uqc":{}}',
    '{"lib":{"5:4":{"mqc_outcome":"Accepted preliminary"},"5:3:7":{"mqc_outcome":"Undecided final"}},"seq":{"5:4":{"mqc_outcome":"Rejected final"},"5:3":{"mqc_outcome":"Accepted final"}},"uqc":{}}',
    '{"lib":{"5:3:6":{"mqc_outcome":"Undecided"},"5:4":{"mqc_outcome":"Accepted preliminary"},"5:3:3":{"mqc_outcome":"Rejected preliminary"},"5:3:7":{"mqc_outcome":"Undecided final"},"5:3:5":{"mqc_outcome":"Rejected final"},"5:3:4":{"mqc_outcome":"Accepted final"},"5:3:2":{"mqc_outcome":"Accepted preliminary"}},"seq":{"5:4":{"mqc_outcome":"Rejected final"},"5:3":{"mqc_outcome":"Accepted final"}},"uqc":{}}',
    '{"lib":{"5:3:7":{"mqc_outcome":"Undecided final"},"5:3:5":{"mqc_outcome":"Rejected final"}},"seq":{"5:3":{"mqc_outcome":"Accepted final"}},"uqc":{}}'
  ];

  my $r1 = HTTP::Request->new('GET',  $base_url);
  my $r2 = HTTP::Request->new('POST', $base_url);
  $r2->header( 'Content-type' => 'application/json' );

  for my $request ($r1, $r2) {
    my $response = request($request);
    my $m = _message($request);
    ok($response->is_error, qq[response for $m is an error]);
    is($response->code, 400, 'error code is 400 - bad request' );
    is($response->header('Content-type'), 'application/json', 'json content type');
    is($response->content, '{"error":"rpt list not defined!"}', 'error message: rpt_list not defined!');
  }

  my $url = join q[?], $base_url, 'rpt_list=wrong';
  $r1 = HTTP::Request->new('GET',  $url);
  $r2 = HTTP::Request->new('POST', $base_url);
  $r2->header( 'Content-type' => 'application/json' );
  $r2->content('{"wrong":{}}');
  for my $request ($r1, $r2) {
    my $response = request($request);
    my $m = _message($request);
    ok($response->is_error, qq[response for $m is an error]);
    is($response->code, 400, 'error code is 400 - bad request' );
    like($response->content,
      qr/Both id_run and position should be available/, 'error message: Both id_run and position should be available in rpt_list');
  }

  my $rpt = '5:8:7;5:8:8';
  $url = join q[?], $base_url, 'rpt_list='. uri_escape($rpt);
  $r1 = HTTP::Request->new('GET',  $url);
  $r2 = HTTP::Request->new('POST', $base_url);
  $r2->header( 'Content-type' => 'application/json' );
  $r2->content(qq[{"$rpt":{}}]);
  for my $request ($r1, $r2) {
    my $response = request($request);
    my $m = _message($request, $rpt);
    ok($response->is_error, qq[response for $m is an error]);
    is($response->code, 400, 'error code is 400 - bad request' );
    like($response->content,
      qr/Cannot deal with multi-component compositions/, 'error message: Cannot deal with multi-component compositions');
  }

  $rpt = '5:3:7';
  $url = join q[?], $base_url, 'rpt_list='. uri_escape($rpt);
  $r1 = HTTP::Request->new('GET',  $url);
  $r2 = HTTP::Request->new('POST', $base_url);
  $r2->header( 'Content-type' => 'application/json' );
  $r2->content(qq[{"$rpt":{}}]);
  for my $request ($r1, $r2) {
    my $response = request($request);
    ok($response->is_success, 'success');
    is($response->code, 200, 'response code 200 for ' . _message($request, $rpt));
    is($response->header('Content-type'), 'application/json', 'json content type');
    is_deeply(decode_json($response->content), decode_json('{"lib":{},"seq":{},"uqc":{}}'),
      'response content with empty fields (lib{},seq{},uqc{}) for no encoded values');
  }
  my $id_sec_compos;
  my $values = {id_run => 5, username => 'u1'};
  for my $i (1 .. 5) {
    $values->{'position'} = $i;
    $values->{'id_mqc_outcome'} = $i;
    $qc_schema->resultset('MqcOutcomeEnt')->create($values);
    $id_sec_compos = t::autoqc_util::find_or_save_composition($qc_schema, {
      'id_run' => 5, 'position' => $i
    });
  }

  my $j = 0;
  while ($j < @urls) {
    if ($j == 2) {
      $values = {id_run => 5, position => 3, username => 'u1'};
      for my $i (2 .. 7) {
        $values->{'tag_index'} = $i;
        $values->{'id_mqc_outcome'} = $i-1;
        $qc_schema->resultset('MqcLibraryOutcomeEnt')->create($values);
        $id_sec_compos = t::autoqc_util::find_or_save_composition($qc_schema, {
        'id_run' => 5, 'position' => 3, 'tag_index' => $i
        });
      }
    } elsif ($j == 4) {
      $qc_schema->resultset('MqcLibraryOutcomeEnt')->create(
        {id_run=>5, position=>4, id_mqc_outcome=>1, username=>'u1'});
      $id_sec_compos = t::autoqc_util::find_or_save_composition($qc_schema, {
        'id_run' => 5, 'position' => 4
        });
    }

    my $rpt_list = $urls[$j];
    my @rpts = @{npg_tracking::glossary::rpt->split_rpts($rpt_list)};
    my $url = $base_url . '?' . join q[&], map {'rpt_list=' . uri_escape($_)} @rpts;
    my %h = map { $_ => {} } @rpts;

    my $request1 = HTTP::Request->new('GET',  $url);
    my $request2 = HTTP::Request->new('POST', $base_url);
    $request2->header( 'Content-type' => 'application/json' );
    $request2->content(encode_json(\%h));
    for my $request ($request1, $request2) {
      my $response = request($request);
      is($response->code, 200, 'response code 200 for ' . _message($request, $rpt_list));
      is_deeply(decode_json($response->content), decode_json($jsons->[$j]),
        'response content with fields (lib{...},seq{...}) for encoded values but empty uqc{} for non encoded');
    }

    $j++;
  }

  $values = {'last_modified' => DateTime->now(),
             'username' => 'u1',
             'modified_by' =>' user',
             'rationale' =>'rationale something'};
  for my $i (1 .. 5) {
    $values->{'id_uqc_outcome'} = (($i % 3) + 1),
    $values->{'id_seq_composition'} = t::autoqc_util::find_or_save_composition($qc_schema, {
        'id_run' => 5, 'position' => $i
    });
    $qc_schema->resultset('UqcOutcomeEnt')->create($values);
    my  $k = '5:' . $i;
    #warn ("$k =*=*=*=*=* created uqcoutcomeEnt " . Dumper($values));
  }

  $jsons = [
    'result test no needed, next loop starts at $j=2',
    'result test no needed, next loop starts at $j=2',
    '{"lib":{"5:3:7":{"mqc_outcome":"Undecided final"}},"seq":{"5:3":{"mqc_outcome":"Accepted final"}},"uqc":{}}',
    '{"lib":{"5:3:6":{"mqc_outcome":"Undecided"},"5:3:3":{"mqc_outcome":"Rejected preliminary"},"5:3:7":{"mqc_outcome":"Undecided final"},"5:3:5":{"mqc_outcome":"Rejected final"},"5:3:4":{"mqc_outcome":"Accepted final"},"5:3:2":{"mqc_outcome":"Accepted preliminary"}},"seq":{"5:3":{"mqc_outcome":"Accepted final"}},"uqc":{}}',
    '{"lib":{"5:4":{"mqc_outcome":"Accepted preliminary"}},"seq":{"5:4":{"mqc_outcome":"Rejected final"}},"uqc":{}}',
    '{"lib":{"5:3:6":{"mqc_outcome":"Undecided"},"5:4":{"mqc_outcome":"Accepted preliminary"},"5:3:3":{"mqc_outcome":"Rejected preliminary"},"5:3:7":{"mqc_outcome":"Undecided final"},"5:3:5":{"mqc_outcome":"Rejected final"},"5:3:4":{"mqc_outcome":"Accepted final"},"5:3:2":{"mqc_outcome":"Accepted preliminary"}},"seq":{"5:4":{"mqc_outcome":"Rejected final"},"5:3":{"mqc_outcome":"Accepted final"}},"uqc":{}}',
    '{"lib":{"5:3:6":{"mqc_outcome":"Undecided"},"5:4":{"mqc_outcome":"Accepted preliminary"},"5:3:3":{"mqc_outcome":"Rejected preliminary"},"5:3:7":{"mqc_outcome":"Undecided final"},"5:3:5":{"mqc_outcome":"Rejected final"},"5:3:4":{"mqc_outcome":"Accepted final"},"5:3:2":{"mqc_outcome":"Accepted preliminary"}},"seq":{"5:4":{"mqc_outcome":"Rejected final"},"5:3":{"mqc_outcome":"Accepted final"},"5:1":{"mqc_outcome":"Accepted preliminary"}},"uqc":{}}',
    '{"lib":{"5:4":{"mqc_outcome":"Accepted preliminary"},"5:3:7":{"mqc_outcome":"Undecided final"}},"seq":{"5:4":{"mqc_outcome":"Rejected final"},"5:3":{"mqc_outcome":"Accepted final"}},"uqc":{}}',
    '{"lib":{"5:3:6":{"mqc_outcome":"Undecided"},"5:4":{"mqc_outcome":"Accepted preliminary"},"5:3:3":{"mqc_outcome":"Rejected preliminary"},"5:3:7":{"mqc_outcome":"Undecided final"},"5:3:5":{"mqc_outcome":"Rejected final"},"5:3:4":{"mqc_outcome":"Accepted final"},"5:3:2":{"mqc_outcome":"Accepted preliminary"}},"seq":{"5:4":{"mqc_outcome":"Rejected final"},"5:3":{"mqc_outcome":"Accepted final"}},"uqc":{}}',
    '{"lib":{"5:3:7":{"mqc_outcome":"Undecided final"},"5:3:5":{"mqc_outcome":"Rejected final"}},"seq":{"5:3":{"mqc_outcome":"Accepted final"}},"uqc":{}}'
  ];

  $j = 2;
  while ($j < @urls) {
    $values = {'last_modified' => DateTime->now(),
               'username' => 'u1',
               'modified_by' =>' user',
               'rationale' =>'rationale something'};
    if ($j == 2) {
      for my $i (2 .. 7) {
        $values->{'id_uqc_outcome'} = (($i % 3) + 1),
        $values->{'id_seq_composition'} = t::autoqc_util::find_or_save_composition($qc_schema, {
          'id_run' => 5, 'position' => 3, 'tag_index' => $i
        });
        $qc_schema->resultset('UqcOutcomeEnt')->create($values);
        my  $k = '5:3:' . $i;
        #warn ("$k ========== created uqcoutcomeEnt " . Dumper($values));
      }
    } elsif ($j == 4) {
      $values->{'id_uqc_outcome'} = 1,
      $values->{'id_seq_composition'} = t::autoqc_util::find_or_save_composition($qc_schema, {
        'id_run' => 5, 'position' => 4
      });
      $qc_schema->resultset('UqcOutcomeEnt')->create($values);
      my  $k = $urls[$j] ;
        #warn ("$k =-=-=-=-=- created uqcoutcomeEnt " . Dumper($values));
    }

    my $rpt_list = $urls[$j];
    my @rpts = @{npg_tracking::glossary::rpt->split_rpts($rpt_list)};
    my $url = $base_url . '?' . join q[&], map {'rpt_list=' . uri_escape($_)} @rpts;
    my %h = map { $_ => {} } @rpts;

    my $request1 = HTTP::Request->new('GET',  $url);
    my $request2 = HTTP::Request->new('POST', $base_url);
    $request2->header( 'Content-type' => 'application/json' );
    $request2->content(encode_json(\%h));
    for my $request ($request1, $request2) {
      my $response = request($request);
      is($response->code, 200, 'response code 200 for ' . _message($request, $rpt_list));
      is_deeply(decode_json($response->content), decode_json($jsons->[$j]), "response content $j for $rpt_list: \n response: " . $response->content . "\n testmem : $jsons->[$j]");
    }
    $j++;
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
  plan tests => 8;

  my $data = {'Action'   => 'UPDATE',
              'user'     => 'cat',
              'password' => 'secret',
              'lib'      => {},
              'seq'      => {}};
  my $error_code = 400;

  my $request = _new_post_request();
  $request->content(encode_json($data));
  my $response = request($request);
  is($response->code, $error_code, "error code is $error_code");
  like ($response->content, qr/No data to save/,
    'should send some data');

  $data->{'lib'} = {'1:2;3:4' => {'mqc_outcome' => 'some'}};
  $request = _new_post_request();
  $request->content(encode_json($data));
  $response = request($request);
  is($response->code, $error_code, "error code is $error_code");
  like ($response->content, qr/rpt string should not contain \';\'/,
    'multi-component compositions are not allowed');

  $data->{'lib'} = {'1:2' => {'mqc_outcome' => 'Undecided'}, '1:4' => {'mqc_outcome' => ''}};
  $request = _new_post_request();
  $request->content(encode_json($data));
  $response = request($request);
  is($response->code, $error_code, "error code is $error_code");
  like ($response->content, qr/Outcome description is missing for 1:4/,
    'outcome description should be present');

  $data->{'lib'} = {'1:2' => {'mqc_outcome' => 'Undecided'}, '1:4' => {'qc_outcome' => ''}};
  $request = _new_post_request();
  $request->content(encode_json($data));
  $response = request($request);
  is($response->code, $error_code, "error code is $error_code");
  like ($response->content, qr/Outcome description is missing for 1:4/,
    'outcome description should not be empty');
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


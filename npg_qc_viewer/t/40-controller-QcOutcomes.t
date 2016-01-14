use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;
use URI::Escape qw(uri_escape);
use JSON::XS;
use HTTP::Request;

use npg_tracking::glossary::rpt;
use t::util;

use_ok('npg_qc_viewer::Controller::QcOutcomes');

my $util = t::util->new();
my $schemas;
lives_ok { $schemas = $util->test_env_setup()}
  'test db created and populated';
my $qc_schema = $schemas->{'qc'};

local $ENV{CATALYST_CONFIG} = $util->config_path;
use_ok 'Catalyst::Test', 'npg_qc_viewer';

sub _message {
  my ($request, $rpt) = @_;
  return sprintf q[%s on '%s'%s%s],
      $request->method, $request->uri,
      $request->method eq 'GET' ? q() :
      q[ with content '] . $request->content . q['],
      $rpt ? qq[ ($rpt)] : q();
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
    '{"lib":{},"seq":{"5:3":{"mqc_outcome":"Accepted final","position":3,"id_run":5}}}',
    '{"lib":{},"seq":{"5:3":{"mqc_outcome":"Accepted final","position":3,"id_run":5}}}',
    '{"lib":{"5:3:7":{"tag_index":7,"mqc_outcome":"Undecided final","position":3,"id_run":5}},"seq":{"5:3":{"mqc_outcome":"Accepted final","position":3,"id_run":5}}}',
    '{"lib":{"5:3:6":{"tag_index":6,"mqc_outcome":"Undecided","position":3,"id_run":5},"5:3:3":{"tag_index":3,"mqc_outcome":"Rejected preliminary","position":3,"id_run":5},"5:3:7":{"tag_index":7,"mqc_outcome":"Undecided final","position":3,"id_run":5},"5:3:5":{"tag_index":5,"mqc_outcome":"Rejected final","position":3,"id_run":5},"5:3:4":{"tag_index":4,"mqc_outcome":"Accepted final","position":3,"id_run":5},"5:3:2":{"tag_index":2,"mqc_outcome":"Accepted preliminary","position":3,"id_run":5}},"seq":{"5:3":{"mqc_outcome":"Accepted final","position":3,"id_run":5}}}',
    '{"lib":{"5:4":{"mqc_outcome":"Accepted preliminary","position":4,"id_run":5}},"seq":{"5:4":{"mqc_outcome":"Rejected final","position":4,"id_run":5}}}',
    '{"lib":{"5:3:6":{"tag_index":6,"mqc_outcome":"Undecided","position":3,"id_run":5},"5:4":{"mqc_outcome":"Accepted preliminary","position":4,"id_run":5},"5:3:3":{"tag_index":3,"mqc_outcome":"Rejected preliminary","position":3,"id_run":5},"5:3:7":{"tag_index":7,"mqc_outcome":"Undecided final","position":3,"id_run":5},"5:3:5":{"tag_index":5,"mqc_outcome":"Rejected final","position":3,"id_run":5},"5:3:4":{"tag_index":4,"mqc_outcome":"Accepted final","position":3,"id_run":5},"5:3:2":{"tag_index":2,"mqc_outcome":"Accepted preliminary","position":3,"id_run":5}},"seq":{"5:4":{"mqc_outcome":"Rejected final","position":4,"id_run":5},"5:3":{"mqc_outcome":"Accepted final","position":3,"id_run":5}}}',
    '{"lib":{"5:3:6":{"tag_index":6,"mqc_outcome":"Undecided","position":3,"id_run":5},"5:4":{"mqc_outcome":"Accepted preliminary","position":4,"id_run":5},"5:3:3":{"tag_index":3,"mqc_outcome":"Rejected preliminary","position":3,"id_run":5},"5:3:7":{"tag_index":7,"mqc_outcome":"Undecided final","position":3,"id_run":5},"5:3:5":{"tag_index":5,"mqc_outcome":"Rejected final","position":3,"id_run":5},"5:3:4":{"tag_index":4,"mqc_outcome":"Accepted final","position":3,"id_run":5},"5:3:2":{"tag_index":2,"mqc_outcome":"Accepted preliminary","position":3,"id_run":5}},"seq":{"5:4":{"mqc_outcome":"Rejected final","position":4,"id_run":5},"5:3":{"mqc_outcome":"Accepted final","position":3,"id_run":5},"5:1":{"mqc_outcome":"Accepted preliminary","position":1,"id_run":5}}}',
    '{"lib":{"5:4":{"mqc_outcome":"Accepted preliminary","position":4,"id_run":5},"5:3:7":{"tag_index":7,"mqc_outcome":"Undecided final","position":3,"id_run":5}},"seq":{"5:4":{"mqc_outcome":"Rejected final","position":4,"id_run":5},"5:3":{"mqc_outcome":"Accepted final","position":3,"id_run":5}}}',
    '{"lib":{"5:3:6":{"tag_index":6,"mqc_outcome":"Undecided","position":3,"id_run":5},"5:4":{"mqc_outcome":"Accepted preliminary","position":4,"id_run":5},"5:3:3":{"tag_index":3,"mqc_outcome":"Rejected preliminary","position":3,"id_run":5},"5:3:7":{"tag_index":7,"mqc_outcome":"Undecided final","position":3,"id_run":5},"5:3:5":{"tag_index":5,"mqc_outcome":"Rejected final","position":3,"id_run":5},"5:3:4":{"tag_index":4,"mqc_outcome":"Accepted final","position":3,"id_run":5},"5:3:2":{"tag_index":2,"mqc_outcome":"Accepted preliminary","position":3,"id_run":5}},"seq":{"5:4":{"mqc_outcome":"Rejected final","position":4,"id_run":5},"5:3":{"mqc_outcome":"Accepted final","position":3,"id_run":5}}}',
    '{"lib":{"5:3:7":{"tag_index":7,"mqc_outcome":"Undecided final","position":3,"id_run":5},"5:3:5":{"tag_index":5,"mqc_outcome":"Rejected final","position":3,"id_run":5}},"seq":{"5:3":{"mqc_outcome":"Accepted final","position":3,"id_run":5}}}'
  ];

  my $base_url = '/qcoutcomes';
  my $r1 = HTTP::Request->new('GET',  $base_url);
  my $r2 = HTTP::Request->new('POST', $base_url);
  $r2->header( 'Content-type' => 'application/json' );

  for my $request ($r1, $r2) {
    my $response = request($request);
    my $m = _message($request);
    ok($response->is_error, qq[response for $m is an error]);
    is($response->code, 400, 'error code is 400 - bad request' );
    is($response->header('Content-type'), 'application/json', 'json content type');
    is($response->content, '{"error":"rpt list not defined!"}', 'error message');
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
      qr/Both id_run and position should be available/, 'error message');
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
      qr/Cannot deal with multi-component compositions/, 'error message');
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
    is($response->content, '{"lib":{},"seq":{}}', 'response content');
  }

  my $values = {id_run => 5, username => 'u1'};
  for my $i (1 .. 5) {
    $values->{'position'} = $i;
    $values->{'id_mqc_outcome'} = $i;
    $qc_schema->resultset('MqcOutcomeEnt')->create($values);
  }
       
  my $j = 0;
  while ($j < @urls) {

    if ($j == 2) {
      $values = {id_run => 5, position => 3, username => 'u1'};
      for my $i (2 .. 7) {
        $values->{'tag_index'} = $i;
        $values->{'id_mqc_outcome'} = $i-1;
        $qc_schema->resultset('MqcLibraryOutcomeEnt')->create($values);
      }
    } elsif ($j == 4) {
      $qc_schema->resultset('MqcLibraryOutcomeEnt')->create(
        {id_run=>5, position=>4, id_mqc_outcome=>1, username=>'u1'});
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
      is_deeply(decode_json($response->content), decode_json($jsons->[$j]), 'response content');
    }
           
    $j++; 
  }
};

1;
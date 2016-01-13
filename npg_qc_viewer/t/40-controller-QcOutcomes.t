use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;
use t::util;

use_ok('npg_qc_viewer::Controller::QcOutcomes');

my $util = t::util->new();
my $schemas;
lives_ok { $schemas = $util->test_env_setup()}
  'test db created and populated';
my $qc_schema = $schemas->{'qc'};

local $ENV{CATALYST_CONFIG} = $util->config_path;
use_ok 'Catalyst::Test', 'npg_qc_viewer';

subtest 'GET requests' => sub {
  plan tests => 34;

  my $url = '/qcoutcomes';
  my $response = request($url);
  ok($response->is_error, "response for '$url' is an error");
  is($response->code, 400, 'error code is 400 - bad request' );
  is($response->header('Content-type'), 'application/json', 'json content type');
  is($response->content, '{"error":"rpt list not defined!"}', 'error message');

  $url = '/qcoutcomes?rpt_list=wrong';
  $response = request($url);
  ok($response->is_error, "response for '$url' is an error");
  is($response->code, 400, 'error code is 400 - bad request' );
  like($response->content,
    qr/Both id_run and position should be available/, 'error message');

  # 5:8:7;5:8:8
  $url = '/qcoutcomes?rpt_list=5%3A8%3A7%3B5%3A8%3A8';
  $response = request($url);
  ok($response->is_error, "response for '$url' is an error");
  is($response->code, 400, 'error code is 400 - bad request' );
  like($response->content,
    qr/Cannot deal with multi-component compositions/, 'error message');

  $url = '/qcoutcomes?rpt_list=5%3A3%3A7';
  $response = request($url);
  ok($response->is_success, 'success');
  is($response->code, 200, "response code for '$url' is 200");
  is($response->header('Content-type'), 'application/json', 'json content type');
  is($response->content, '{"lib":{},"seq":{}}', 'response content');

  my $values = {id_run => 5, username => 'u1'};
  for my $i (1 .. 5) {
    $values->{'position'} = $i;
    $values->{'id_mqc_outcome'} = $i;
    $qc_schema->resultset('MqcOutcomeEnt')->create($values);
  }

  my $expected = '{"lib":{},"seq":{"5:3":{"mqc_outcome":"Accepted final","position":3,"id_run":5}}}';
  $response = request($url);
  is($response->code, 200, "response code for '$url' is 200");
  is($response->content, $expected, 'response content');

  my $url1 = '/qcoutcomes?rpt_list=5%3A3';
  $response = request($url1);
  is($response->code, 200, "response code for '$url1' is 200");
  is($response->content, $expected, 'response content');

  $values = {id_run => 5, position => 3, username => 'u1'};
  for my $i (2 .. 7) {
    $values->{'tag_index'} = $i;
    $values->{'id_mqc_outcome'} = $i-1;
    $qc_schema->resultset('MqcLibraryOutcomeEnt')->create($values);
  }

  $expected = '{"lib":{"5:3:7":{"tag_index":7,"mqc_outcome":"Undecided final","position":3,"id_run":5}},"seq":{"5:3":{"mqc_outcome":"Accepted final","position":3,"id_run":5}}}';
  $response = request($url);
  is($response->code, 200, "response code for '$url' is 200");
  is($response->content, $expected, 'response content');

  $expected = '{"lib":{"5:3:6":{"tag_index":6,"mqc_outcome":"Undecided","position":3,"id_run":5},"5:3:3":{"tag_index":3,"mqc_outcome":"Rejected preliminary","position":3,"id_run":5},"5:3:7":{"tag_index":7,"mqc_outcome":"Undecided final","position":3,"id_run":5},"5:3:5":{"tag_index":5,"mqc_outcome":"Rejected final","position":3,"id_run":5},"5:3:4":{"tag_index":4,"mqc_outcome":"Accepted final","position":3,"id_run":5},"5:3:2":{"tag_index":2,"mqc_outcome":"Accepted preliminary","position":3,"id_run":5}},"seq":{"5:3":{"mqc_outcome":"Accepted final","position":3,"id_run":5}}}';
  $response = request($url1);
  is($response->code, 200, "response code for '$url' is 200");
  is($response->content, $expected, 'response content');

  $qc_schema->resultset('MqcLibraryOutcomeEnt')->create(
    {id_run=>5, position=>4, id_mqc_outcome=>1, username=>'u1'});

  $url = '/qcoutcomes?rpt_list=5%3A4';
  $expected = '{"lib":{"5:4":{"mqc_outcome":"Accepted preliminary","position":4,"id_run":5}},"seq":{"5:4":{"mqc_outcome":"Rejected final","position":4,"id_run":5}}}';
  $response = request($url);
  is($response->code, 200, "response code for '$url' is 200");
  is($response->content, $expected, 'response content');

  $url = '/qcoutcomes?rpt_list=5%3A4&rpt_list=5%3A3';
  $expected = '{"lib":{"5:3:6":{"tag_index":6,"mqc_outcome":"Undecided","position":3,"id_run":5},"5:4":{"mqc_outcome":"Accepted preliminary","position":4,"id_run":5},"5:3:3":{"tag_index":3,"mqc_outcome":"Rejected preliminary","position":3,"id_run":5},"5:3:7":{"tag_index":7,"mqc_outcome":"Undecided final","position":3,"id_run":5},"5:3:5":{"tag_index":5,"mqc_outcome":"Rejected final","position":3,"id_run":5},"5:3:4":{"tag_index":4,"mqc_outcome":"Accepted final","position":3,"id_run":5},"5:3:2":{"tag_index":2,"mqc_outcome":"Accepted preliminary","position":3,"id_run":5}},"seq":{"5:4":{"mqc_outcome":"Rejected final","position":4,"id_run":5},"5:3":{"mqc_outcome":"Accepted final","position":3,"id_run":5}}}';
  $response = request($url);
  is($response->code, 200, "response code for '$url' is 200");
  is($response->content, $expected, 'response content');

  $url = '/qcoutcomes?rpt_list=5%3A4&rpt_list=5%3A3&rpt_list=5%3A1';
  $expected = '{"lib":{"5:3:6":{"tag_index":6,"mqc_outcome":"Undecided","position":3,"id_run":5},"5:4":{"mqc_outcome":"Accepted preliminary","position":4,"id_run":5},"5:3:3":{"tag_index":3,"mqc_outcome":"Rejected preliminary","position":3,"id_run":5},"5:3:7":{"tag_index":7,"mqc_outcome":"Undecided final","position":3,"id_run":5},"5:3:5":{"tag_index":5,"mqc_outcome":"Rejected final","position":3,"id_run":5},"5:3:4":{"tag_index":4,"mqc_outcome":"Accepted final","position":3,"id_run":5},"5:3:2":{"tag_index":2,"mqc_outcome":"Accepted preliminary","position":3,"id_run":5}},"seq":{"5:4":{"mqc_outcome":"Rejected final","position":4,"id_run":5},"5:3":{"mqc_outcome":"Accepted final","position":3,"id_run":5},"5:1":{"mqc_outcome":"Accepted preliminary","position":1,"id_run":5}}}';
  $response = request($url);
  is($response->code, 200, "response code for '$url' is 200");
  is($response->content, $expected, 'response content');

  $url = '/qcoutcomes?rpt_list=5%3A4&rpt_list=5%3A3%3A7';
  $expected = '{"lib":{"5:4":{"mqc_outcome":"Accepted preliminary","position":4,"id_run":5},"5:3:7":{"tag_index":7,"mqc_outcome":"Undecided final","position":3,"id_run":5}},"seq":{"5:4":{"mqc_outcome":"Rejected final","position":4,"id_run":5},"5:3":{"mqc_outcome":"Accepted final","position":3,"id_run":5}}}';
  $response = request($url);
  is($response->code, 200, "response code for '$url' is 200");
  is($response->content, $expected, 'response content');

  $url = '/qcoutcomes?rpt_list=5%3A4&rpt_list=5%3A3%3A7&rpt_list=5%3A3';
  $expected = '{"lib":{"5:3:6":{"tag_index":6,"mqc_outcome":"Undecided","position":3,"id_run":5},"5:4":{"mqc_outcome":"Accepted preliminary","position":4,"id_run":5},"5:3:3":{"tag_index":3,"mqc_outcome":"Rejected preliminary","position":3,"id_run":5},"5:3:7":{"tag_index":7,"mqc_outcome":"Undecided final","position":3,"id_run":5},"5:3:5":{"tag_index":5,"mqc_outcome":"Rejected final","position":3,"id_run":5},"5:3:4":{"tag_index":4,"mqc_outcome":"Accepted final","position":3,"id_run":5},"5:3:2":{"tag_index":2,"mqc_outcome":"Accepted preliminary","position":3,"id_run":5}},"seq":{"5:4":{"mqc_outcome":"Rejected final","position":4,"id_run":5},"5:3":{"mqc_outcome":"Accepted final","position":3,"id_run":5}}}';
  $response = request($url);
  is($response->code, 200, "response code for '$url' is 200");
  is($response->content, $expected, 'response content');

  $url = '/qcoutcomes?rpt_list=5%3A3%3A5&rpt_list=5%3A3%3A7';
  $expected = '{"lib":{"5:3:7":{"tag_index":7,"mqc_outcome":"Undecided final","position":3,"id_run":5},"5:3:5":{"tag_index":5,"mqc_outcome":"Rejected final","position":3,"id_run":5}},"seq":{"5:3":{"mqc_outcome":"Accepted final","position":3,"id_run":5}}}';
  $response = request($url);
  is($response->code, 200, "response code for '$url' is 200");
  is($response->content, $expected, 'response content');
};

1;
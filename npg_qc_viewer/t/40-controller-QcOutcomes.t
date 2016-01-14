use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;
use URI::Escape qw(uri_escape);
use JSON::XS;

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

#use HTTP::Request::Common;

subtest 'retrieving data via GET and POST' => sub {
  plan tests => 34;

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
  my $r1 = request($base_url);
  #my $r2 = request POST $base_url;
  for my $response ($r1) {
    ok($response->is_error, "response for '$base_url' is an error");
    is($response->code, 400, 'error code is 400 - bad request' );
    is($response->header('Content-type'), 'application/json', 'json content type');
    is($response->content, '{"error":"rpt list not defined!"}', 'error message');
  }

  my $url = join q[?], $base_url, 'rpt_list=wrong';
  $r1 = request($url);
  #$r2 = request POST $base_url, ['wrong' => {}];
  for my $response ($r1) {
    ok($response->is_error, "response for '$url' is an error");
    is($response->code, 400, 'error code is 400 - bad request' );
    like($response->content,
      qr/Both id_run and position should be available/, 'error message');
  }

  $url = join q[?], $base_url, 'rpt_list='. uri_escape('5:8:7;5:8:8');
  $r1 = request($url);
  #$r2 = request POST $base_url, ['5:8:7;5:8:8' => {}];
  for my $response ($r1) {
    ok($response->is_error, "response for '$url (5:8:7;5:8:8)' is an error");
    is($response->code, 400, 'error code is 400 - bad request' );
    like($response->content,
      qr/Cannot deal with multi-component compositions/, 'error message');
  }

  $url = join q[?], $base_url, 'rpt_list='. uri_escape('5:3:7');
  $r1 = request($url);
  #$r2 = request POST $base_url, ['5:3:7' => {}];
  for my $response ($r1) {
    ok($response->is_success, 'success');
    is($response->code, 200, "response code for '$url (5:3:7)' is 200");
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
    my $url = $base_url . '?' . join q[&], map {'rpt_list=' . uri_escape($_)}
      @{npg_tracking::glossary::rpt->split_rpts($rpt_list)};
    my $response = request($url);
    is($response->code, 200, "response code for '$url ($rpt_list)' is 200");
    is_deeply(decode_json($response->content), decode_json($jsons->[$j]), 'response content');
           
    $j++;        
  }
};

1;
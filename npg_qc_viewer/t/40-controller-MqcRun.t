use strict;
use warnings;
use Test::More tests => 31;
use Test::Exception;
use HTTP::Request;
use JSON;
use t::util;

my $util = t::util->new();
local $ENV{CATALYST_CONFIG} = $util->config_path;

use_ok 'Catalyst::Test', 'npg_qc_viewer';
use_ok 'npg_qc_viewer::Controller::MqcRun';

my $schema;
lives_ok { $schema = $util->test_env_setup()} 'test db created and populated';

{
  for my $url (qw(/mqc/mqc_runs /mqc/mqc_libraries)) {
    for my $method (qw(POST PUT)) {
      my $response = request(HTTP::Request->new($method, $url));
      ok($response->is_error, qq[$url does not accept $method]);
      is( $response->code, 405, 'error code is 405' );
    }
  }
}

{
  my $response = request(HTTP::Request->new('GET', '/mqc/mqc_runs' ));
  ok($response->is_error, q[no id_run, error]);
  is( $response->code, 500, 'error code is 500' );
  like($response->content, qr/"error":"Run id is needed/, 'correct error message');

  $response = request(HTTP::Request->new('GET', '/mqc/mqc_runs/3500' ));
  my $expected = {
           'current_user'               => q[],
           'has_manual_qc_role'         => q[],
           'id_run'                     => '3500',
           'taken_by'                   => 'pipeline',
           'qc_lane_status'             => {},
           'current_status_description' => 'qc complete',
         };
  is_deeply(from_json($response->content, {utf8 => 1}), $expected, 'json response is correct');

  $response = request(HTTP::Request->new('GET', '/mqc/mqc_runs/3500?user=cat&password=secret' ));
  $expected->{'current_user'} = 'cat';
  $expected->{'has_manual_qc_role'} = '1';
  is_deeply(from_json($response->content, {utf8 => 1}), $expected, 'json response is correct');
}

{
  my $response = request(HTTP::Request->new('GET', '/mqc/mqc_libraries' ));
  ok($response->is_error, q[no identifier - error]);
  is($response->code, 500, 'error code is 500' );
  like($response->content, qr/Both run id and position are needed/, 'error content');

  $response = request(HTTP::Request->new('GET', '/mqc/mqc_libraries/3500' ));
  ok($response->is_error, q[no identifier - error]);
  is($response->code, 500, 'error code is 500' );
  like($response->content, qr/Both run id and position are needed/, 'error content');

  $response = request(HTTP::Request->new('GET', '/mqc/mqc_libraries/4025_1' ));
  ok(!$response->is_error, q[no error]);
  is($response->code, 200, 'response code is 200');
  my $expected = {
           'current_user'               => q[],
           'has_manual_qc_role'         => q[],
           'qc_plex_status'             => {},
           'mqc_lib_limit'              => 50,
           'position'                   => '1',
           'id_run'                     => '4025',
           'taken_by'                   => 'pipeline',
           'current_lane_outcome'       => 'Undecided',
           'current_status_description' => 'qc complete',
           'qc_tags'                    => [],
           'non_qc_tags'                => [],
         };
  is_deeply(from_json($response->content, {utf8 => 1}), $expected, 'json response is correct');

  $response = request(HTTP::Request->new('GET', '/mqc/mqc_libraries/4950_4' ));
  ok($response->is_error, q[run does not exists - error]);
  is($response->code, 500, 'error code is 500');

  my $values = {
    'id_run'               => 4950,
    'id_instrument'        => 110,
    'priority'             => 1,
    'actual_cycle_count'   => 512,
    'expected_cycle_count' => 512,
    'is_paired'            => 0,
    'batch_id'             => 0,
    'id_instrument_format' => 11,
    'team'                 => 'A',
  };
  $schema->{'npg'}->resultset('Run')->create($values);
  $values = {
    'id_run'     => 4950,
    'position'   => 1,
    'tile_count' => 100,
    'tracks'     => 2
  };
  $schema->{'npg'}->resultset('RunLane')->create($values);
  $values = {
    'id_run'             => 4950,
    'id_run_status_dict' => 19,
    'id_user'            => 10,
    'iscurrent'          => 1,
  };
  $schema->{'npg'}->resultset('RunStatus')->create($values);

  $response = request(HTTP::Request->new('GET', '/mqc/mqc_libraries/4950_1' ));
  ok(!$response->is_error, q[no error]);
  is($response->code, 200, 'response code is 200');
  $expected = {
           'current_user'               => q[],
           'has_manual_qc_role'         => q[],
           'qc_plex_status'             => {},
           'mqc_lib_limit'              => 50,
           'position'                   => '1',
           'id_run'                     => '4950',
           'taken_by'                   => q[sl1],
           'current_lane_outcome'       => 'Undecided',
           'current_status_description' => 'qc review pending',
           'qc_tags'                    => [(1 .. 24)],
           'non_qc_tags'                => [0],
         };
  is_deeply(from_json($response->content, {utf8 => 1}), $expected, 'some qc, some non-qc tags');

  my $product_rs = $schema->{'mlwh'}->resultset(q[IseqProductMetric])->search(
                     {'me.id_run'=>4950, 'me.position'=>1},
                     {prefetch => 'iseq_flowcell',}
                   );
  while (my $row = $product_rs->next) {
    my $f = $row->iseq_flowcell;
    if ($f) {
      $f->update({id_lims => 'C_GCLP'});
    }
  }

  $response = request(HTTP::Request->new('GET', '/mqc/mqc_libraries/4950_1' ));
  $expected->{'qc_tags'} = [];
  $expected->{'non_qc_tags'} = [(0 .. 24)];
  is_deeply(from_json($response->content, {utf8 => 1}), $expected,
    'GCLP lane - all tags are non-qc');
}

1;
use strict;
use warnings;
use Test::More tests => 16;
use Test::Exception;

use npg_qc_viewer::TransferObjects::ProductMetrics4RunTO;
use t::util;

use_ok 'npg_qc_viewer::Model::LimsServer';

my $util = t::util->new(fixtures => 0);
lives_ok { $util->test_env_setup()}  'test db created and populated';
local $ENV{CATALYST_CONFIG} = $util->config_path;
use_ok 'Catalyst::Test', 'npg_qc_viewer';

{
  my $s = npg_qc_viewer::Model::LimsServer->new();
  isa_ok($s, 'npg_qc_viewer::Model::LimsServer');
  throws_ok { $s->generate_url() } qr/Entity type \(library|pool|sample\) is missing/,
    'missing args error';
  throws_ok { $s->generate_url('study') } qr/Unknown entity type study/,
    'wrong entity type error';
  throws_ok { $s->generate_url('sample') } qr/LIMS values object is missing/,
    'missing args error';
  throws_ok { $s->generate_url('sample', {'my' => 'yours'}) }
    qr/npg_qc_viewer::TransferObjects::ProductMetrics4RunTO is expected, got HASH/,
    'wrong type arg error';

  my $values = npg_qc_viewer::TransferObjects::ProductMetrics4RunTO->new(
    id_run            => 1234,
    position          => 6,
    id_sample_lims    => 123,
    id_library_lims   => '1235678:A2',
    entity_id_lims    => '123567X',
    legacy_library_id => 12345,
    is_gclp           => 0,
    num_cycles        => 33
  );

  is($s->generate_url('sample', $values), 
    q[http://sscape.com/samples/123], 'sscape sample url');
  $values->is_gclp(1);
  is($s->generate_url('sample', $values),
    q[http://clarity.com/clarity/search?scope=Sample&query=123],'clarity sample url');
  $values->id_sample_lims('123:re');
  is($s->generate_url('sample', $values),
     q[http://clarity.com/clarity/search?scope=Sample&query=123:re],
    'clarity sample url');

  $values->is_gclp(0);
  is($s->generate_url('library', $values), 
    q[http://sscape.com/assets/12345], 'sscape library url');
  $values->is_gclp(1);
  is($s->generate_url('library', $values),
     q[http://clarity.com/clarity/search?scope=Container&query=1235678],
    'clarity container url');
  $values->id_library_lims('1235678');
  is($s->generate_url('library', $values),
     q[http://clarity.com/clarity/search?scope=Container&query=1235678],
    'clarity container url');

  is($s->generate_url('pool', $values),
     q[], 'clarity container url is empty');
  $values->is_gclp(0);
  is($s->generate_url('pool', $values), 
    q[http://sscape.com/assets/123567X], 'sscape pool url');     
}

1;

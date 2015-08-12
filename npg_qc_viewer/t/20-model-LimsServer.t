use strict;
use warnings;
use Test::More tests => 14;
use Test::Exception;
use t::util;

use_ok 'npg_qc_viewer::Model::LimsServer';

my $util = t::util->new();
lives_ok { $util->test_env_setup()}  'test db created and populated';
local $ENV{CATALYST_CONFIG} = $util->config_path;
use_ok 'Catalyst::Test', 'npg_qc_viewer';

{
  my $s = npg_qc_viewer::Model::LimsServer->new();
  isa_ok($s, 'npg_qc_viewer::Model::LimsServer');
  throws_ok { $s->generate_url() } qr/Entity type \(library|sample\) is missing/,
    'missing args error';
  throws_ok { $s->generate_url('study') } qr/Unknown entity type study/,
    'wrong entity type error';
  throws_ok { $s->generate_url('sample') } qr/LIMS flag is missing/,
    'missing args error';
  throws_ok { $s->generate_url('sample', 0) } qr/LIMS object id is missing/,
    'missing args error';
  is($s->generate_url('sample', 0, '123'), 
    q[http://sscape.com/samples/123], 'sscape sample url');
  is($s->generate_url('sample', 1, '123'),
     q[http://clarity.com/clarity/search?scope=Sample&query=123],
    'clarity sample url');
    is($s->generate_url('sample', 1, '123:re'),
     q[http://clarity.com/clarity/search?scope=Sample&query=123:re],
    'clarity sample url');
  is($s->generate_url('library', 0, '123567'), 
    q[http://sscape.com/assets/123567],
    'sscape library url');
  is($s->generate_url('library', 1, '1235678:A2'),
     q[http://clarity.com/clarity/search?scope=Container&query=1235678],
    'clarity container url');
  is($s->generate_url('library', 1, '1235678'),
     q[http://clarity.com/clarity/search?scope=Container&query=1235678],
    'clarity container url');   
}

1;

use strict;
use warnings;
use lib 't/lib';
use Test::More tests => 12;
use Test::Exception;

use npg_qc_viewer::Util::TransferObject;
use t::util;

use_ok 'npg_qc_viewer::Model::LimsServer';

my $util = t::util->new(fixtures => 0);
lives_ok { $util->test_env_setup()}  'test db created';
local $ENV{CATALYST_CONFIG} = $util->config_path;
use_ok 'Catalyst::Test', 'npg_qc_viewer';

{
  my $s = npg_qc_viewer::Model::LimsServer->new();
  isa_ok($s, 'npg_qc_viewer::Model::LimsServer');
  throws_ok { $s->generate_url() } qr/Unknown entity type ""/,
    'missing args error';
  throws_ok { $s->generate_url('study') } qr/Unknown entity type "study"/,
    'wrong entity type error';
  throws_ok { $s->generate_url('sample', {'my' => 'yours'}) }
    qr/Util::TransferObject is expected/, 'wrong type arg error';

  my $values = npg_qc_viewer::Util::TransferObject->new(
    id_run            => 1234,
    position          => 6,
    sample_id         => 123,
    id_library_lims   => '1235678:A2',
    entity_id_lims    => '123567X',
    legacy_library_id => 12345,
    lims_live         => 1,
    num_cycles        => 33
  );

  is($s->generate_url('sample', $values), 
    q[http://sscape.com/samples/123], 'sscape sample url');
  is($s->generate_url('library', $values), 
    q[http://sscape.com/assets/12345], 'sscape library url');
  is($s->generate_url('pool', $values), 
    q[http://sscape.com/assets/123567X], 'sscape pool url');  

  $values = npg_qc_viewer::Util::TransferObject->new(
    id_run            => 1234,
    position          => 6,
    sample_id         => 123,
    id_library_lims   => '1235678:A2',
    entity_id_lims    => '123567X',
    legacy_library_id => 12345,
    lims_live         => 0,
    num_cycles        => 33
  );
  is($s->generate_url('sample', $values),q[],'url is empty');

  $values = npg_qc_viewer::Util::TransferObject->new(
    id_run            => 1234,
    position          => 6,
    sample_id         => 123,
    id_library_lims   => '1235678:A2',
    entity_id_lims    => '123567X',
    lims_live         => 1,
    num_cycles        => 33
  );
  is($s->generate_url('library', $values), q[], 'url is an empty string');
}

1;

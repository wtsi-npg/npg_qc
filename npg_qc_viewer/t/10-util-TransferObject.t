use strict;
use warnings;
use Test::More tests => 2;

use_ok 'npg_qc_viewer::Util::TransferObject';

subtest 'LIMs data' => sub {
  plan tests => 7;

  my $to = npg_qc_viewer::Util::TransferObject->new(
    id_run            => 1234,
    position          => 6,
    id_library_lims   => '1235678:A2',
    entity_id_lims    => '123567X',
    legacy_library_id => 12345,
    lims_live         => 1,
    num_cycles        => 33,
    sample_id         => 'S4567',
    sample_name       => 'sample 1',
    study_name        => 'study 2',
    sample_supplier_name => 'sample X',
    instance_qc_able  => 1
  );

  isa_ok($to, 'npg_qc_viewer::Util::TransferObject');

  is (join(q[|],$to->provenance), '1235678:A2|sample 1|study 2', 'provenance');
  is ($to->sample_name4display, 'sample X', 'display sample name');

  $to = npg_qc_viewer::Util::TransferObject->new(
    id_run            => 1234,
    position          => 6,
    id_library_lims   => '1235678:A2',
    entity_id_lims    => '123567X',
    legacy_library_id => 12345,
    num_cycles        => 33,
    sample_id         => 'S4567',
    sample_name       => 'sample 1',
    study_name        => 'study 2',
  );
  is ($to->sample_name4display, 'sample 1', 'display sample name');

  $to = npg_qc_viewer::Util::TransferObject->new(
    id_run            => 1234,
    position          => 6,
    entity_id_lims    => '123567X',
    legacy_library_id => 12345,
    num_cycles        => 33,
    sample_id         => 'S4567',
    sample_name       => 'sample 1',
    study_name        => 'study 2',
  );
  is (join(q[|],$to->provenance), 'sample 1|study 2', 'provenance');

  $to = npg_qc_viewer::Util::TransferObject->new(
    id_run            => 1234,
    position          => 6,
    entity_id_lims    => '123567X',
    legacy_library_id => 12345,
    num_cycles        => 33,
    sample_id         => 'S4567',
    sample_name       => 'sample 1',
  );
    is (join(q[|],$to->provenance), 'sample 1', 'provenance');

  $to = npg_qc_viewer::Util::TransferObject->new(
    id_run            => 1234,
    position          => 6,
    entity_id_lims    => '123567X',
    legacy_library_id => 12345,
    num_cycles        => 33,
    sample_id         => 'S4567',
    sample_supplier_name => 'sample 1',
  );
  is (join(q[|], $to->provenance), q[], 'provenance');
};

1;


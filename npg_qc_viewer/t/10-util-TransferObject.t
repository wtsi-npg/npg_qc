use strict;
use warnings;
use Test::More tests => 11;

use_ok 'npg_qc_viewer::Util::TransferObject';

{
  my $to = npg_qc_viewer::Util::TransferObject->new(
    id_run            => 1234,
    position          => 6,
    id_sample_lims    => 123,
    id_library_lims   => '1235678:A2',
    entity_id_lims    => '123567X',
    legacy_library_id => 12345,
    is_gclp           => 0,
    num_cycles        => 33,
    id_sample_lims    => 'S4567',
    sample_name       => 'sample 1',
    study_name        => 'study 2',
    supplier_sample_name => 'sample X',
    tag_sequence      => 'acgt'
  );

  isa_ok($to, 'npg_qc_viewer::Util::TransferObject');

  is (join(q[|],$to->provenance), '1235678:A2|sample 1|study 2', 'provenance');
  is ($to->sample_name4display, 'sample X', 'display sample name');
  $to->supplier_sample_name(undef);
  is ($to->sample_name4display, 'sample 1', 'display sample name');
  $to->supplier_sample_name('sample Y');
  $to->reset_as_pool();
  is ($to->sample_name4display, undef, 'display sample name for a pool is undefined');
  foreach my $attr (qw/tag_sequence
                       study_name
                       id_sample_lims
                       sample_name
                       supplier_sample_name/) {
    is ($to->$attr, undef, "pool $attr value is undefined");
  }
}

1;
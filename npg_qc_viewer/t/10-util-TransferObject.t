use strict;
use warnings;
use Test::More tests => 12;

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

subtest 'Transfer object qc_able' => sub {
  plan tests => 19;
  my $id_run = 1;
  my $position = 1;
  my $to = npg_qc_viewer::Util::TransferObject->new({
    id_run => $id_run,
    position => $position
  });

  #Params gclp, control, tag_index
  ok($to->qc_able(0, 0, 1), q[Is qc'able when not control, not gclp, tag index not 0]);
  ok(!$to->qc_able(1, 0, 1), q[Is not qc'able when is gclp]);
  ok(!$to->qc_able(0, 1, 1), q[Is not qc'able when is control]);
  ok(!$to->qc_able(0, 0, 0), q[Is not qc'able when is tag index 0]);
  ok($to->qc_able(0, 0), q[Is qc'able when no tag index]);
  ok($to->qc_able(1, 0), q[Is qc'able when no tag index]);
  ok($to->qc_able(0, 1), q[Is qc'able when no tag index]);

  ok(npg_qc_viewer::Util::TransferObject->qc_able(0, 0, 1), q[Is qc'able (class method) when not control, not gclp, tag index not 0]);
  ok(!npg_qc_viewer::Util::TransferObject->qc_able(1, 0, 1), q[Is not qc'able (class method) when is gclp]);
  ok(!npg_qc_viewer::Util::TransferObject->qc_able(0, 1, 1), q[Is not qc'able (class method) when is control]);
  ok(!npg_qc_viewer::Util::TransferObject->qc_able(0, 0, 0), q[Is not qc'able (class method) when is tag index 0]);
  ok(npg_qc_viewer::Util::TransferObject->qc_able(0, 0), q[Is qc'able (class method) when no tag index]);
  ok(npg_qc_viewer::Util::TransferObject->qc_able(1, 0), q[Is qc'able (class method) when no tag index]);
  ok(npg_qc_viewer::Util::TransferObject->qc_able(0, 1), q[Is qc'able (class method) when no tag index]);

  $to = npg_qc_viewer::Util::TransferObject->new({
    id_run     => $id_run,
    position   => $position,
    is_gclp    => 0,
    is_control => 0,
    tag_index  => 1
  });
  ok($to->instance_qc_able, q[Intance is qc'able when not control, not gclp, tag index not 0]);
  $to->is_gclp(1);
  ok(!$to->instance_qc_able, q[Intance is not qc'able when is gclp]);
  $to->is_gclp(0); $to->is_control(1);
  ok(!$to->instance_qc_able, q[Intance is not qc'able when is control]);
  $to->is_control(0); $to->tag_index(0);
  ok(!$to->instance_qc_able, q[Intance is not qc'able when is tag index 0]);
  $to = npg_qc_viewer::Util::TransferObject->new({
    id_run     => $id_run,
    position   => $position,
    is_gclp    => 0,
    is_control => 0
  });
  ok($to->instance_qc_able, q[Intance is qc'able when no tag index]);
};

1;


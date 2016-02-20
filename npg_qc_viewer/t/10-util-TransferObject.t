use strict;
use warnings;
use Test::More tests => 3;
use Test::Exception;

use_ok 'npg_qc_viewer::Util::TransferObject';

subtest 'LIMs data' => sub {
  plan tests => 10;

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
    study_name       => 'study 2',
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
};

subtest 'qc_able' => sub {
  plan tests => 24;

  my $to = npg_qc_viewer::Util::TransferObject->new(
    id_run => 1, position => 1);

  for my $entity ($to, 'npg_qc_viewer::Util::TransferObject') {
    my $calling_as = ref $entity ? q[instance method] : q[class method];
    #Parameters gclp, control, tag_index
    throws_ok {$entity->qc_able()} qr/Both gclp and control flags should be defined/,
                                   qq[Throws exception ($calling_as) when is_gclp is undefined];
    throws_ok {$entity->qc_able(0)} qr/Both gclp and control flags should be defined/,
                                    qq[Throws exception ($calling_as) when is_control is undefined];
    ok($entity->qc_able(0, 0, 1), qq[Is qc'able ($calling_as) when not control, not gclp, tag index not 0]);
    ok(!$entity->qc_able(1, 0, 1), qq[Is not qc'able ($calling_as) when is gclp]);
    ok(!$entity->qc_able(0, 1, 1), qq[Is not qc'able ($calling_as) when is control]);
    ok(!$entity->qc_able(0, 0, 0), qq[Is not qc'able ($calling_as) when is tag index 0]);
    ok($entity->qc_able(0, 0), qq[Is qc'able ($calling_as) when no tag index]);
    ok($entity->qc_able(1, 0), qq[Is qc'able ($calling_as) when no tag index]);
    ok($entity->qc_able(0, 1), qq[Is qc'able ($calling_as) when no tag index]);
  }

  my $values = {id_run     => 22,
                position   => 2,
                is_gclp    => 0,
                is_control => 0,
                tag_index  => 1};
  $to = npg_qc_viewer::Util::TransferObject->new($values);
  ok($to->instance_qc_able,
    q[Intance is qc'able when not control, not gclp, tag index not 0]);
  $values->{'is_gclp'} = 1;
  $to = npg_qc_viewer::Util::TransferObject->new($values);
  ok(!$to->instance_qc_able, q[Intance is not qc'able when is gclp]);
  $values->{'is_gclp'} = 0;
  $values->{'is_control'} = 1;
  $to = npg_qc_viewer::Util::TransferObject->new($values);
  ok(!$to->instance_qc_able, q[Intance is not qc'able when is control]);
  $values->{'is_control'} = 1;
  $values->{'tag_index'} = 0;
  $to = npg_qc_viewer::Util::TransferObject->new($values);
  ok(!$to->instance_qc_able, q[Intance is not qc'able when is tag index 0]);
  delete $values->{'tag_index'};
  $to = npg_qc_viewer::Util::TransferObject->new($values);
  ok($to->instance_qc_able, q[Lane is qc'able]);
  $values->{'instance_qc_able'} = 0;
  $to = npg_qc_viewer::Util::TransferObject->new($values);
  ok(!$to->instance_qc_able,
    q[Attribute set to false on object construction - lane is qc'able]);
};

1;


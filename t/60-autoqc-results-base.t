use strict;
use warnings;
use Test::More tests => 7;
use Test::Exception;

my $cp  = q[npg_tracking::glossary::composition::component::illumina];

subtest 'load the packages' => sub {
  use_ok 'npg_qc::autoqc::results::base';
  use_ok ($cp);
  use_ok 'npg_tracking::glossary::composition::factory';
};

subtest 'base object with no composition set' => sub {
  plan tests => 1;
  throws_ok { npg_qc::autoqc::results::base->new() }
    qr/Can only build old style results/,
    'composition needed';
};

subtest 'base object with one-component composition' => sub {
  plan tests => 5;

  my $f = npg_tracking::glossary::composition::factory->new();
  $f->add_component($cp->new(id_run => 1, position => 2));
  my $b = npg_qc::autoqc::results::base->new(composition => $f->create_composition());
  isa_ok ($b, 'npg_qc::autoqc::results::base');
  my $cmps = $b->composition;
  is ($cmps->num_components, 1, 'one component');
  my $digest = 'c674faa835fd34457c29af3492ef291c623ce67a230b29eb8c3b6891a4d98837'; 
  is ($b->composition_digest, $digest, 'digest');
  my $b1 = npg_qc::autoqc::results::base->thaw($b->freeze());
  isa_ok ($b1, 'npg_qc::autoqc::results::base');
  ok ($b1->composition_digest eq $digest, 'objects have the same composition');
};

my $c1 = $cp->new(id_run => 1, position => 2);
my $c2 = $cp->new(id_run => 1, position => 1);
my $c3 = $cp->new(id_run => 1, position => 3, tag_index => 5);
my $c4 = $cp->new(id_run => 1, position => 3, tag_index => 5, subset => 'some');
my $digest1_4 = '13d877ed93b3c1ffeb5c830f6fbfb5cd4613fe089cb1f1b230c8a942343e7489';

subtest 'base object with multi-component composition' => sub {
  plan tests => 4;

  my $f = npg_tracking::glossary::composition::factory->new();
  $f->add_component($c1, $c2, $c3, $c4);
  my $b = npg_qc::autoqc::results::base->new(
    composition => $f->create_composition()
  );
  my $cmps = $b->composition;
  is ($cmps->num_components, 4, 'four components');
  is ($b->composition_digest, $digest1_4, 'digest');
  my $b1 = npg_qc::autoqc::results::base->thaw($b->freeze());
  isa_ok ($b1, 'npg_qc::autoqc::results::base');
  is ($b1->composition_digest, $digest1_4, 'objects have the same composition');
};

subtest 'json is only for instances' => sub{
  plan tests =>1;
  throws_ok { npg_qc::autoqc::results::base->json() }
    qr/"json" method should be called on an object instance/, 
    q[throws exception when json() called on package];
};

subtest 'methods' => sub {
  plan tests => 18;

  my $f = npg_tracking::glossary::composition::factory->new();
  $f->add_component($c1, $c2, $c3, $c4);
  my $b = npg_qc::autoqc::results::base->new(
    composition => $f->create_composition()
  );
  like ($b->to_string, qr/npg_qc::autoqc::results::base/, 'custom to_string');
  throws_ok { $b->equals_byvalue() }
    qr/Can compare to HASH only/,
    'error comparing to undef';
  throws_ok { $b->equals_byvalue(4) }
    qr/Can compare to HASH only/,
    'error comparing to a scalar';
  throws_ok { $b->equals_byvalue($c1) }
    qr/Can compare to HASH only/,
    'error comparing to a component object';
  throws_ok { $b->equals_byvalue({id_run => 2, position => 4}) }
    qr/Not ready to deal with multi-component composition/,
    'error since this object has multiple omponents';

  $f = npg_tracking::glossary::composition::factory->new();
  $f->add_component($c3);
  $b = npg_qc::autoqc::results::base->new(
    composition => $f->create_composition()
  );
  is ($b->equals_byvalue({check_name => 'base'}), 1, 'equal by check name');
  is ($b->equals_byvalue({check_name => 'insert size'}), 0, 'not equal by check name');
  is ($b->equals_byvalue({class_name => 'base'}), 1, 'equal by class name');
  is ($b->equals_byvalue({class_name => 'insert_size'}), 0, 'not equal by class name');
  is ($b->equals_byvalue({id_run => 1}), 1, 'equal by id_run');
  is ($b->equals_byvalue({id_run => 2}), 0, 'no equal by id_run');
  is ($b->equals_byvalue({tag_index => 5}), 1, 'equal by tag_index');
  is ($b->equals_byvalue({tag_index => 4, check_name => 'base'}), 0, 'not equal');

  $f = npg_tracking::glossary::composition::factory->new();
  $f->add_component($c1);
  $b = npg_qc::autoqc::results::base->new(
    composition => $f->create_composition()
  );
  is ($b->equals_byvalue({tag_index => 5, id_run => 1}), 0, 'not equal');
  is ($b->equals_byvalue({tag_index => undef, id_run => 1}), 1, 'equal');
  is ($b->equals_byvalue({position => 2, id_run => 1}), 1, 'equal');
  is ($b->equals_byvalue({position => 2, id_run => 1, tag_index => undef}), 1, 'equal');

  is ($b->filename4serialization, '1_2.base.json', 'file name');
};

subtest 'extended_base' => sub {
  plan tests => 7;

  package npg_qc::autoqc::results::test_extended;
  use Moose;
  extends 'npg_qc::autoqc::results::base';
  with qw( npg_tracking::glossary::run
           npg_tracking::glossary::lane
           npg_tracking::glossary::tag );
  1;

  package main;
  my $eb = npg_qc::autoqc::results::test_extended->new(
    id_run => 1, position => 3, tag_index => 3
  );

  is ($eb->composition->num_components, 1, 'composition created');
  is ($eb->to_string,
    'npg_qc::autoqc::results::test_extended {"components":[{"id_run":1,"position":3,"tag_index":3}]}',
    'to_string via inheritance');
  is ($eb->filename4serialization, '1_3#3.test_extended.json', 
    'filename as result object');
  is ($eb->equals_byvalue({id_run => 1, position => 3, tag_index => 3}),
    1, 'compositions are the same');
  is ($eb->equals_byvalue({id_run => 1, position => 3, tag_index => 4}),
    0, 'compositions are different tag_index');
  is ($eb->equals_byvalue({id_run => 1, position => 3}),
    1, 'compositions are the same for the purpose of search');
  is ($eb->equals_byvalue({id_run => 1, position => 4}),
    0, 'compositions are different');
};

1;

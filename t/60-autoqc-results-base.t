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
  plan tests => 6;

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

  push @{$b->composition->components}, $cp->new(id_run => 1, position => 3);
  throws_ok {$b->freeze()} qr/Composition has changed/, 'object lost integrity';
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
  plan tests => 9;

  my $f = npg_tracking::glossary::composition::factory->new();
  $f->add_component($c1, $c2, $c3, $c4);
  my $b = npg_qc::autoqc::results::base->new(
    composition => $f->create_composition()
  );
  ok (!$b->is_old_style_result, 'not old style object');
  like ($b->to_string, qr/npg_qc::autoqc::results::base/, 'custom to_string');
  throws_ok { $b->equals_byvalue() }
    qr/Nothing to compare to/,
    'error comparing to undef';
  throws_ok { $b->equals_byvalue(4) }
    qr/Cannot evaluate input 4/,
    'error comparing to a scalar';
  throws_ok { $b->equals_byvalue({id_run => 2, position => 4}) }
    qr/Cannot evaluate input HASH/,
    'error comparing to a hash';
  throws_ok { $b->equals_byvalue($c1) }
    qr/Cannot evaluate input npg_tracking::glossary::composition::component/,
    'error comparing to a component object';

  $f = npg_tracking::glossary::composition::factory->new();
  $f->add_component($c2, $c1, $c3, $c4);
  is ($b->equals_byvalue($f->create_composition()), 1, 'compositions are the same');
  $f = npg_tracking::glossary::composition::factory->new();
  $f->add_component($c1, $c2, $c3);
  is ($b->equals_byvalue($f->create_composition()), 0, 'compositions are different');
  is ($b->filename4serialization, $digest1_4 . '.base.json', 'custom filename');
};

subtest 'extended_base' => sub {
  plan tests => 8;

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
  ok ($eb->is_old_style_result, 'old style object');
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

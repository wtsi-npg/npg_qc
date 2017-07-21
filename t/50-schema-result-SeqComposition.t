use strict;
use warnings;
use Test::More tests => 2;
use Moose::Meta::Class;
use npg_tracking::glossary::composition::factory;
use npg_tracking::glossary::composition::component::illumina;
use npg_testing::db;

use_ok('npg_qc::Schema::Result::SeqComposition');

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema]);

subtest q[creating new composition from new and existing components] => sub {
  plan tests => 16;

  my $id_run = 1;

  my $rs_composition = $schema->resultset('SeqComposition');
  my $rs_component   = $schema->resultset('SeqComponent');
  my $rs_cc          = $schema->resultset('SeqComponentComposition');

  my @values = (
    [{id_run => $id_run,position => 2}],
    [{id_run => $id_run,position => 3}, {id_run => $id_run,position => 2}],
    [{id_run => $id_run,position => 2,subset=>'phix'}],
    [{id_run => $id_run,position => 1,tag_index => 22},
     {id_run => $id_run,position => 1,tag_index => 23},
     {id_run => $id_run,position => 1,tag_index => 24}],
    [{id_run => $id_run,position => 1,tag_index => 12},
     {id_run => $id_run,position => 1,tag_index => 13},
     {id_run => $id_run,position => 1,tag_index => 14}],
    [{id_run => $id_run,position => 3,tag_index => 0}],
    [{id_run => $id_run,position => 1,tag_index => 22,subset => 'human'},
     {id_run => $id_run,position => 1,tag_index => 24,subset => 'human'}],
    [{id_run => $id_run,position => 1,tag_index => 25,subset => 'phix'},
     {id_run => $id_run,position => 1,tag_index => 26,subset => 'phix'}],  
  );

  foreach my $values_array (@values) {

    my $f = npg_tracking::glossary::composition::factory->new();
    my @component_ids = ();
    foreach my $value (@{$values_array}) {
      my $component = npg_tracking::glossary::composition::component::illumina
                      ->new($value);
      $f->add_component($component);
      my %temp = %{$value};
      $temp{'digest'} = $component->digest();
      push @component_ids, $rs_component->find_or_create(\%temp)->id_seq_component();
    }
    my $composition = $f->create_composition();
    my $num_components = $composition->num_components;
    my $row = $rs_composition->create(
      {digest => $composition->digest, size => $num_components});
    my $pk_value= $row->id_seq_composition;
    foreach my $id (@component_ids) {
      $rs_cc->create({'size'               => $num_components,
                      'id_seq_component'   => $id,
                      'id_seq_composition' => $pk_value,
                     });
    }

    my $compisition_from_db = $row->create_composition();
    isa_ok($compisition_from_db, 'npg_tracking::glossary::composition');
    ok($compisition_from_db->digest eq $composition->digest(), 'the same composition');
  }
};

1;
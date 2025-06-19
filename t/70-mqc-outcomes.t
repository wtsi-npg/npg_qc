use strict;
use warnings;
use Test::More tests => 17;
use Test::Exception;
use Moose::Meta::Class;
use JSON::XS;
use DateTime;
use DateTime::Duration;
use List::MoreUtils qw/uniq/;

use npg_testing::db;
use npg_tracking::glossary::rpt;
use npg_tracking::glossary::composition::factory::rpt_list;
use t::autoqc_util;

use_ok('npg_qc::mqc::outcomes');

my $qc_schema = Moose::Meta::Class->create_anon_class(
    roles => [qw/npg_testing::db/])
    ->new_object()->create_test_db(
    q[npg_qc::Schema], q[t/data/qcoutcomes/fixtures]);

subtest 'initial assumptions' => sub {
  plan tests => 3;

  is ($qc_schema->resultset('MqcLibraryOutcomeDict')->search({})->count(), 6,
    'mqc library dict table contains 6 rows'); 
  is ($qc_schema->resultset('MqcOutcomeDict')->search({})->count(), 5,
    'mqc dict table contains 5 rows'); 
  is ($qc_schema->resultset('UqcOutcomeDict')->search({})->count(), 3,
    'uqc dict table contains 3 rows');  
};

subtest 'constructor tests' => sub {
  plan tests => 3;

  throws_ok { npg_qc::mqc::outcomes->new() }
    qr/Attribute \(qc_schema\) is required/,
    'qc schema should be provided';

  my $o;
  lives_ok { $o = npg_qc::mqc::outcomes->new(
                  qc_schema  => $qc_schema)}
    'qc schema given - object created';
  isa_ok($o, 'npg_qc::mqc::outcomes');
};

subtest 'retrieval - errors and boundary conditions' => sub {
  plan tests => 3;

  my $o = npg_qc::mqc::outcomes->new(qc_schema  => $qc_schema);
  throws_ok { $o->get() }
    qr/Input is missing or is not an array/,
    'get method requires input';

  throws_ok { $o->get('something') }
    qr/Input is missing or is not an array/,
    'get method requires array input';

  is_deeply($o->get([]), {'lib'=>{},'seq'=>{},'uqc'=>{}}, 'empty request is OK');
};

subtest 'retrieval, lib and seq outcomes for single-component compositions' => sub {
  plan tests => 11;

  my @data = qw( 5:3:7 5:3:7 5:3 5:3:7 5:3 5:4
                 5:4|5:3 5:4|5:3|5:1 5:4|5:3:7
                 5:4|5:3:7|5:3 5:3:5|5:3:7 );
  my $fkeys = {};
  my $rs = $qc_schema->resultset('MqcOutcomeEnt');
  my @expanded_list = uniq map {(split /\|/, $_)}
                      @data, qw(5:2 5:5 5:3:2 5:3:3 5:3:4 5:3:5 5:3:6);

  foreach my $l (@expanded_list) {
    my $c = npg_tracking::glossary::composition::factory::rpt_list
            ->new(rpt_list => $l)->create_composition();
    my $seq_c = $rs->find_or_create_seq_composition($c);
    $fkeys->{$l} =  $seq_c->id_seq_composition();
  }

  my $o = npg_qc::mqc::outcomes->new(qc_schema  => $qc_schema);

  my $expected = {"lib"=>{},"seq"=>{},"uqc"=>{}};
  is_deeply($o->get([qw(5:3:7)]), $expected, q[no data, outcome for 5:3:7 is correct]);

  my $values = {id_run   => 5,
                username => 'u1'};
  # Create seq outcomes for run 5, lanes 1,2,3,4,5
  for my $i (1 .. 5) {
    $values->{'position'}       = $i;
    $values->{'id_mqc_outcome'} = $i;
    $values->{'id_seq_composition'} = $fkeys->{join q[:], 5, $i};
    $qc_schema->resultset('MqcOutcomeEnt')->create($values);
  }

  $expected = {"lib"=>{},"seq"=>{"5:3"=>{"mqc_outcome"=>"Accepted final"}},"uqc"=>{}};
  is_deeply($o->get([qw(5:3:7)]), $expected, q[outcome for 5:3:7  is correct]);
  is_deeply($o->get([qw(5:3)]), $expected, q[outcome for 5:3 is correct]);

  $values     = {id_run    => 5,
                 position  => 3,
                 username  => 'u1'};
  for my $i (2 .. 7) { # Create lib outcomes for run 5, lane 3 tags 2-7
    $values->{'tag_index'}      = $i;
    $values->{'id_mqc_outcome'} = $i-1;
    $values->{'id_seq_composition'} = $fkeys->{join q[:], 5, 3, $i};
    $qc_schema->resultset('MqcLibraryOutcomeEnt')->create($values);
  } 
  
  $expected = {"lib"=>{"5:3:6"=>{"mqc_outcome"=>"Undecided"},"5:3:3"=>{"mqc_outcome"=>"Rejected preliminary"},"5:3:7"=>{"mqc_outcome"=>"Undecided final"},"5:3:5"=>{"mqc_outcome"=>"Rejected final"},"5:3:4"=>{"mqc_outcome"=>"Accepted final"},"5:3:2"=>{"mqc_outcome"=>"Accepted preliminary"}},"seq"=>{"5:3"=>{"mqc_outcome"=>"Accepted final"}},"uqc"=>{}};   
  is_deeply($o->get([qw(5:3:7)]), $expected, q[outcome for 5:3:7 is correct]);
  is_deeply($o->get([qw(5:3)]), $expected, q[outcome for 5:3 is correct]);

  # Create lib outcome for run 5 lane 4 (no tag!)
  $values    = {id_seq_composition => $fkeys->{'5:4'},
                id_run             => 5,
                username           => 'u1',
                position           => 4,
                id_mqc_outcome     => 1};
  $qc_schema->resultset('MqcLibraryOutcomeEnt')->create($values);

  $expected = {"lib"=>{"5:4"=>{"mqc_outcome"=>"Accepted preliminary"}},"seq"=>{"5:4"=>{"mqc_outcome"=>"Rejected final"}},"uqc"=>{}};
  is_deeply($o->get([qw(5:4)]), $expected, q[outcome for 5:4 is correct]);

  #
  # Lists of single-component compositions
  #
  $expected = {"lib"=>{"5:3:6"=>{"mqc_outcome"=>"Undecided"},"5:4"=>{"mqc_outcome"=>"Accepted preliminary"},"5:3:3"=>{"mqc_outcome"=>"Rejected preliminary"},"5:3:7"=>{"mqc_outcome"=>"Undecided final"},"5:3:5"=>{"mqc_outcome"=>"Rejected final"},"5:3:4"=>{"mqc_outcome"=>"Accepted final"},"5:3:2"=>{"mqc_outcome"=>"Accepted preliminary"}},"seq"=>{"5:4"=>{"mqc_outcome"=>"Rejected final"},"5:3"=>{"mqc_outcome"=>"Accepted final"}},"uqc"=>{}};
  is_deeply($o->get([qw(5:4 5:3)]), $expected, q[outcome for (5:4 5:3 5:1) is correct]);

  $expected = {"lib"=>{"5:3:6"=>{"mqc_outcome"=>"Undecided"},"5:4"=>{"mqc_outcome"=>"Accepted preliminary"},"5:3:3"=>{"mqc_outcome"=>"Rejected preliminary"},"5:3:7"=>{"mqc_outcome"=>"Undecided final"},"5:3:5"=>{"mqc_outcome"=>"Rejected final"},"5:3:4"=>{"mqc_outcome"=>"Accepted final"},"5:3:2"=>{"mqc_outcome"=>"Accepted preliminary"}},"seq"=>{"5:4"=>{"mqc_outcome"=>"Rejected final"},"5:3"=>{"mqc_outcome"=>"Accepted final"},"5:1"=>{"mqc_outcome"=>"Accepted preliminary"}},"uqc"=>{}};
  is_deeply($o->get([qw(5:4 5:3 5:1)]), $expected, q[outcome for (5:4 5:3 5:1) is correct]);

  $expected = {"lib"=>{"5:3:6"=>{"mqc_outcome"=>"Undecided"},"5:4"=>{"mqc_outcome"=>"Accepted preliminary"},"5:3:3"=>{"mqc_outcome"=>"Rejected preliminary"},"5:3:7"=>{"mqc_outcome"=>"Undecided final"},"5:3:5"=>{"mqc_outcome"=>"Rejected final"},"5:3:4"=>{"mqc_outcome"=>"Accepted final"},"5:3:2"=>{"mqc_outcome"=>"Accepted preliminary"}},"seq"=>{"5:4"=>{"mqc_outcome"=>"Rejected final"},"5:3"=>{"mqc_outcome"=>"Accepted final"}},"uqc"=>{}};
  is_deeply($o->get([qw(5:4 5:3:7)]), $expected, q[outcome for (5:4 5:3:7) is correct]);
  is_deeply($o->get([qw(5:4 5:3:7 5:3)]), $expected, q[outcome for (5:4 5:3:7 5:3) is correct]);

  $expected = {"lib"=>{"5:3:6"=>{"mqc_outcome"=>"Undecided"},"5:3:3"=>{"mqc_outcome"=>"Rejected preliminary"},"5:3:7"=>{"mqc_outcome"=>"Undecided final"},"5:3:5"=>{"mqc_outcome"=>"Rejected final"},"5:3:4"=>{"mqc_outcome"=>"Accepted final"},"5:3:2"=>{"mqc_outcome"=>"Accepted preliminary"}},"seq"=>{"5:3"=>{"mqc_outcome"=>"Accepted final"}},"uqc"=>{}};
  is_deeply($o->get([qw(5:3:5 5:3:7)]), $expected, q[outcome for (5:3:5 5:3:7) is correct]);
};

subtest 'retrieval, uqc_outcomes for single-component compositions' => sub {
  plan tests => 12;

  my $o = npg_qc::mqc::outcomes->new(qc_schema  => $qc_schema);

  my $rs = $qc_schema->resultset('UqcOutcomeEnt');
  my $keys = {};
  foreach my $key (qw/7:1:1 7:1:3 7:2:1 7:4/) {
    my $c = npg_tracking::glossary::composition::factory::rpt_list
            ->new(rpt_list => $key )->create_composition();
    $keys->{$key} = $rs->find_or_create_seq_composition($c)->id_seq_composition();
  }

  my $values={'last_modified'      => DateTime->now(),
              'username'           => 'u1',
              'modified_by'        =>' user',
              'rationale'          => 'rationale something',
              'id_seq_composition' => $keys->{'7:2:1'},
              'id_uqc_outcome'     => 1
             };
  $rs->create($values);

  my $expected = {'lib' => {},'seq' => {},
                  'uqc' => {'7:2:1' => {'uqc_outcome' => 'Accepted'}}};
  is_deeply ($o->get([qw(7:2:1)]),$expected, q[data retrieved correctly for (7:2:1)]);
  is_deeply ($o->get([qw(7:2:)]), $expected, q[data retrieved correctly for (7:2)]);
  is_deeply ($o->get([qw(7:2:2)]),$expected, q[data retrieved correctly for qw(7:2:2)]);

  $values->{'id_seq_composition'} = $keys->{'7:1:1'};
  $rs->create($values);
  $values->{'id_seq_composition'} = $keys->{'7:1:3'};
  $values->{'id_uqc_outcome'} = 2;
  $rs->create($values);

  $expected = {'lib' => {},'seq' => {},
               'uqc' => {'7:1:1' => {'uqc_outcome' => 'Accepted'},
                         '7:1:3' => {'uqc_outcome' => 'Rejected'},}
              };
  is_deeply ($o->get([qw(7:1:1)]),$expected, q[data retrieved correctly for (7:1:1)]);
  is_deeply ($o->get([qw(7:1:2)]),$expected, q[data retrieved correctly for (7:1:2)]);
  is_deeply ($o->get([qw(7:1)]),$expected, q[data retrieved correctlyfor (7:1)]);
  is_deeply ($o->get([qw(7:1 7:1:2)]), $expected, q[data retrieved correctly for (7:1 7:1:2)]);
  is_deeply ($o->get([qw(7:1:3 7:1:2)]),$expected, q[data retrieved correctly for (7:1:3 7:1:2)]);
  is_deeply ($o->get([qw(7:1:4 7:1:2)]),$expected, q[data retrieved correctly for (7:1:4 7:1:2)]);
  is_deeply ($o->get([qw(7:1:4 7:1:6)]),$expected, q[data retrieved correctly for (7:1:4 7:1:6)]);

  $values->{'id_seq_composition'} = $keys->{'7:4'};
  $values->{'id_uqc_outcome'} = 3;
  $rs->create($values);
  
  $expected->{'uqc'}->{'7:4'} = {'uqc_outcome' => 'Undecided'};
  is_deeply ($o->get([qw(7:1:1 7:4)]), $expected, q[data retrieved correctly for (7:1:1 7:4)]);
  is_deeply ($o->get([qw(7:1:1 7:4:3)]),$expected, q[data retrieved correctly for (7:1:1 7:4:3)]);  
};

subtest 'retrieval for single-component compositions - all outcome types' => sub {
  plan tests => 3;

  my $rs = $qc_schema->resultset('UqcOutcomeEnt');
  my $keys = {};
  my $outcome_id = 0;
  foreach my $key (qw/8:1:1 8:1:3 8:4/) {
    $outcome_id++;
    my $c = npg_tracking::glossary::composition::factory::rpt_list
            ->new(rpt_list => $key )->create_composition();
    my $ckey = $rs->find_or_create_seq_composition($c)->id_seq_composition();
    my $values = {
                'username'           => 'u1',
                'modified_by'        =>' user',
                'rationale'          => 'rationale something',
                'id_seq_composition' => $ckey,
                'id_uqc_outcome'     => $outcome_id
                 };
    $rs->create($values);

    delete $values->{'rationale'};
    delete $values->{'id_uqc_outcome'};
    $values->{'id_mqc_outcome'} = $outcome_id;
    my $component = $c->get_component(0);
    $values->{'id_run'}   = $component->id_run;
    $values->{'position'} = $component->position;
    if ($component->tag_index) {
      $values->{'tag_index'} = $component->tag_index;
    } else {
      $qc_schema->resultset('MqcOutcomeEnt')->create($values);
    }
    $qc_schema->resultset('MqcLibraryOutcomeEnt')->create($values);
  }

  my $o = npg_qc::mqc::outcomes->new(qc_schema => $qc_schema);

  my $expected = {
               'uqc' => { '8:1:1' => {'uqc_outcome' => 'Accepted'},
                          '8:1:3' => {'uqc_outcome' => 'Rejected'}},
               'seq' => {},
               'lib' => { '8:1:1' => {'mqc_outcome' => 'Accepted preliminary'},
                          '8:1:3' => {'mqc_outcome' => 'Rejected preliminary'}}
                 };
  
  is_deeply ($o->get([qw(8:1:1)]), $expected, 'data retrieved correctly for (8:1:1)');
 
  $expected = {
               'lib' => { '8:4'   => {'mqc_outcome' => 'Accepted final'},
                          '8:1:1' => {'mqc_outcome' => 'Accepted preliminary'},
                          '8:1:3' => {'mqc_outcome' => 'Rejected preliminary'}},
               'seq' => {'8:4'    => {'mqc_outcome' => 'Accepted final'}},
               'uqc' => { '8:1:1' => {'uqc_outcome' => 'Accepted'},
                          '8:1:3' => {'uqc_outcome' => 'Rejected'},
                          '8:4'   => {'uqc_outcome' => 'Undecided'}}
              };
  is_deeply ($o->get([qw(8:1:1 8:4)]), $expected, 'data retrieved correctly for (8:1:1 8:4)');
  is_deeply ($o->get([qw(8:1 8:4)]), $expected, 'data retrieved correctly for (8:1 8:4)');
};

subtest 'retrieval for multi-component compositions - all outcome types' => sub {
  plan tests => 8;

  my $o = npg_qc::mqc::outcomes->new(qc_schema => $qc_schema);

  is_deeply ($o->get([qw(80:1:1;80:1:3)]), {'lib'=>{},'seq'=>{},'uqc'=>{}},
    'no data retrieved for (80:1:1;80:1:3)');

  my $c = npg_tracking::glossary::composition::factory::rpt_list
            ->new(rpt_list => q(80:1:1;80:1:3) )->create_composition();
  my $rs = $qc_schema->resultset('UqcOutcomeEnt');
  my $ckey = $rs->find_or_create_seq_composition($c)->id_seq_composition();
  my $values = {
                'username'           => 'u1',
                'modified_by'        =>' user',
                'rationale'          => 'rationale something',
                'id_seq_composition' => $ckey,
                'id_uqc_outcome'     => 1
               };
  $rs->create($values);

  $rs = $qc_schema->resultset('MqcLibraryOutcomeEnt');
  $values    = {
                'username'           => 'u1',
                'modified_by'        =>' user',
                'id_seq_composition' => $ckey,
                'id_mqc_outcome'     => 4
               };
  $rs->create($values);

  my $expected = {
    'uqc' => {'80:1:1;80:1:3' => {'uqc_outcome' => 'Accepted'}},
    'seq' => {},
    'lib' => {'80:1:1;80:1:3' => {'mqc_outcome' => 'Rejected final'}}
                 };
  is_deeply ($o->get([qw(80:1:1;80:1:3)]), $expected,
    'correct data retrieved for (80:1:1;80:1:3)');

  $c = npg_tracking::glossary::composition::factory::rpt_list
            ->new(rpt_list => q(80:1:1;80:1:5) )->create_composition();
  $ckey = $rs->find_or_create_seq_composition($c)->id_seq_composition();
  $values    = {
                'username'           => 'u1',
                'modified_by'        =>' user',
                'id_seq_composition' => $ckey,
                'id_mqc_outcome'     => 3
               };
  $rs->create($values);
  
  $expected = {
    'lib' => {'80:1:1;80:1:3' => {'mqc_outcome' => 'Rejected final'},
              '80:1:1;80:1:5' => {'mqc_outcome' => 'Accepted final'}},
    'uqc' => {'80:1:1;80:1:3' => {'uqc_outcome' => 'Accepted'}},
    'seq' => {}
  };
  is_deeply ($o->get([qw(80:1:1;80:1:3 80:1:1;80:1:5)]), $expected,
    'correct data retrieved for (80:1:1;80:1:3 80:1:1;80:1:5)');

  $rs = $qc_schema->resultset('MqcOutcomeEnt');
  $c = npg_tracking::glossary::composition::factory::rpt_list
            ->new(rpt_list => q(80:1))->create_composition();
  $ckey = $rs->find_or_create_seq_composition($c)->id_seq_composition();
  $values->{'id_seq_composition'} = $ckey;
  $rs->create($values);

  is_deeply ($o->get([qw(80:1:1;80:1:3 80:1:1;80:1:5)]), $expected,
    'correct data retrieved for (80:1:1;80:1:3 80:1:1;80:1:5)');

  $expected->{'seq'} = {'80:1' => {'mqc_outcome' => 'Accepted final'}};
  is_deeply ($o->get([qw(80:1:1;80:1:3 80:1:1;80:1:5 80:1)]), $expected,
    'correct data retrieved for (80:1:1;80:1:3 80:1:1;80:1:5 80:1)');

  $rs = $qc_schema->resultset('MqcLibraryOutcomeEnt');
  $c = npg_tracking::glossary::composition::factory::rpt_list
            ->new(rpt_list => q(80:1:4))->create_composition();
  $ckey = $rs->find_or_create_seq_composition($c)->id_seq_composition();
  $values->{'id_seq_composition'} = $ckey;
  $rs->create($values);
  
  $expected->{'lib'}->{'80:1:4'} = {'mqc_outcome' => 'Accepted final'};
  is_deeply ($o->get([qw(80:1:1;80:1:3 80:1:1;80:1:5 80:1)]), $expected,
    'correct data retrieved for (80:1:1;80:1:3 80:1:1;80:1:5 80:1)');
  is_deeply ($o->get([qw(80:1:1;80:1:3 80:1:1;80:1:5 80:1:4)]), $expected,
    'correct data retrieved for (80:1:1;80:1:3 80:1:1;80:1:5 80:1:4)');
  is_deeply ($o->get([qw(80:1:1;80:1:3 80:1:1;80:1:5 80:1:7)]), $expected,
    'correct data retrieved for (80:1:1;80:1:3 80:1:1;80:1:5 80:1:7)');   
};

subtest q[get mqc library outcomes as boolean outcomes] => sub {
  plan tests => 2;
  
  my @l = qw/26291:1:1;26291:2:1;26291:3:1
             26291:1:2;26291:2:2;26291:3:2
             26291:1:3;26291:2:3;26291:3:3
             26291:1:4;26291:2:4;26291:3:4
             26291:1:5;26291:2:5;26291:3:5
             26291:1:6;26291:2:6;26291:3:6
             26291:1:11;26291:2:11;26291:3:11
             26291:1:12;26291:2:12;26291:3:12
             26291:1:13;26291:2:13;26291:3:13
             26291:1:14;26291:2:14;26291:3:14
             26291:1:15;26291:2:15;26291:3:15
             26291:1:16;26291:2:16;26291:3:16
            /;

  my $rs = $qc_schema->resultset('MqcLibraryOutcomeEnt');
  for my $l (@l) {
    my $c = npg_tracking::glossary::composition::factory::rpt_list
            ->new(rpt_list => $l )->create_composition();
    my $ckey = $rs->find_or_create_seq_composition($c)->id_seq_composition();
    my $values = {
                'username'           => 'u1',
                'modified_by'        =>' user',
                'id_seq_composition' => $ckey,
                'id_mqc_outcome'     => substr($l, -1)
                 };
    $rs->create($values);
  }

  my %expected = map { $_ => 0 } @l;
  $expected{'26291:1:3;26291:2:3;26291:3:3'} = 1;
  $expected{'26291:1:13;26291:2:13;26291:3:13'} = 1;

  my $o = npg_qc::mqc::outcomes->new(qc_schema => $qc_schema);
  my $outcomes = {};
  map { $outcomes->{$_} = $o->get_library_outcome($_) } @l;
  is_deeply ($outcomes, \%expected, 'correct results');
  
  throws_ok { $o->get_library_outcome('26291:1:26;26291:2:26;26291:3:26') }
    qr/No library outcome for '26291:1:26;26291:2:26;26291:3:26'/,
    'error if a lib outcome for rpt list does not exist';
};

subtest q[find or create outcome - error handling] => sub {
  plan tests => 4;

  my $o = npg_qc::mqc::outcomes->new(qc_schema => $qc_schema);

  throws_ok { $o->_find_or_new_outcome() }
    qr/Two arguments required/, 'no arguments - error';
  throws_ok { $o->_find_or_new_outcome('lib') }
    qr/Two arguments required/, 'one arguments - error';
  throws_ok { $o->_find_or_new_outcome('some', {}) }
    qr/Unknown outcome entity type \'some\'/, 'unknown entity type - error';
  throws_ok { $o->_find_or_new_outcome('lib', {}) }
    qr/Composition object argument expected/, 'not passing composition type object - error';
};

subtest q[find or create lib entity] => sub {
  plan tests => 30;

  my $o = npg_qc::mqc::outcomes->new(qc_schema => $qc_schema);
  my $c = npg_tracking::glossary::composition::factory::rpt_list
         ->new(rpt_list => '45:2:1')->create_composition();
  my $row = $o->_find_or_new_outcome('lib', $c);
  isa_ok($row, 'npg_qc::Schema::Result::MqcLibraryOutcomeEnt');
  ok(!$row->in_storage, 'new object is created in memory');
  is($row->id_run, 45, 'correct run id');
  is($row->position, 2, 'correct position');
  is($row->tag_index, 1, 'tag index is 1');
  is($row->username, undef, 'username is undefined');
  is($row->modified_by, undef, 'modified_by is undefined');
  ok(!$row->mqc_outcome, 'no related dictionary object');

  my $dict_id = $qc_schema->resultset('MqcLibraryOutcomeDict')
    ->search({'short_desc' => 'Rejected preliminary'})
    ->next->id_mqc_library_outcome;

  $c = npg_tracking::glossary::composition::factory::rpt_list
          ->new(rpt_list => '45:3:1')->create_composition();
  my $seq_c = $qc_schema->resultset('MqcLibraryOutcomeEnt')
              ->find_or_create_seq_composition($c);
  $qc_schema->resultset('MqcLibraryOutcomeEnt')->create({
    'id_run'         => 45,
    'position'       => 3,
    'tag_index'      => 1,
    'id_seq_composition' => $seq_c->id_seq_composition(),
    'id_mqc_outcome' => $dict_id,
    'username'       => 'cat',
    'modified_by'    => 'dog',
  });

  $row = $o->_find_or_new_outcome('lib',$c);
  isa_ok($row, 'npg_qc::Schema::Result::MqcLibraryOutcomeEnt');
  ok($row->in_storage, 'object is retrieved from the db');
  is($row->id_run, 45, 'correct run id');
  is($row->position, 3, 'correct position');
  is($row->tag_index, 1, 'tag index is 1');
  is($row->username, 'cat', 'username is "cat"');
  is($row->modified_by, 'dog', 'modified by dog');
  ok($row->mqc_outcome, 'related dictionary object exists');
  is($row->mqc_outcome->short_desc, 'Rejected preliminary',
    'correct outcome description');

  $c = npg_tracking::glossary::composition::factory::rpt_list
         ->new(rpt_list => '45:2')->create_composition();
  $row = $o->_find_or_new_outcome('lib', $c);
  isa_ok($row, 'npg_qc::Schema::Result::MqcLibraryOutcomeEnt');
  ok(!$row->in_storage, 'new object is created in memory');
  is($row->id_run, 45, 'correct run id');
  is($row->position, 2, 'correct position');
  is($row->tag_index, undef, 'tag index not defined');
  ok(!$row->mqc_outcome, 'no related dictionary object');

  my $c_45_4 = npg_tracking::glossary::composition::factory::rpt_list
         ->new(rpt_list => '45:4')->create_composition();
  $seq_c = $qc_schema->resultset('MqcLibraryOutcomeEnt')
         ->find_or_create_seq_composition($c_45_4);
  $qc_schema->resultset('MqcLibraryOutcomeEnt')->create({
    'id_run'         => 45,
    'position'       => 4,
    'id_seq_composition' => $seq_c->id_seq_composition(),
    'id_mqc_outcome' => $dict_id,
    'username'       => 'cat',
    'modified_by'    => 'dog',
  });

  $c = npg_tracking::glossary::composition::factory::rpt_list
         ->new(rpt_list => '45:4:1')->create_composition();
  $seq_c = $qc_schema->resultset('MqcLibraryOutcomeEnt')
         ->find_or_create_seq_composition($c);
  $qc_schema->resultset('MqcLibraryOutcomeEnt')->create({
    'id_run'         => 45,
    'position'       => 4,
    'tag_index'      => 1,
    'id_seq_composition' => $seq_c->id_seq_composition(),
    'id_mqc_outcome' => $dict_id,
    'username'       => 'cat',
    'modified_by'    => 'dog',
  });

  $row = $o->_find_or_new_outcome('lib', $c);
  isa_ok($row, 'npg_qc::Schema::Result::MqcLibraryOutcomeEnt');
  ok($row->in_storage, 'object is retrieved from the db');
  is($row->id_run, 45, 'correct run id');
  is($row->position, 4, 'correct position');
  is($row->tag_index, 1, 'tag index 1');
  ok($row->mqc_outcome, 'related dictionary object exists');
  is($row->mqc_outcome->short_desc, 'Rejected preliminary',
    'correct outcome description');
};

subtest q[find or create seq entity] => sub {
  plan tests => 16;

  my $o = npg_qc::mqc::outcomes->new(qc_schema => $qc_schema);

  my $c = npg_tracking::glossary::composition::factory::rpt_list
          ->new(rpt_list => '45:3:1')->create_composition();
  throws_ok { $o->_find_or_new_outcome('seq', $c) }
    qr/Defined tag index value is incompatible with outcome type seq/,
    'tag index defined - error';

  $c = npg_tracking::glossary::composition::factory::rpt_list
       ->new(rpt_list => '55:2')->create_composition();
  my $row = $o->_find_or_new_outcome('seq', $c);
  isa_ok($row, 'npg_qc::Schema::Result::MqcOutcomeEnt');
  ok(!$row->in_storage, 'new object is created in memory');
  is($row->id_run, 55, 'correct run id');
  is($row->position, 2, 'correct position');
  is($row->username, undef, 'username is undefined');
  is($row->modified_by, undef, 'modified_by is undefined');
  ok(!$row->mqc_outcome, 'no related dictionary object');

  my $dict_id = $qc_schema->resultset('MqcOutcomeDict')->search(
      {'short_desc' => 'Rejected preliminary'}
     )->next->id_mqc_outcome;

  $c = npg_tracking::glossary::composition::factory::rpt_list
         ->new(rpt_list => '55:3')->create_composition();
  my $seq_c = $qc_schema->resultset('MqcLibraryOutcomeEnt')
         ->find_or_create_seq_composition($c);
  $qc_schema->resultset('MqcOutcomeEnt')->create({
    'id_run'         => 55,
    'position'       => 3,
    'id_seq_composition' => $seq_c->id_seq_composition(),
    'id_mqc_outcome' => $dict_id,
    'username'       => 'cat',
    'modified_by'    => 'dog',
  });

  $row = $o->_find_or_new_outcome('seq', $c);
  isa_ok($row, 'npg_qc::Schema::Result::MqcOutcomeEnt');
  ok($row->in_storage, 'object is retrieved from the db');
  is($row->id_run, 55, 'correct run id');
  is($row->position, 3, 'correct position');
  is($row->username, 'cat', 'username is "cat"');
  is($row->modified_by, 'dog', 'modified by dog');
  ok($row->mqc_outcome, 'related dictionary object exists');
  is($row->mqc_outcome->short_desc, 'Rejected preliminary',
    'correct outcome description');
};

subtest q[save - errors] => sub {
  plan tests => 17;

  my $o = npg_qc::mqc::outcomes->new(qc_schema => $qc_schema);
  throws_ok {$o->save() } qr/Outcomes hash is required/,
    'outcomes should be given';
  throws_ok {$o->save([]) } qr/Outcomes hash is required/,
    'outcomes should be a hash ref';
  throws_ok {$o->save({}) } qr/Username is required/,
    'username is required';
  throws_ok {$o->save({}, q[]) } qr/Username is required/,
    'username cannot be empty';
  throws_ok {$o->save({}, q[cat], q[1, 2, 3]) }
    qr/Lane info should be a hash ref/,
    'lane info about tags should be a hash';
  lives_ok {$o->save({'seq' => {}}, q[cat]) }
    'lane info about tags is not required in the absence of seq data';
  throws_ok {$o->save({}, q[cat], {}) }
    qr/No data to save/, 'empty outcomes hash - error';
  throws_ok {$o->save({'lib'=>{}, 'other'=>{}}, q[cat], {}) }
    qr/One of outcome types is unknown/,
    'expected keys are missing in the outcomes hash - error';
  throws_ok {$o->save({'lib'=>[1,3,4], 'seq'=>{}}, q[cat], {}) }
    qr/Outcome for lib is not a hash ref/,
    'unexpected type of values - error';
  throws_ok {$o->save({'lib'=>{'123'=>undef}}, q[cat], {}) }
    qr/Outcome is not defined or is not a hash ref/,
    'outcome is not defined - error';
  throws_ok {$o->save({'lib'=>{'123'=>[]}}, q[cat], {}) }
    qr/Outcome is not defined or is not a hash ref/,
    'outcome is not a hash ref - error';
  throws_ok {$o->save({'lib'=>{'123:3'=>{'mqc_outcome'=>undef}}}, q[cat], {}) }
    qr/Error saving outcome for 123:3 - Outcome description is missing/,
    'undefined outcome description - error';
  throws_ok {$o->save({'lib'=>{'123:3'=>{'mqc_outcome'=>''}}}, q[cat], {}) }
    qr/Error saving outcome for 123:3 - Outcome description is missing/,
    'empty outcome description - error';
  throws_ok {$o->save({'uqc'=>{'123:1'=>{
    'uqc_outcome'=>'Accepted'}}}, q[cat]) }
    qr/Rationale required/,
    'expected rationale is missing in the uqc outcomes hash';
  throws_ok {$o->save({'uqc'=>{'123:1'=>{
    'mqc_outcome'=>'Accepted'}}}, q[cat]) }
    qr/Error saving outcome for 123:1 - Outcome description is missing/,
    'outcome key should match qc type';
  throws_ok {$o->save({'uqc'=>{'123:1'=>{
    'mqc_outcome'=>'Undecided'}}}, q[cat]) }
    qr/Error saving outcome for 123:1 - Outcome description is missing/,
    'outcome key should match qc type';
  throws_ok {$o->save({'uqc'=>{'123:1'=>{
    'mqc_outcome'=>'Accepted preliminary'}}}, q[cat]) }
    qr/Error saving outcome for 123:1 - Outcome description is missing/,
    'outcome key should match qc type'; 
};

subtest q[save outcomes] => sub {
  plan tests => 24;

  my $o = npg_qc::mqc::outcomes->new(qc_schema => $qc_schema);

  my $dict_id_prelim = $qc_schema->resultset('MqcOutcomeDict')->search(
      {'short_desc' => 'Rejected preliminary'}
     )->next->id_mqc_outcome;

  my $outcomes = {
    '101:1:2'=>{'mqc_outcome'=>'Accepted preliminary'},
    '101:1:4'=>{'mqc_outcome'=>'Rejected preliminary'},
    '101:1:6'=>{'mqc_outcome'=>'Undecided'},
                 };

  my $reply = {'lib' => $outcomes, 'seq'=> {}, 'uqc'=> {},};
  is_deeply($o->save({'lib' => $outcomes}, 'cat'),
    $reply, 'only lib info returned');

  my $c = npg_tracking::glossary::composition::factory::rpt_list
         ->new(rpt_list => '101:1')->create_composition();
  my $seq_c = $qc_schema->resultset('MqcLibraryOutcomeEnt')
         ->find_or_create_seq_composition($c);
  $qc_schema->resultset('MqcOutcomeEnt')->create({
    'id_run'         => 101,
    'position'       => 1,
    'id_seq_composition' => $seq_c->id_seq_composition(),
    'id_mqc_outcome' => $dict_id_prelim,
    'username'       => 'cat',
    'modified_by'    => 'dog',
  });

  $reply->{'seq'}->{'101:1'} = {'mqc_outcome'=>'Rejected preliminary'};
  is_deeply($o->save({'lib' => $outcomes}, 'cat'),
    $reply, 'both lib and seq info returned');

  my $outcomes1 = {
    '101:1:1'=>{'mqc_outcome'=>'Accepted preliminary'},
    '101:1:3'=>{'mqc_outcome'=>'Rejected preliminary'},
    '101:1:5'=>{'mqc_outcome'=>'Undecided'},
              };
  $reply->{'lib'} = {%{$outcomes}, %{$outcomes1}};

  my $saved = $o->save({'lib' => $outcomes1}, 'cat');
  is_deeply($saved, $reply, 'both lib and seq info returned');

  $reply->{'seq'}->{'101:1'} = {'mqc_outcome'=>'Accepted preliminary'};
  is_deeply($o->save({'seq' =>
    {'101:1'=>{'mqc_outcome'=>'Accepted preliminary'}}}, 'cat', {}),
    $reply, 'updated a seq entity to another prelim outcome');

  $reply->{'lib'}->{'101:1:1'} = {'mqc_outcome'=>'Accepted final'};
  is_deeply($o->save(
    {'lib' => {'101:1:1'=>{'mqc_outcome'=>'Accepted final'}}}, 'cat'),
    $reply, 'updated one of lib entities to a final outcome');

  $reply->{'uqc'} = {
    '101:1:1'=>{'uqc_outcome'=>'Accepted'},
    '101:1:3'=>{'uqc_outcome'=>'Rejected'},
    '101:1:5'=>{'uqc_outcome'=>'Undecided'},
  };
  my $values_to_save = {
    '101:1:1'=>{'uqc_outcome' => 'Accepted',
                'rationale'   => 'something'},
    '101:1:3'=>{'uqc_outcome' => 'Rejected',
                'rationale'   => 'something'},
    '101:1:5'=>{'uqc_outcome' => 'Undecided',
                'rationale'   => 'something'},
  };
  is_deeply($o->save({'uqc' => $values_to_save}, 'cat'),
    $reply, 'uqc outcomes saved ok. Lib, seq and uqc info returned');

  $values_to_save =  {
     'uqc' => $values_to_save,
     'lib' => {'101:1:2' => {'mqc_outcome' => 'Accepted preliminary'}},
     'seq' => {'101:1'   => {'mqc_outcome' => 'Accepted preliminary'}}};
  lives_ok{ $o->save($values_to_save, 'cat', {'101:1' => []})}
    'can save uqc, lib and seq outcomes at the same time';

  throws_ok { $o->save({'seq' =>
    {'101:1'=>{'mqc_outcome'=>'Accepted final'}}}, 'cat', {})}
    qr/Tag indices for lane 101:1 are required/,
    'tag info is not available, but lib results are stored - error';

  my $error =
    q[Mismatch between known tag indices and available library outcomes];

  throws_ok { $o->save({'seq' =>
    {'101:1'=>{'mqc_outcome'=>'Accepted final'}}}, 'cat',
    {'101:1'=>[]})}
    qr/$error/,
    'tag info array is empty, but lib results are stored - error';
  throws_ok { $o->save({'seq' =>
    {'101:1'=>{'mqc_outcome'=>'Accepted final'}}}, 'cat',
    {'101:1'=>[1, 2, 3]})}
    qr/$error/,
    'some tag info is not available, but lib results are stored - error';
  throws_ok { $o->save({'seq' =>
    {'101:1'=>{'mqc_outcome'=>'Accepted final'}}}, 'cat',
    {'101:1'=>[(1 .. 10)]})}
    qr/$error/,
    'more tags are available from lane info than stored - error';
  throws_ok { $o->save({'seq' =>
    {'101:1'=>{'mqc_outcome'=>'Accepted final'}}}, 'cat',
    {'101:1'=>[(1 .. 10)]})}
    qr/$error/,
    'more tags are available from lane info than stored - error';
  throws_ok { $o->save({'seq' =>
    {'101:1'=>{'mqc_outcome'=>'Accepted final'}}}, 'cat',
    {'101:1'=>[(5 .. 10)]})}
    qr/$error/,
    'only some tags match stored libs - error';

  lives_ok { $o->save({'seq' =>
    {'101:1'=>{'mqc_outcome'=>'Accepted final'}}}, 'cat',
    {'101:1'=>[(1 .. 6)]})}
    'Sequencing passed, we allow undefined lib outcomes';

  $outcomes = {
    '101:1:5'=>{'mqc_outcome'=>'Rejected preliminary'},
    '101:1:6'=>{'mqc_outcome'=>'Rejected preliminary'},
                 };

  my $dict_lib_id_prelim = $qc_schema->resultset('MqcLibraryOutcomeDict')
    ->search({'short_desc' => 'Rejected preliminary'})
    ->next->id_mqc_library_outcome;
  my $dict_lib_id_undecided = $qc_schema->resultset('MqcLibraryOutcomeDict')
     ->search({'short_desc' => 'Undecided'})
     ->next->id_mqc_library_outcome;
  my @tag_indexes = (1 .. 6);
  my @libs = ();
  for (@tag_indexes) {
    my $c = npg_tracking::glossary::composition::factory::rpt_list
         ->new(rpt_list => "101:3:$_")->create_composition();
    my $seq_c = $qc_schema->resultset('MqcLibraryOutcomeEnt')
         ->find_or_create_seq_composition($c);
    push @libs, $qc_schema->resultset('MqcLibraryOutcomeEnt')->create({
      'id_run'         => 101,
      'position'       => 3,
      'tag_index'      => $_,
      'id_seq_composition' => $seq_c->id_seq_composition(),
      'id_mqc_outcome' => $dict_lib_id_prelim,
      'username'       => 'cat',
      'modified_by'    => 'dog',
    });
  }

  my $error4fail =
    q[Sequencing failed, all library outcomes should be undecided];
  throws_ok { $o->save({'seq' =>
    {'101:3'=>{'mqc_outcome'=>'Rejected final'}}}, 'cat',
    {'101:3'=>\@tag_indexes})}
    qr/$error4fail/, $error4fail;

  map { $_->update({id_mqc_outcome => $dict_lib_id_undecided}) } @libs;
  lives_and { ok $o->save({'seq' =>
    {'101:3'=>{'mqc_outcome'=>'Rejected final'}}}, 'cat',
    {'101:3'=>\@tag_indexes}), 'got results'};


  throws_ok { $o->save({'seq' =>
    {'101:2'=>{'mqc_outcome'=>'Rejected final'}}}, 'cat',
    {'101:2'=>[(1 .. 6)]})}
    qr/$error/,
    'have tag info, but no lib outcomes stored - error';
  throws_ok { $o->save({'seq' =>
    {'101:2'=>{'mqc_outcome'=>'Accepted final'}}}, 'cat',
    {'101:2'=>[(1 .. 6)]})}
    qr/$error/,
    'have tag info, but no lib outcomes stored - error';

  lives_and { ok $o->save({'seq' =>
    {'101:2'=>{'mqc_outcome'=>'Accepted final'}}}, 'cat',
    {'101:2'=>[]}), 'empty tag list, no stored lib outcomes - ok'};
  lives_and { ok $o->save({'seq' =>
    {'101:3'=>{'mqc_outcome'=>'Rejected final'}}}, 'cat',
    {'101:3'=>[]}), 'saving the same outcome second time - early return'};

  lives_and { ok $o->save({'seq' =>
    {'101:1'=>{'mqc_outcome'=>'Accepted final'}}}, 'cat',
    {'101:1'=>[(1 .. 6)]}), 'got results again'};
  throws_ok { $o->save({'seq' =>
    {'101:1'=>{'mqc_outcome'=>'Rejected final'}}}, 'cat',
    {'101:1'=>[(1 .. 6)]})}
    qr/Final outcome cannot be updated/,
    'error updating a final outcome to a different final outcome';

  my $non_illumina_data = 1;
  lives_and { ok $o->save(
    {'seq' => {'1010000:5'=>{'mqc_outcome'=>'Accepted preliminary'}}},
    'cat',
    {},
    $non_illumina_data
  ) } 'saved preliminary lane outcome for non-Illumina data';
  lives_and { ok $o->save(
    {'seq' => {'1010000:5'=>{'mqc_outcome'=>'Accepted final'}}},
    'cat',
    {},
    $non_illumina_data
  ) } 'saved final lane outcome for non-Illumina data, no tag info';
};

subtest q[save outcomes for entities with multiple components] => sub {
  plan tests => 12;

  my $o = npg_qc::mqc::outcomes->new(qc_schema => $qc_schema);

  my $outcomes = {
    '26300:1:2;26300:2:2;26300:3:2;26300:4:2'=>{'mqc_outcome'=>'Accepted preliminary'},
    '26300:1:3;26300:2:3;26300:3:3;26300:4:3'=>{'mqc_outcome'=>'Rejected preliminary'},
    '26300:1:4;26300:2:4;26300:3:4;26300:4:4'=>{'mqc_outcome'=>'Undecided'},
                 };

  my $reply = {'lib' => $outcomes, 'seq'=> {}, 'uqc' => {}};
  is_deeply($o->save({'lib' => $outcomes}, 'cat'),
    $reply, 'lib info returned');

  my $c = npg_tracking::glossary::composition::factory::rpt_list
         ->new(rpt_list => '26300:1')->create_composition();
  my $seq_c = $qc_schema->resultset('MqcOutcomeEnt')
         ->find_or_create_seq_composition($c);
  my $dict_id_prelim = $qc_schema->resultset('MqcOutcomeDict')->search(
      {'short_desc' => 'Rejected preliminary'}
     )->next->id_mqc_outcome;
  $qc_schema->resultset('MqcOutcomeEnt')->create({
    'id_run'         => 101,
    'position'       => 1,
    'id_seq_composition' => $seq_c->id_seq_composition(),
    'id_mqc_outcome' => $dict_id_prelim,
    'username'       => 'cat',
    'modified_by'    => 'dog',
  });

  $outcomes->{'26300:1:3;26300:2:3;26300:3:3;26300:4:3'} =
    {'mqc_outcome'=>'Accepted preliminary'};
  is_deeply($o->save({'lib' => $outcomes}, 'cat'),
    $reply, 'only lib info returned, one outcome updated');

  my $seq_final = {'26300:1' => {'mqc_outcome'=>'Accepted final'}};
  throws_ok {$o->save({'seq' => $seq_final}, 'cat')}
    qr/Tag indices for lane 26300:1 are required/,
    'tag information required';
  throws_ok {$o->save({'seq' => $seq_final}, 'cat', {'26300:1' => [1,2]})}
    qr/Mismatch between known tag indices and available library outcomes/,
    'tag mismatch';
  throws_ok {$o->save({'seq' => $seq_final}, 'cat', {'26300:1' => [(2 .. 5)]})}
    qr/Mismatch between known tag indices and available library outcomes/,
    'tag mismatch';

  lives_ok {$reply = $o->save({'seq' => $seq_final}, 'cat', {'26300:1' => [(2 .. 4)]})}
    'lane 1 final outcome saved';
  is_deeply ($reply, {'seq' => $seq_final, 'lib' => {}, uqc => {}}, 'cirrect reply');
  $seq_final = {'26300:2' => {'mqc_outcome'=>'Accepted final'}};
  lives_ok {$reply = $o->save({'seq' => $seq_final}, 'cat', {'26300:2' => [(2 .. 4)]})}
    'lane 2 final outcome saved';

  my @lib_rows = $qc_schema->resultset('MqcLibraryOutcomeEnt')
     ->search_autoqc({id_run => 26300, position => 1}, 4)->all();
  is (scalar @lib_rows, 3, 'three lib outcome records found');
  @lib_rows = sort {$a->composition->get_component(0)->tag_index <=>
                    $b->composition->get_component(0)->tag_index} @lib_rows;
  is ($lib_rows[0]->mqc_outcome->short_desc, 'Accepted final', 'lib outcome is final');
  is ($lib_rows[1]->mqc_outcome->short_desc, 'Accepted final', 'lib outcome is final');
  is ($lib_rows[2]->mqc_outcome->short_desc, 'Undecided final', 'lib outcome is final, undecided saved');
};

subtest q[outcomes are not saved twice] => sub {
  plan tests => 6;

  my $dict_lib_id_prelim = $qc_schema->resultset('MqcLibraryOutcomeDict')
    ->search({'short_desc' => 'Rejected preliminary'})
    ->next->id_mqc_library_outcome;

  my $set_datetime = DateTime->now();
  $set_datetime->subtract_duration(
    DateTime::Duration->new(seconds => 100));

  my @tag_indexes = (1 .. 3);
  my @libs = ();
  for (@tag_indexes) {
    my $c = npg_tracking::glossary::composition::factory::rpt_list
         ->new(rpt_list => "102:1:$_")->create_composition();
    my $seq_c = $qc_schema->resultset('MqcLibraryOutcomeEnt')
         ->find_or_create_seq_composition($c);
    push @libs, $qc_schema->resultset('MqcLibraryOutcomeEnt')->create({
      'id_run'         => 102,
      'position'       => 1,
      'tag_index'      => $_,
      'id_seq_composition' => $seq_c->id_seq_composition(),
      'id_mqc_outcome' => $dict_lib_id_prelim,
      'username'       => 'dog',
      'modified_by'    => 'dog',
    });
  }
  map {$_->update({last_modified => $set_datetime})} @libs;

  my $outcomes = {
    '102:1:1'=>{'mqc_outcome'=>'Accepted preliminary'},
    '102:1:2'=>{'mqc_outcome'=>'Rejected preliminary'},
    '102:1:3'=>{'mqc_outcome'=>'Undecided'},
                 };
  npg_qc::mqc::outcomes->new(qc_schema => $qc_schema)
    ->save({'lib' => $outcomes}, 'cat');

  my $lib = $qc_schema->resultset('MqcLibraryOutcomeEnt')
    ->search({'id_run'=>102,'position'=>1,'tag_index'=>1})->next;
  is($lib->mqc_outcome->short_desc, 'Accepted preliminary',
    'outcome has changed');
  is($lib->modified_by, 'cat', 'latest modified_by value');
  ok(($lib->last_modified()
               ->subtract_datetime_absolute($set_datetime)
               ->seconds > 60),
    'last_modified field has changed');

  $lib = $qc_schema->resultset('MqcLibraryOutcomeEnt')
    ->search({'id_run'=>102,'position'=>1,'tag_index'=>2})->next;
  is($lib->mqc_outcome->short_desc, 'Rejected preliminary',
    'outcome has not changed');
  is($lib->modified_by, 'dog', 'old modified_by value');
  ok(($lib->last_modified()
               ->subtract_datetime_absolute($set_datetime)
               ->seconds < 1),
    'last_modified field is close to the original value');
};

subtest q[order of saving outcomes: lib, then seq] => sub {
  plan tests => 5;

  my $o = npg_qc::mqc::outcomes->new(qc_schema => $qc_schema);
  is($qc_schema->resultset('MqcLibraryOutcomeEnt')
               ->search({id_run=>103})->count, 0,
    'no lib results for run 103');
  is($qc_schema->resultset('MqcOutcomeEnt')
               ->search({id_run=>103})->count, 0,
    'no seq results for run 103');

  my $lib_outcomes = {
    '103:1:1'=>{'mqc_outcome'=>'Accepted preliminary'},
    '103:1:2'=>{'mqc_outcome'=>'Rejected preliminary'},
    '103:1:3'=>{'mqc_outcome'=>'Undecided'},
                     };
  my $seq_outcomes = {'103:1'=>{'mqc_outcome'=>'Accepted final'}};
  lives_ok { $o->save(
           {'lib' => $lib_outcomes, 'seq' => $seq_outcomes},
           'cat', {'103:1' => [1, 2, 3]}) }
  'seq result is saved';
  is($qc_schema->resultset('MqcLibraryOutcomeEnt')
               ->search({id_run=>103})->count, 3,
    'three lib results for run 103');
  is($qc_schema->resultset('MqcOutcomeEnt')
               ->search({id_run=>103})->count, 1,
    'one seq results for run 103');
};

1;

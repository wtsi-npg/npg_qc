use strict;
use warnings;
use Test::More tests => 11;
use Test::Exception;
use Moose::Meta::Class;
use JSON::XS;
use DateTime;
use DateTime::Duration;

use npg_testing::db;
use npg_tracking::glossary::rpt;

use_ok('npg_qc::mqc::outcomes');

my $qc_schema = Moose::Meta::Class->create_anon_class(
    roles => [qw/npg_testing::db/])
    ->new_object()->create_test_db(
    q[npg_qc::Schema], q[t/data/qcoutcomes/fixtures]);

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

subtest 'retrieving data' => sub {
  plan tests => 16;

  my $o = npg_qc::mqc::outcomes->new(
            qc_schema  => $qc_schema);
  throws_ok { $o->get() }
    qr/Input is missing or is not an array/,
    'get method requires input';

  throws_ok { $o->get('something') }
    qr/Input is missing or is not an array/,
    'get method requires array input';
  is_deeply($o->get([]), {'lib'=>{},'seq'=>{},'uqc'=>{}}, 'empty request is OK');

  my $v = {'tag_index' => 0};
  throws_ok {$o->get([$v])}
    qr/Both 'id_run' and 'position' keys should be defined/,
    'badly formed query - error';
  $v->{'id_run'} = 7;
  throws_ok {$o->get([$v])}
    qr/Both 'id_run' and 'position' keys should be defined/,
    'badly formed query - error';
  my $jsons = [
    '{"lib":{},"seq":{},"uqc":{}}',
    '{"lib":{},"seq":{"5:3":{"mqc_outcome":"Accepted final"}},"uqc":{}}',
    '{"lib":{},"seq":{"5:3":{"mqc_outcome":"Accepted final"}},"uqc":{}}',
    '{"lib":{"5:3:7":{"mqc_outcome":"Undecided final"}},"seq":{"5:3":{"mqc_outcome":"Accepted final"}},"uqc":{}}',
    '{"lib":{"5:3:6":{"mqc_outcome":"Undecided"},"5:3:3":{"mqc_outcome":"Rejected preliminary"},"5:3:7":{"mqc_outcome":"Undecided final"},"5:3:5":{"mqc_outcome":"Rejected final"},"5:3:4":{"mqc_outcome":"Accepted final"},"5:3:2":{"mqc_outcome":"Accepted preliminary"}},"seq":{"5:3":{"mqc_outcome":"Accepted final"}},"uqc":{}}',
    '{"lib":{"5:4":{"mqc_outcome":"Accepted preliminary"}},"seq":{"5:4":{"mqc_outcome":"Rejected final"}},"uqc":{}}',
    '{"lib":{"5:3:6":{"mqc_outcome":"Undecided"},"5:4":{"mqc_outcome":"Accepted preliminary"},"5:3:3":{"mqc_outcome":"Rejected preliminary"},"5:3:7":{"mqc_outcome":"Undecided final"},"5:3:5":{"mqc_outcome":"Rejected final"},"5:3:4":{"mqc_outcome":"Accepted final"},"5:3:2":{"mqc_outcome":"Accepted preliminary"}},"seq":{"5:4":{"mqc_outcome":"Rejected final"},"5:3":{"mqc_outcome":"Accepted final"}},"uqc":{}}',
    '{"lib":{"5:3:6":{"mqc_outcome":"Undecided"},"5:4":{"mqc_outcome":"Accepted preliminary"},"5:3:3":{"mqc_outcome":"Rejected preliminary"},"5:3:7":{"mqc_outcome":"Undecided final"},"5:3:5":{"mqc_outcome":"Rejected final"},"5:3:4":{"mqc_outcome":"Accepted final"},"5:3:2":{"mqc_outcome":"Accepted preliminary"}},"seq":{"5:4":{"mqc_outcome":"Rejected final"},"5:3":{"mqc_outcome":"Accepted final"},"5:1":{"mqc_outcome":"Accepted preliminary"}},"uqc":{}}',
    '{"lib":{"5:4":{"mqc_outcome":"Accepted preliminary"},"5:3:7":{"mqc_outcome":"Undecided final"}},"seq":{"5:4":{"mqc_outcome":"Rejected final"},"5:3":{"mqc_outcome":"Accepted final"}},"uqc":{}}',
    '{"lib":{"5:3:6":{"mqc_outcome":"Undecided"},"5:4":{"mqc_outcome":"Accepted preliminary"},"5:3:3":{"mqc_outcome":"Rejected preliminary"},"5:3:7":{"mqc_outcome":"Undecided final"},"5:3:5":{"mqc_outcome":"Rejected final"},"5:3:4":{"mqc_outcome":"Accepted final"},"5:3:2":{"mqc_outcome":"Accepted preliminary"}},"seq":{"5:4":{"mqc_outcome":"Rejected final"},"5:3":{"mqc_outcome":"Accepted final"}},"uqc":{}}',
    '{"lib":{"5:3:7":{"mqc_outcome":"Undecided final"},"5:3:5":{"mqc_outcome":"Rejected final"}},"seq":{"5:3":{"mqc_outcome":"Accepted final"}},"uqc":{}}'
  ];

  my @data = qw(
    5:3:7
    5:3:7
    5:3
    5:3:7
    5:3
    5:4
    5:4;5:3
    5:4;5:3;5:1
    5:4;5:3:7
    5:4;5:3:7;5:3
    5:3:5;5:3:7
  );


  my $j = 0;
  while ($j < @data) {
    if ($j == 1) {
      my $values = {id_run => 5, username => 'u1'};
      for my $i (1 .. 5) {
        $values->{'position'} = $i;
        $values->{'id_mqc_outcome'} = $i;
        $qc_schema->resultset('MqcOutcomeEnt')->create($values);
      }
    } elsif ($j == 3) {
      my $values = {id_run => 5, position => 3, username => 'u1'};
      for my $i (2 .. 7) {
        $values->{'tag_index'} = $i;
        $values->{'id_mqc_outcome'} = $i-1;
        $qc_schema->resultset('MqcLibraryOutcomeEnt')->create($values);
      }
    } elsif ($j == 5) {
      my $values = {id_run=>5, position=>4, id_mqc_outcome=>1, username=>'u1'};
      $qc_schema->resultset('MqcLibraryOutcomeEnt')->create($values);
    }

    my $l = $data[$j];
    is_deeply($o->get(npg_tracking::glossary::rpt->inflate_rpts($l)),
              decode_json($jsons->[$j]), qq[outcome for $l is correct]);
    $j++;
  }
};

subtest q[find or create entity - error handling] => sub {
  plan tests => 4;

  my $o = npg_qc::mqc::outcomes->new(qc_schema => $qc_schema);

  throws_ok { $o->_find_or_create_outcome() }
    qr/Two arguments required/,
    'no arguments - error';
  throws_ok { $o->_find_or_create_outcome('lib') }
    qr/Two arguments required/,
    'one arguments - error';
  throws_ok { $o->_find_or_create_outcome('some', {}) }
    qr/Unknown outcome entity type \'some\'/,
    'unknown entity type - error';
  throws_ok { $o->_find_or_create_outcome('lib', '44') }
    qr/Both id_run and position should be available /,
    'malformed rpt key - error';
};

subtest q[find or create lib entity] => sub {
  plan tests => 30;

  my $o = npg_qc::mqc::outcomes->new(qc_schema => $qc_schema);

  my ($row, $query) = $o->_find_or_create_outcome('lib', '45:2:1');
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

  $qc_schema->resultset('MqcLibraryOutcomeEnt')->create({
    'id_run'         => 45,
    'position'       => 3,
    'tag_index'      => 1,
    'id_mqc_outcome' => $dict_id,
    'username'       => 'cat',
    'modified_by'    => 'dog',
  });

  ($row, $query) = $o->_find_or_create_outcome('lib', '45:3:1');
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

  ($row, $query) = $o->_find_or_create_outcome('lib', '45:2');
  isa_ok($row, 'npg_qc::Schema::Result::MqcLibraryOutcomeEnt');
  ok(!$row->in_storage, 'new object is created in memory');
  is($row->id_run, 45, 'correct run id');
  is($row->position, 2, 'correct position');
  is($row->tag_index, undef, 'tag index not defined');
  ok(!$row->mqc_outcome, 'no related dictionary object');

  $qc_schema->resultset('MqcLibraryOutcomeEnt')->create({
    'id_run'         => 45,
    'position'       => 4,
    'id_mqc_outcome' => $dict_id,
    'username'       => 'cat',
    'modified_by'    => 'dog',
  });

  $qc_schema->resultset('MqcLibraryOutcomeEnt')->create({
    'id_run'         => 45,
    'position'       => 4,
    'tag_index'      => 1,
    'id_mqc_outcome' => $dict_id,
    'username'       => 'cat',
    'modified_by'    => 'dog',
  });

  ($row, $query) = $o->_find_or_create_outcome('lib', '45:4');
  isa_ok($row, 'npg_qc::Schema::Result::MqcLibraryOutcomeEnt');
  ok($row->in_storage, 'object is retrieved from the db');
  is($row->id_run, 45, 'correct run id');
  is($row->position, 4, 'correct position');
  is($row->tag_index, undef, 'tag index undefined');
  ok($row->mqc_outcome, 'related dictionary object exists');
  is($row->mqc_outcome->short_desc, 'Rejected preliminary',
    'correct outcome description');
};

subtest q[find or create seq entity] => sub {
  plan tests => 17;

  my $o = npg_qc::mqc::outcomes->new(qc_schema => $qc_schema);

  throws_ok { $o->_find_or_create_outcome('seq', '55:2:1') }
    qr/no such column: tag_index/,
    'query with tag index gives an error for seq outcome';
  my ($row, $query) = $o->_find_or_create_outcome('seq', '55:2');
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

  $qc_schema->resultset('MqcOutcomeEnt')->create({
    'id_run'         => 55,
    'position'       => 3,
    'id_mqc_outcome' => $dict_id,
    'username'       => 'cat',
    'modified_by'    => 'dog',
  });

  throws_ok { $o->_find_or_create_outcome('seq', '55:3:1') }
    qr/no such column: tag_index/,
    'query with tag index gives an error for seq outcome';
  ($row, $query) = $o->_find_or_create_outcome('seq', '55:3');
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

subtest q[validation for an update] => sub {
  plan tests => 12;

  my $o = npg_qc::mqc::outcomes->new(qc_schema => $qc_schema);
  my $dict_id_prel = $qc_schema->resultset('MqcOutcomeDict')->search(
      {'short_desc' => 'Rejected preliminary'}
     )->next->id_mqc_outcome;
  my $dict_id_final = $qc_schema->resultset('MqcOutcomeDict')->search(
      {'short_desc' => 'Rejected final'}
     )->next->id_mqc_outcome;

  my $outcome = $qc_schema->resultset('MqcOutcomeEnt')
    ->new_result({'id_run' => 45, 'position' => 2});
  lives_and {
    is $o->_valid4update($outcome, 'Rejected preliminary'), 1 }
    'in-memory object can be updated to a prelim outcome';
  lives_and {
    is $o->_valid4update($outcome, 'Rejected final'), 1 }
    'in-memory object can be updated to a final outcome';

  $outcome = $qc_schema->resultset('MqcLibraryOutcomeEnt')->create({
    'id_run'         => 45,
    'position'       => 7,
    'id_mqc_outcome' => $dict_id_prel,
    'username'       => 'cat',
    'modified_by'    => 'dog',
  });
  lives_and {
    is $o->_valid4update($outcome, 'Rejected preliminary'), 0 }
    'preliminary stored seq outcome cannot be updated to the same outcome';
  lives_and {
    is $o->_valid4update($outcome, 'Accepted preliminary'), 1 }
    'preliminary stored seq outcome can be updated to another priliminary outcome';
  lives_and {
    is $o->_valid4update($outcome, 'Accepted final'), 1 }
    'preliminary stored seq outcome can be updated to a final outcome';

  $outcome->update({'id_mqc_outcome' => $dict_id_final});
  throws_ok { $o->_valid4update($outcome, 'Accepted final') }
    qr/Final outcome cannot be updated/,
    'error updating a final stored outcome to another final outcome';
  throws_ok { $o->_valid4update($outcome, 'Accepted preliminary') }
    qr/Final outcome cannot be updated/,
    'error updating a final stored seq outcome to a preliminary outcome';
  lives_and { is $o->_valid4update($outcome, 'Rejected final'), 0 }
    'no error updating a final stored seq outcome to the same outcome';

  $o = npg_qc::mqc::outcomes->new(qc_schema => $qc_schema);
  $dict_id_prel =
    $qc_schema->resultset('MqcLibraryOutcomeDict')->search(
    {'short_desc' => 'Undecided'})->next->id_mqc_library_outcome;
  $dict_id_final =
    $qc_schema->resultset('MqcLibraryOutcomeDict')->search(
    {'short_desc' => 'Undecided final'})->next->id_mqc_library_outcome;

  $outcome = $qc_schema->resultset('MqcLibraryOutcomeEnt')
    ->new_result({'id_run' => 47, 'position' => 2, tag_index => 3});
  is($o->_valid4update($outcome, 'some outcome'), 1,
    'in-memory object can be updated');

  $outcome = $qc_schema->resultset('MqcLibraryOutcomeEnt')->create({
    'id_run'         => 47,
    'position'       => 2,
    'tag_index'      => 3,
    'id_mqc_outcome' => $dict_id_prel,
    'username'       => 'cat',
    'modified_by'    => 'dog',
  });
  is($o->_valid4update($outcome, 'some outcome'), 1,
    'stored lib outcome can be updated to a different outcome');
  is($o->_valid4update($outcome, $outcome->mqc_outcome->short_desc), 0,
    'stored lib outcome cannot be updated to the same outcome');

  $outcome->update({'id_mqc_outcome' => $dict_id_final});
  throws_ok { $o->_valid4update($outcome, 'some outcome') }
    qr/Final outcome cannot be updated/,
    'error updating a final stored lib outcome to another final outcome';
};

subtest q[save - errors] => sub {
  plan tests => 11;

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
    qr/Tag indices for lanes should be a hash ref/,
    'lane info about tags should be a hash';
  throws_ok {$o->save({'seq' => {}}, q[cat]) }
    qr/Tag indices for lanes are required/,
    'lane info about tags is required for seq data';
  throws_ok {$o->save({}, q[cat], {}) }
    qr/No data to save/, 'empty outcomes hash - error';
  throws_ok {$o->save({'some'=>{}, 'other'=>{}}, q[cat], {}) }
    qr/No data to save/,
    'expected keys are missing in the outcomes hash - error';
  throws_ok {$o->save({'lib'=>[1,3,4], 'seq'=>{}}, q[cat], {}) }
    qr/No data to save/,
    'unexpected type of values do not count';
  throws_ok {$o->save({'lib'=>{}, 'seq'=>{}}, q[cat], {}) }
    qr/No data to save/,
    'arrays for both lib and seq keys empty - error';
  throws_ok {$o->save({'lib'=>{}}, q[cat], {}) }
    qr/No data to save/,
    'lib array empty, seq key is missing - error';
};

subtest q[save outcomes] => sub {
  plan tests => 21;

  my $o = npg_qc::mqc::outcomes->new(qc_schema => $qc_schema);

  my $dict_id_prelim = $qc_schema->resultset('MqcOutcomeDict')->search(
      {'short_desc' => 'Rejected preliminary'}
     )->next->id_mqc_outcome;

  my $outcomes = {
    '101:1:2'=>{'mqc_outcome'=>'Accepted preliminary'},
    '101:1:4'=>{'mqc_outcome'=>'Rejected preliminary'},
    '101:1:6'=>{'mqc_outcome'=>'Undecided'},
                 };
  my $expected = {};
  foreach my $key (keys %{$outcomes}) {
    my $h = npg_tracking::glossary::rpt->inflate_rpt($key);
    $h->{'mqc_outcome'} = $outcomes->{$key}->{'mqc_outcome'};
    foreach my $hkey (keys %{$h}) {
      if(($hkey eq 'id_run') || ($hkey eq 'position') || ($hkey eq'tag_index')){
        delete ($h->{$hkey});
      }
    }
    $expected->{$key} = $h;
  }

  my $reply = {'lib' => $expected, 'seq'=> {}, 'uqc'=>{}};
    is_deeply($o->save({'lib' => $outcomes}, 'cat'),
    $reply, 'only lib info returned');

  $qc_schema->resultset('MqcOutcomeEnt')->create({
    'id_run'         => 101,
    'position'       => 1,
    'id_mqc_outcome' => $dict_id_prelim,
    'username'       => 'cat',
    'modified_by'    => 'dog',
  });
  $reply->{'seq'}->{'101:1'} = {'mqc_outcome'=>'Rejected preliminary'};
  is_deeply($o->save({'lib' => $outcomes}, 'cat'),
    $reply, 'both lib and seq info returned');

  $outcomes = {
    '101:1:1'=>{'mqc_outcome'=>'Accepted preliminary'},
    '101:1:3'=>{'mqc_outcome'=>'Rejected preliminary'},
    '101:1:5'=>{'mqc_outcome'=>'Undecided'},
              };
  my $expected_1 = {};
  foreach my $key (keys %{$outcomes}) {
    my $h = npg_tracking::glossary::rpt->inflate_rpt($key);
    $h->{'mqc_outcome'} = $outcomes->{$key}->{'mqc_outcome'};

    foreach my $hkey (keys %{$h}) {
      if(($hkey eq 'id_run') || ($hkey eq 'position') || ($hkey eq'tag_index')){
        delete ($h->{$hkey});
      }
    }
    $expected_1->{$key} = $h;
  }
  $reply->{'lib'} = $expected_1;
  is_deeply($o->save({'lib' => $outcomes}, 'cat'),
    $reply, 'both lib and seq info returned');

  my %all = (%{$expected}, %{$expected_1});
  $reply->{'lib'} = \%all;
  $reply->{'seq'}->{'101:1'} = {'mqc_outcome'=>'Accepted preliminary'};

  is_deeply($o->save({'seq' =>
    {'101:1'=>{'mqc_outcome'=>'Accepted preliminary'}}}, 'cat', {}),
    $reply, 'updated a seq entity to another prelim outcome');

  delete $reply->{'lib'};
  $reply->{'lib'}->{'101:1:1'} = {'mqc_outcome'=>'Accepted final'};
  is_deeply($o->save(
    {'lib' => {'101:1:1'=>{'mqc_outcome'=>'Accepted final'}}}, 'cat'),
    $reply, 'updated one of lib entities to a final outcome');

  my $error =
    q[Mismatch between known tag indices and available library outcomes];

  throws_ok { $o->save({'seq' =>
    {'101:1'=>{'mqc_outcome'=>'Accepted final'}}}, 'cat', {})}
    qr/List of known tag indexes is required for validation/,
    'tag info is not available, but lib results are stored - error';
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

  my $error4pass =
    q[Sequencing passed, cannot have undecided lib outcomes];
  throws_ok { $o->save({'seq' =>
    {'101:1'=>{'mqc_outcome'=>'Accepted final'}}}, 'cat',
    {'101:1'=>[(1 .. 6)]})}
    qr/$error4pass/, $error4pass;

  $outcomes = {
    '101:1:5'=>{'mqc_outcome'=>'Rejected preliminary'},
    '101:1:6'=>{'mqc_outcome'=>'Rejected preliminary'},
                 };
  $o->save({'lib' => $outcomes}, 'dog');
  lives_and { ok $o->save({'seq' =>
    {'101:1'=>{'mqc_outcome'=>'Accepted final'}}}, 'cat',
    {'101:1'=>[(1 .. 6)]}), 'got results'};

  my $dict_lib_id_prelim = $qc_schema->resultset('MqcLibraryOutcomeDict')
    ->search({'short_desc' => 'Rejected preliminary'})
    ->next->id_mqc_library_outcome;
  my $dict_lib_id_undecided = $qc_schema->resultset('MqcLibraryOutcomeDict')
     ->search({'short_desc' => 'Undecided'})
     ->next->id_mqc_library_outcome;
  my @tag_indexes = (1 .. 6);
  my @libs = ();
  for (@tag_indexes) {
    push @libs, $qc_schema->resultset('MqcLibraryOutcomeEnt')->create({
      'id_run'         => 101,
      'position'       => 3,
      'tag_index'      => $_,
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
    {'101:3'=>[]}), 'empty tag list, no stored lib outcomes - ok'};

  lives_and { ok $o->save({'seq' =>
    {'101:1'=>{'mqc_outcome'=>'Accepted final'}}}, 'cat',
    {'101:1'=>[(1 .. 6)]}), 'got results again'};
  throws_ok { $o->save({'seq' =>
    {'101:1'=>{'mqc_outcome'=>'Rejected final'}}}, 'cat',
    {'101:1'=>[(1 .. 6)]})}
    qr/Final outcome cannot be updated/,
    'error updating a final outcome to a different final outcome';
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
    push @libs, $qc_schema->resultset('MqcLibraryOutcomeEnt')->create({
      'id_run'         => 102,
      'position'       => 1,
      'tag_index'      => $_,
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
  plan tests => 8;

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
  throws_ok { $o->save(
           {'lib' => $lib_outcomes, 'seq' => $seq_outcomes},
           'cat', {'103:1' => [1, 2, 3]}) }
    qr/Sequencing passed, cannot have undecided lib outcomes/,
    'sequencing outcome cannot be saved - one of lib outcomes undecided';
  is($qc_schema->resultset('MqcLibraryOutcomeEnt')
               ->search({id_run=>103})->count, 0,
    'no lib results for run 103');
  is($qc_schema->resultset('MqcOutcomeEnt')
               ->search({id_run=>103})->count, 0,
    'no seq results for run 103');

  $lib_outcomes->{'103:1:3'}->{'mqc_outcome'} = 'Accepted preliminary';
  lives_ok { $o->save(
           {'lib' => $lib_outcomes, 'seq' => $seq_outcomes},
           'cat', {'103:1' => [1, 2, 3]}) }
  'seq result is now saved';
  is($qc_schema->resultset('MqcLibraryOutcomeEnt')
               ->search({id_run=>103})->count, 3,
    'three lib results for run 103');
  is($qc_schema->resultset('MqcOutcomeEnt')
               ->search({id_run=>103})->count, 1,
    'one seq results for run 103');
};

1;


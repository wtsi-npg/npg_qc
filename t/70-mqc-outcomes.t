use strict;
use warnings;
use Test::More tests => 3;
use Test::Exception;
use Moose::Meta::Class;
use JSON::XS;
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

  is_deeply($o->get([]), {'lib'=>{},'seq'=>{}}, 'empty request is OK');

  my $v = {'tag_index' => 0};
  throws_ok {$o->get([$v])}
    qr/Both 'id_run' and 'position' keys should be defined/,
    'badly formed query - error';
  $v->{'id_run'} = 7;
  throws_ok {$o->get([$v])}
    qr/Both 'id_run' and 'position' keys should be defined/,
    'badly formed query - error';

  my $jsons = [
    '{"lib":{},"seq":{}}',
    '{"lib":{},"seq":{"5:3":{"mqc_outcome":"Accepted final","position":3,"id_run":5}}}',
    '{"lib":{},"seq":{"5:3":{"mqc_outcome":"Accepted final","position":3,"id_run":5}}}',
    '{"lib":{"5:3:7":{"tag_index":7,"mqc_outcome":"Undecided final","position":3,"id_run":5}},"seq":{"5:3":{"mqc_outcome":"Accepted final","position":3,"id_run":5}}}',
    '{"lib":{"5:3:6":{"tag_index":6,"mqc_outcome":"Undecided","position":3,"id_run":5},"5:3:3":{"tag_index":3,"mqc_outcome":"Rejected preliminary","position":3,"id_run":5},"5:3:7":{"tag_index":7,"mqc_outcome":"Undecided final","position":3,"id_run":5},"5:3:5":{"tag_index":5,"mqc_outcome":"Rejected final","position":3,"id_run":5},"5:3:4":{"tag_index":4,"mqc_outcome":"Accepted final","position":3,"id_run":5},"5:3:2":{"tag_index":2,"mqc_outcome":"Accepted preliminary","position":3,"id_run":5}},"seq":{"5:3":{"mqc_outcome":"Accepted final","position":3,"id_run":5}}}',
    '{"lib":{"5:4":{"mqc_outcome":"Accepted preliminary","position":4,"id_run":5}},"seq":{"5:4":{"mqc_outcome":"Rejected final","position":4,"id_run":5}}}',
    '{"lib":{"5:3:6":{"tag_index":6,"mqc_outcome":"Undecided","position":3,"id_run":5},"5:4":{"mqc_outcome":"Accepted preliminary","position":4,"id_run":5},"5:3:3":{"tag_index":3,"mqc_outcome":"Rejected preliminary","position":3,"id_run":5},"5:3:7":{"tag_index":7,"mqc_outcome":"Undecided final","position":3,"id_run":5},"5:3:5":{"tag_index":5,"mqc_outcome":"Rejected final","position":3,"id_run":5},"5:3:4":{"tag_index":4,"mqc_outcome":"Accepted final","position":3,"id_run":5},"5:3:2":{"tag_index":2,"mqc_outcome":"Accepted preliminary","position":3,"id_run":5}},"seq":{"5:4":{"mqc_outcome":"Rejected final","position":4,"id_run":5},"5:3":{"mqc_outcome":"Accepted final","position":3,"id_run":5}}}',
    '{"lib":{"5:3:6":{"tag_index":6,"mqc_outcome":"Undecided","position":3,"id_run":5},"5:4":{"mqc_outcome":"Accepted preliminary","position":4,"id_run":5},"5:3:3":{"tag_index":3,"mqc_outcome":"Rejected preliminary","position":3,"id_run":5},"5:3:7":{"tag_index":7,"mqc_outcome":"Undecided final","position":3,"id_run":5},"5:3:5":{"tag_index":5,"mqc_outcome":"Rejected final","position":3,"id_run":5},"5:3:4":{"tag_index":4,"mqc_outcome":"Accepted final","position":3,"id_run":5},"5:3:2":{"tag_index":2,"mqc_outcome":"Accepted preliminary","position":3,"id_run":5}},"seq":{"5:4":{"mqc_outcome":"Rejected final","position":4,"id_run":5},"5:3":{"mqc_outcome":"Accepted final","position":3,"id_run":5},"5:1":{"mqc_outcome":"Accepted preliminary","position":1,"id_run":5}}}',
    '{"lib":{"5:4":{"mqc_outcome":"Accepted preliminary","position":4,"id_run":5},"5:3:7":{"tag_index":7,"mqc_outcome":"Undecided final","position":3,"id_run":5}},"seq":{"5:4":{"mqc_outcome":"Rejected final","position":4,"id_run":5},"5:3":{"mqc_outcome":"Accepted final","position":3,"id_run":5}}}',
    '{"lib":{"5:3:6":{"tag_index":6,"mqc_outcome":"Undecided","position":3,"id_run":5},"5:4":{"mqc_outcome":"Accepted preliminary","position":4,"id_run":5},"5:3:3":{"tag_index":3,"mqc_outcome":"Rejected preliminary","position":3,"id_run":5},"5:3:7":{"tag_index":7,"mqc_outcome":"Undecided final","position":3,"id_run":5},"5:3:5":{"tag_index":5,"mqc_outcome":"Rejected final","position":3,"id_run":5},"5:3:4":{"tag_index":4,"mqc_outcome":"Accepted final","position":3,"id_run":5},"5:3:2":{"tag_index":2,"mqc_outcome":"Accepted preliminary","position":3,"id_run":5}},"seq":{"5:4":{"mqc_outcome":"Rejected final","position":4,"id_run":5},"5:3":{"mqc_outcome":"Accepted final","position":3,"id_run":5}}}',
    '{"lib":{"5:3:7":{"tag_index":7,"mqc_outcome":"Undecided final","position":3,"id_run":5},"5:3:5":{"tag_index":5,"mqc_outcome":"Rejected final","position":3,"id_run":5}},"seq":{"5:3":{"mqc_outcome":"Accepted final","position":3,"id_run":5}}}'
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
      $qc_schema->resultset('MqcLibraryOutcomeEnt')->create(
        {id_run=>5, position=>4, id_mqc_outcome=>1, username=>'u1'});
    }

    my $l = $data[$j];
    is_deeply($o->get(npg_tracking::glossary::rpt->inflate_rpts($l)),
              decode_json($jsons->[$j]), qq[outcome for $l is correct]);
    $j++;
  } 
};

1;


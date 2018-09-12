use strict;
use warnings;
use Test::More tests => 20;
use Test::Exception;
use Moose::Meta::Class;
use JSON;

use npg_testing::db;
use t::autoqc_util;

use_ok('npg_qc::Schema::Result::QXYield');

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema]);

my $json = q({
  "info":{"Check":"npg_qc::autoqc::checks::qX_yield","Check_version":"14179"},
  "yield2":2317485,
  "yield1":2326976,
  "yield1_q30":17485,
  "yield2_q30":17385,
  "yield1_q40":25,
  "yield2_q40":85,
  "filename1":"9225_1_1#93.fastqcheck",
  "filename2":"9225_1_2#93.fastqcheck",
  "path":"archive/lane1",
  "threshold_quality":20,
  "id_run":"9225",
  "position":"1",
  "tag_index":"93"
});

my $values = from_json($json);

$values->{'id_seq_composition'} =
  t::autoqc_util::find_or_save_composition($schema,
    {id_run => 9225, position => 1, tag_index => 93});
my $rs = $schema->resultset('QXYield');
isa_ok($rs->new_result($values), 'npg_qc::Schema::Result::QXYield');

{
  my %values1 = %{$values};
  my $v1 = \%values1;

  lives_ok {$rs->find_or_new($v1)->set_inflated_columns($v1)->update_or_insert()} 'tag record inserted';
  my $rs1 = $rs->search({});
  is ($rs1->count, 1, q[one row created in the table]);
  my $row = $rs1->next;
  is($row->tag_index, 93, 'tag index retrieved correctly');
  is($row->yield1_q20, 2326976, 'q20 yield, forward, saved');
  is($row->yield2_q20, 2317485, 'q20 yield, reverse, saved');
  is($row->yield1_q30, 17485, 'q30 yield, forward, saved');
  is($row->yield2_q30, 17385, 'q30 yield, reverse, saved');
  is($row->yield1_q40, 25, 'q40 yield, forward, saved');
  is($row->yield2_q40, 85, 'q40 yield, reverse, saved');
  is(ref $row->info, 'HASH', 'info returned as hash ref');
  is_deeply($row->info, $values->{'info'},
    'info hash content is correct'); 

  %values1 = %{$values};
  $v1 = \%values1;
  delete $v1->{'id_run'};
  delete $v1->{'position'};
  delete $v1->{'tag_index'};
  my $row1;
  lives_ok {$row1 = $rs->find_or_new($v1)->set_inflated_columns($v1)->update_or_insert()}
    'another or the same row?';
  is ($row->id_qx_yield, $row1->id_qx_yield, 'new row is not created');

  %values1 = %{$values};
  $v1 = \%values1;
  $v1->{'id_seq_composition'} =
  t::autoqc_util::find_or_save_composition($schema,
    {id_run => 9225, position => 1, tag_index => 9});
  delete $v1->{'id_run'};
  delete $v1->{'position'};
  delete $v1->{'tag_index'};
  lives_ok {$row1 = $rs->find_or_new($v1)->set_inflated_columns($v1)->update_or_insert()}
    'another or the same row?';
  isnt ($row->id_qx_yield, $row1->id_qx_yield, 'new row iscreated');
  is ($row1->id_run, undef, 'id run value is undefined');
  is ($row1->position, undef, 'position value is undefined');
  is ($row1->tag_index, undef, 'tag_index value is undefined');
}

1;



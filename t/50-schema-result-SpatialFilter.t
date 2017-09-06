use strict;
use warnings;
use Test::More tests => 13;
use Test::Exception;
use Moose::Meta::Class;
use JSON;

use npg_testing::db;
use t::autoqc_util;

use_ok('npg_qc::Schema::Result::SpatialFilter');

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema]);

my $json = q { 
{"info":{"Check":"npg_qc::autoqc::checks::spatial_filter","Check_version":"16458"},
  "num_total_reads":341489472,"position":"4","path":"/dev/stdin","num_spatial_filter_fail_reads":0,"id_run":"9225"}
};

my $values = from_json($json);
$values->{'id_seq_composition'} =
  t::autoqc_util::find_or_save_composition($schema,
    {id_run => 9225, position => 4});
my $rs = $schema->resultset('SpatialFilter');
isa_ok($rs->new_result($values), 'npg_qc::Schema::Result::SpatialFilter');
{
  my %values1 = %{$values};
  my $v1 = \%values1;

  lives_ok {$rs->find_or_new($v1)->set_inflated_columns($v1)->update_or_insert()} 'record inserted';
  my $rs1 = $rs->search({});
  is ($rs1->count, 1, q[one row created in the table]);
  my $row = $rs1->next;
  is($row->num_total_reads, 341489472, 'num_total_reads retrieved correctly');
  is(ref $row->info, 'HASH', 'info returned as hash ref');
  is_deeply($row->info, $values->{'info'},
    'info hash content is correct');

  %values1 = %{$values};
  $v1 = \%values1;
  delete $v1->{'id_run'};
  delete $v1->{'position'};
  my $row1;
  lives_ok {$row1 = $rs->find_or_new($v1)->set_inflated_columns($v1)->update_or_insert()}
    'another or the same row?';
  is ($row->id_spatial_filter, $row1->id_spatial_filter, 'new row is not created');

  %values1 = %{$values};
  $v1 = \%values1;
  delete $v1->{'id_run'};
  delete $v1->{'position'};
  $v1->{'id_seq_composition'} =
  t::autoqc_util::find_or_save_composition($schema,
    {id_run => 9225, position => 1});
  lives_ok {$row1 = $rs->find_or_new($v1)->set_inflated_columns($v1)->update_or_insert()}
    'another row';
  isnt ($row->id_spatial_filter, $row1->id_spatial_filter, 'new row is created');
  is ($row1->id_run, undef, 'id run value is undefined');
  is ($row1->position, undef, 'position value is undefined');
} 

1;



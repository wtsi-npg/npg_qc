use strict;
use warnings;
use Test::More tests => 7;
use Test::Exception;
use Test::Deep;
use Moose::Meta::Class;
use JSON;
use npg_testing::db;

use_ok('npg_qc::Schema::Result::SpatialFilter');

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema]);

my $json = q { 
{"info":{"Check":"npg_qc::autoqc::checks::spatial_filter","Check_version":"16458"},
  "num_total_reads":341489472,"position":"4","path":"/dev/stdin","num_spatial_filter_fail_reads":0,"id_run":"9225"}
};

my $values = from_json($json);
my $rs = $schema->resultset('SpatialFilter');
isa_ok($rs->new_result($values), 'npg_qc::Schema::Result::SpatialFilter');
{
  my %values1 = %{$values};
  my $v1 = \%values1;

  $rs->deflate_unique_key_components($v1);
  lives_ok {$rs->find_or_new($v1)->set_inflated_columns($v1)->update_or_insert()} 'record inserted';
  my $rs1 = $rs->search({});
  is ($rs1->count, 1, q[one row created in the table]);
  my $row = $rs1->next;
  is($row->num_total_reads, 341489472, 'num_total_reads retrieved correctly');
  is(ref $row->info, 'HASH', 'info returned as hash ref');
  cmp_deeply($row->info, $values->{'info'},
    'info hash content is correct');
} 

1;



use strict;
use warnings;
use Test::More tests => 6;
use Test::Exception;
use Moose::Meta::Class;

use_ok 'npg_qc::Schema';

my $schema_package = q[npg_qc::Schema];
my $schema;
lives_ok{ $schema = Moose::Meta::Class->create_anon_class(
            roles => [qw/npg_testing::db/])->new_object()
            ->create_test_db($schema_package) } 'test db created';
isa_ok($schema, $schema_package);

subtest q[results with id_run and position only in the table] => sub {
  plan tests => 2;

  $schema->resultset('SpatialFilter')->create({id_run => 8926, position => 2});
  is ($schema->resultset('SpatialFilter')->search({
    id_run => 8926, position => 2})->count(), 1, 'one result');
  throws_ok {$schema->resultset('SpatialFilter')->search({
    id_run => 8926, position => 2, tag_index => undef})->count()}
    qr/no such column: tag_index/,
    'error with tag_index as a part of the query';
};

subtest q[results with id_run, position and tag_index in the table] => sub {
  plan tests => 15;

  my $is_rs = $schema->resultset('InsertSize');
  $is_rs->create({id_run => 3500, position => 1});
  my $rs = $is_rs->search_autoqc({id_run => 3500, position => 1});
  is ($rs->count, 1, 'one result retrieved');
  is ($rs->next->tag_index, undef, 'lane-level result');
  $rs = $is_rs->search_autoqc({id_run => 3500, position => 2});
  is ($rs->count, 0, 'no results retrieved');
  
  $rs = $is_rs->search_autoqc({id_run => 3500, position => 1, tag_index => undef});
  is ($rs->count, 1, 'one result retrieved');
  is ($rs->next->tag_index, undef, 'lane-level result');

  $rs = $is_rs->search_autoqc({id_run => 3500, position => 1, tag_index => 0});
  is ($rs->count, 0, 'no results retrieved');

  foreach my $i ((0 .. 10)) {
    foreach my $p ((1 .. 2)) {
      foreach my $r ((3500, 4000, 5000)) {
        $is_rs->create({id_run => $r, position => $p, tag_index => $i});
      }
    }
  }
  
  $rs = $is_rs->search_autoqc({id_run => 3500, position => 1});
  is ($rs->count, 12, '12 results retrieved');
  $rs = $is_rs->search_autoqc({id_run => 3500, position => 2});
  is ($rs->count, 11, '11 results retrieved');
  $rs = $is_rs->search_autoqc({id_run => 3500, position => 1, tag_index => undef});
  is ($rs->count, 1, '1 result retrieved');
  $rs = $is_rs->search_autoqc({id_run => 3500, position => 2, tag_index => undef});
  is ($rs->count, 0, 'no results retrieved');
  $rs = $is_rs->search_autoqc({id_run => 3500, position => 1, tag_index => 0});
  is ($rs->count, 1, 'one result retrieved');
  $rs = $is_rs->search_autoqc({id_run => 3500, position => [1,2], tag_index => 0});
  is ($rs->count, 2, 'two results retrieved');
  $rs = $is_rs->search_autoqc({id_run => 3500, position => [1,2], tag_index => [1,3,5,7]});
  is ($rs->count, 8, '8 results retrieved');
  $rs = $is_rs->search_autoqc({tag_index => [1,3]});
  is ($rs->count, 12, '12 results retrieved');
  $rs = $is_rs->search_autoqc({id_run => [3500,5000], position => [1,2], tag_index => undef});
  is ($rs->count, 1, '1 result retrieved');
};

subtest q[results with id_run, position, tag_index and subset in the table] => sub {
  plan tests => 9;

  my $fs_rs = $schema->resultset('BamFlagstats');
  foreach my $i ((0 .. 10)) {
    foreach my $p ((1 .. 2)) {
      foreach my $r ((3500, 4000, 5000)) {
        foreach my $s (qw/target human phix/) {
          my $hs = $s eq 'target' ? 'all' : $s;
          $fs_rs->create(
            {id_run => $r, position => $p, tag_index => $i, subset => $s, human_split => $hs});
        }
      }
    }
  }

  my $rs = $fs_rs->search_autoqc({id_run => 3500, position => 1});
  is ($rs->count, 33, '33 results retrieved');
  $rs = $fs_rs->search_autoqc({id_run => 3500, position => 1, tag_index => undef});
  is ($rs->count, 0, 'no results retrieved');
  $rs = $fs_rs->search_autoqc({id_run => 3500, position => 1, tag_index => 0});
  is ($rs->count, 3, '3 results retrieved');
  $rs = $fs_rs->search_autoqc({id_run => 3500, position => [1,2], tag_index => 0});
  is ($rs->count, 6, '6 results retrieved');
  $rs = $fs_rs->search_autoqc({id_run => 4000, position => [1,2], tag_index => 3, human_split => undef});
  is ($rs->count, 2, '2 results retrieved');
  $rs = $fs_rs->search_autoqc({id_run => 5000, position => 1, tag_index => 3, human_split => 'human'});
  is ($rs->count, 1, 'one result retrieved');
  $rs = $fs_rs->search_autoqc({id_run => 5000, position => 1, tag_index => 3, human_split => 'yhuman'});
  is ($rs->count, 0, 'no results retrieved');
  $rs = $fs_rs->search_autoqc({human_split => ['phix']});
  is ($rs->count, 66, '66 results retrieved');
  $rs = $fs_rs->search_autoqc({human_split => undef});
  is ($rs->count, 66, '66 results retrieved');
};

1;

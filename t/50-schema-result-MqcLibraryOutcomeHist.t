use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;
use Moose::Meta::Class;
use npg_testing::db;
use DateTime;

my $table = 'MqcLibraryOutcomeHist';

use_ok('npg_qc::Schema::Result::' . $table);

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema], 't/data/fixtures');

subtest 'Test insert' => sub {
  plan tests => 2;
  my $values = {
    'id_run'         => 1, 
    'position'       => 1,
    'tag_index'      => 1,
    'id_mqc_outcome' => 0, 
    'username'       => 'user', 
  };

  my $object = $schema->resultset($table)->create($values);
  isa_ok($object, 'npg_qc::Schema::Result::' . $table);

  my $rs = $schema->resultset($table)->search({});
  is ($rs->count, 1, q[one row created in the table]);  
};

subtest 'Test insert with tag_index null' => sub {
  plan tests => 4;
  my $values = {
      'id_run'         => 1, 
      'position'       => 2,
      'id_mqc_outcome' => 0, 
      'username'       => 'user', 
  };

  my $object = $schema->resultset($table)->create($values);
  isa_ok($object, 'npg_qc::Schema::Result::' . $table);

  my $rs = $schema->resultset($table)->search({'id_run'=>1, 'position'=>2});
  is ($rs->count, 1, q[one row matches in the table]);
  my $hist = $schema->resultset($table)->find({'id_run'=>1, 'position'=>2});
  ok ($hist, q[one row matches with find through key]);
  is($hist->tag_index, undef, q[tag_index is undefined]);
};

subtest 'Test update' => sub {
  plan tests => 3;
  my $values = {
    'id_run'         => 1, 
    'position'       => 3,
    'tag_index'      => 1,
    'id_mqc_outcome' => 0, 
    'username'       => 'user', 
  };

  my $rs = $schema->resultset($table);
  lives_ok {$rs->create($values)} 'Insert new entity';
  lives_ok {$rs->find({ 'id_run'=>1, 'position'=>3, 'tag_index'=>1 })->update({ 'id_mqc_outcome'=>2 })}
    'Find and update the outcome in the new entity';
  is ($schema->resultset($table)->search({ 'id_run'    =>1,
                                           'position'  =>3,
                                           'tag_index' =>1,
                                           'id_mqc_outcome'=>2
  })->count,
    1, q[one row matches in the table after update]);  
};

1;
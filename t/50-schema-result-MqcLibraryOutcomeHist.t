use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;
use Moose::Meta::Class;
use DateTime;

use npg_testing::db;
use t::autoqc_util;

my $table = 'MqcLibraryOutcomeHist';

use_ok('npg_qc::Schema::Result::' . $table);

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema], 't/data/fixtures');

subtest 'Test insert' => sub {
  plan tests => 3;
  my $values = {
    'id_run'         => 1, 
    'position'       => 1,
    'tag_index'      => 1,
    'id_mqc_outcome' => 0, 
    'username'       => 'user', 
  };

  throws_ok {$schema->resultset($table)->create($values)}
    qr/NOT NULL constraint failed: mqc_library_outcome_hist\.id_seq_composition/,
    'composition foreign key is needed';

  $values->{'id_seq_composition'} = t::autoqc_util::find_or_save_composition(
                $schema, {'id_run'    => 1,
                          'position'  => 1,
                          'tag_index' => 1});
  my $object = $schema->resultset($table)->create($values);
  isa_ok($object, 'npg_qc::Schema::Result::' . $table);

  my $rs = $schema->resultset($table)->search({});
  is ($rs->count, 1, q[one row created in the table]);  
};

subtest 'Test insert with tag_index null' => sub {
  plan tests => 8;
  my $values = {
      'id_run'         => 1, 
      'position'       => 2,
      'id_mqc_outcome' => 0, 
      'username'       => 'user', 
  };

  $values->{'id_seq_composition'} = t::autoqc_util::find_or_save_composition(
                $schema, {'id_run'    => 1,
                          'position'  => 1});
  my $object = $schema->resultset($table)->create($values);
  isa_ok($object, 'npg_qc::Schema::Result::' . $table);

  $values->{'id_seq_composition'} = t::autoqc_util::find_or_save_composition(
                $schema, {'id_run'    => 1,
                          'position'  => 1});
  my $rs = $schema->resultset($table)->search({'id_run'=>1, 'position'=>2});
  is ($rs->count, 1, q[one row matches in the table]);
  my $hist = $schema->resultset($table)->find({'id_run'=>1, 'position'=>2});
  ok ($hist, q[one row matches with find through key]);
  is($hist->tag_index, undef, q[tag_index is undefined]);

  $rs = $schema->resultset($table)->search({});
  is ($rs->count, 2, q[Two rows in the table]);
  $values = {
    'id_run'         => 2, 
    'position'       => 8,
    'id_mqc_outcome' => 1, 
    'username'       => 'user',
    'modified_by'    => 'user'
  };
  $values->{'id_seq_composition'} = t::autoqc_util::find_or_save_composition(
                $schema, {'id_run'    => 2,
                          'position'  => 8});
  $rs = $schema->resultset($table);
  lives_ok {$rs->find_or_new($values)
               ->set_inflated_columns($values)
               ->update_or_insert()} 'lane record inserted';
  my $rs1 = $rs->search({'id_run' => 2});
  is ($rs1->count, 1, q[one row created in the table]);
  my $row = $rs1->next;
  is($row->tag_index, undef, 'Tag index returns as default value');
};

subtest 'Test update' => sub {
  plan tests => 3;
  my $values = {
    'id_run'         => 1, 
    'position'       => 3,
    'tag_index'      => 1,
    'id_mqc_outcome' => 2, 
    'username'       => 'user', 
  };
  $values->{'id_seq_composition'} = t::autoqc_util::find_or_save_composition(
                $schema, {'id_run'    => 1,
                          'position'  => 3});
  my $rs = $schema->resultset($table);
  lives_ok {$rs->create($values)} 'Insert new entity';
  lives_ok {$rs->find({
    'id_run'=>1,
    'position'=>3,
    'tag_index'=>1
  })->update({ 'id_mqc_outcome'=>2 })}
    'Find and update the outcome in the new entity';

  is ($schema->resultset($table)->search({ 'id_run'    =>1,
                                           'position'  =>3,
                                           'tag_index' =>1,
                                           'id_mqc_outcome'=>2
  })->count,
    1, q[one row matches in the table after update]);  
};

1;
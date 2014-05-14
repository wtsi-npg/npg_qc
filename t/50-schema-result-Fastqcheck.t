use strict;
use warnings;
use Test::More tests => 18;
use Test::Exception;
use Compress::Zlib;
use Moose::Meta::Class;

use_ok ( 'npg_qc::Schema::Result::Fastqcheck' );
my $schema;
my $table = 'Fastqcheck';
{
  lives_ok
    {$schema = Moose::Meta::Class->create_anon_class(
       roles => [qw/npg_testing::db/])->new_object()
       ->create_test_db(q[npg_qc::Schema])}
    'test database created';
}

{
 my $resultset = $schema->resultset($table);
 is ($resultset->result_class->column_info('tag_index')->{'default_value'}, -1,
  'default value for tag_index column');
 is ($resultset->result_class->column_info('split')->{'default_value'}, 'none',
  'default value for split column');
}

{
  my $file_content = q[fastqcheck file total 1];
  my $file_content_compressed = compress($file_content);
  my $resultset = $schema->resultset($table);

  lives_ok {$resultset->create(     {id_run=>1, position=>1, 
                                     file_name=>q[file1],
                                     section => q[forward],
                                     file_content=>$file_content,
                                     file_content_compressed=>$file_content_compressed});}
   'create record without specifying tag_index and split';
  my $row = $resultset->find({id_run=>1, position=>1});
  is ($row->tag_index, undef, 'tag index converted to undef in result');
  is ($row->split, undef, 'split converted to undef in result');

  lives_ok {$resultset->create(     {id_run=>1, position=>1,tag_index=>1,
                                     file_name=>q[file11],
                                     section => q[forward],
                                     file_content=>$file_content,
                                     file_content_compressed=>$file_content_compressed});}
   'tag record for the same lane created';

  my $values =                      {id_run=>1, position=>1,
                                     file_name=>q[file1],
                                     section => q[forward],
                                     file_content=>q[new],
                                     file_content_compressed=>$file_content_compressed};
  lives_ok {$resultset->find_or_new($values)->set_inflated_columns($values)->update_or_insert()}
   'update not specifying tag_index and split';
  $row = $resultset->find({id_run=>1, position=>1,tag_index=>-1,});
  is ($row->file_content, q[new], 'updated file_content for a lane');
  $row = $resultset->find({id_run=>1, position=>1,tag_index=>1,});
  is ($row->file_content, $file_content, 'record file_content for a tag is not updated');

  $values->{tag_index} = 1;
  $values->{file_name} = q[file11];
  $values->{file_content} = q[new11];
  lives_ok {$resultset->find_or_new($values)->set_inflated_columns($values)->update_or_insert()}
   'update tag record';
  $row = $resultset->find({id_run=>1, position=>1,tag_index=>1,});
  is ($row->file_content, q[new11], 'updated file_content is correct');

  ok(!$resultset->find({id_run=>1, position=>1, tag_index => undef}), 'query with tag_index => undef brings no results');
  my $rs = $resultset->search({id_run=>1, position=>1, tag_index => $resultset->result_class->column_info('tag_index')->{'default_value'},});
  is ($rs->count, 1, 'query with default tag_index brings one result');
  $row = $rs->next;
  is ($row->tag_index, undef, 'default tag index returned as undef');
  is ($row->split, undef, 'default split returned as undef');
  $rs = $resultset->search({id_run=>1, position=>1, split => $resultset->result_class->column_info('split')->{'default_value'},});
  is ($rs->count, 2, 'query with default split brings two results');
}

1;

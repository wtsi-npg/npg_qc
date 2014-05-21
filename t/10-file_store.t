#########
# Author:        mg8
# Maintainer:    $Author$
# Created:       9 August 2010
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

use strict;
use warnings;
use Test::More tests => 36;
use Test::Exception;
use Test::Deep;
use Perl6::Slurp;
use File::Spec;
use Moose::Meta::Class;
use Compress::Zlib;

use npg_testing::db;

use_ok('npg_qc::file_store');

isa_ok(npg_qc::file_store->new(path => ['t']), 'npg_qc::file_store');

throws_ok {npg_qc::file_store->new()} qr/Attribute \(path\) is required /, 'error if path is not set';

{
  my $s = npg_qc::file_store->new(path => ['t/data/fastqcheck/4308']);
  is ($s->table_name, 'Fastqcheck', 'table name to save to correct');
  is (scalar @{$s->_get_files}, 3, '3 fastqcheck files found');
}

{
  cmp_deeply(npg_qc::file_store::fname2ids('111_3_1#4.fastqcheck'),
    {id_run =>111,position=>3,tag_index=>4,section=>'forward',}, 'forward plex filename parsed');
  cmp_deeply(npg_qc::file_store::fname2ids('111_3_2#4.fastqcheck'),
    {id_run =>111,position=>3,tag_index=>4,section=>'reverse',}, 'reverse plex filename parsed');
  cmp_deeply(npg_qc::file_store::fname2ids('111_3.fastqcheck'),
    {id_run =>111,position=>3,section=>'forward',}, 'single lane filename parsed');
  cmp_deeply(npg_qc::file_store::fname2ids('111_3#0.fastqcheck'),
    {id_run =>111,position=>3,tag_index=>0,section=>'forward',}, 'unknown read can be interpreted as a split');
  cmp_deeply(npg_qc::file_store::fname2ids('111_3_m#4.fastqcheck'),
    {id_run =>111,position=>3,tag_index=>4,split=>'m',section=>'forward',}, 'single tag 0 filename parsed');
  throws_ok { npg_qc::file_store::fname2ids('111_3_m_phix#4.fastqcheck') }
     qr/Cannot infer id_run/, 'error if read value unexpected'; 
}

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema]);

{
  my $s = npg_qc::file_store->new(path => ['t/data/autoqc/npg'], schema => $schema);
  is (scalar @{$s->_get_files}, 0, 'no fqcheck files found');
  my $num_saved;
  lives_ok {$num_saved = $s->save_files} 'saving files when there are no files lives';
  is ($num_saved, 0, 'no files are saved');
}

{
  my $table = 'Fastqcheck';

  my $path = 't/data/fastqcheck/4308';
  my $s = npg_qc::file_store->new(path => [$path], schema => $schema, table_name => $table);
  my $num_saved;
  lives_ok {$num_saved = $s->save_files} 'saving files lives';
  my $expected = 3;
  is ($num_saved, $expected, qq[$expected files saved]);

  is ($schema->resultset($table)->search({})->count, $expected, qq[$expected rows created in the table]);

  my $fname=  q[4308_1_2.fastqcheck];
  my $content = slurp(File::Spec->catfile($path, $fname));

  my $row = $schema->resultset($table)->find({file_name => $fname,});
  ok ($row, qq[row for $fname exists]);
  is ($row->file_content, $content, 'file content saved correctly');
  is (uncompress($row->file_content_compressed), $content, 'compressed file content saved correctly');
  is ($row->twenty, 613490247, 'q20 saved');
  is ($row->twentyfive, 601259067, 'q25 saved');
  is ($row->thirty, 564565526, 'q30 saved');
  is ($row->thirtyfive, 393329004, 'q35 saved');
  is ($row->forty, 0, 'q40 saved');
  is ($row->tag_index, undef, 'tag index returned as undef');

  $row = $schema->resultset($table)->find({file_name => '4308_4_2#5.fastqcheck',});
  is ($row->tag_index, 5, 'tag index 5');
  is ($row->position, 4, 'position 4');
  is ($row->id_run, 4308, 'id run 4308');
  is ($row->section, 'reverse', 'reverse read saved');
  is ($row->split, undef, 'no split');

  $row = $schema->resultset($table)->find({file_name => '4308_4#5.fastqcheck',});
  is ($row->tag_index, 5, 'tag index 5');
  is ($row->position, 4, 'position 4');
  is ($row->id_run, 4308, 'id run 4308');
  is ($row->section, 'forward', 'forward read saved');
  is ($row->split, undef, 'no split');
}

1;

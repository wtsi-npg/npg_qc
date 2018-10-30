use strict;
use warnings;
use Test::More tests => 25;
use Test::Exception;
use Perl6::Slurp;
use File::Spec;
use Moose::Meta::Class;
use Compress::Zlib;

use npg_testing::db;

use_ok('npg_qc::file_store');

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema]);
{
  isa_ok(npg_qc::file_store->new(path => ['t']), 'npg_qc::file_store');
  throws_ok {npg_qc::file_store->new()} qr/Attribute \(path\) is required /, 'error if path is not set';
}

{
  my $s = npg_qc::file_store->new(path => ['t/data/fastqcheck']);
  is (scalar @{$s->_get_files}, 2, 'two fastqcheck files found');
}

{
  ok(!npg_qc::file_store::_fname2ids('111_3_1#4.fastqcheck'), 'plex level file excluded');
  ok(!npg_qc::file_store::_fname2ids('111_3_1_phix.fastqcheck'), 'file for a subset excluded');
 
  is_deeply(npg_qc::file_store::_fname2ids('111_3.fastqcheck'),
    {id_run =>111,position=>3,section=>'forward'}, 'implicit forward read filename parsed');
  is_deeply(npg_qc::file_store::_fname2ids('111_3_1.fastqcheck'),
    {id_run =>111,position=>3,section=>'forward'}, 'forward read filename parsed');
  is_deeply(npg_qc::file_store::_fname2ids('111_3_2.fastqcheck'),
    {id_run =>111,position=>3,section=>'reverse'}, 'reverse read filename parsed');
}

{
  my $s = npg_qc::file_store->new(path => ['t/data/autoqc/npg'], schema => $schema);
  is (scalar @{$s->_get_files}, 0, 'no fqcheck files found');
  my $num_saved;
  lives_ok {$num_saved = $s->save_files} 'saving files when there are no files lives';
  is ($num_saved, 0, 'no files are saved');

  $s = npg_qc::file_store->new(path => ['t/data/autoqc/npg', 't/some'],
                               schema => $schema);
  is (scalar @{$s->_get_files}, 0,
    'no fqcheck files found, one of the given directories does not exist');
}

{
  my $rs = $schema->resultset('Fastqcheck');

  my $path = 't/data/fastqcheck';
  my $s = npg_qc::file_store->new(path => [$path], schema => $schema);
  my $num_saved;
  lives_ok {$num_saved = $s->save_files} 'saving files lives';

  is ($num_saved, 1, qq[one file saved]);

  is ($rs->search({})->count, 1, qq[one row created in the table]);

  my $fname=  q[4308_1_2.fastqcheck];
  my $content = slurp(File::Spec->catfile($path, $fname));

  my $row = $rs->find({file_name => $fname,});
  ok ($row, qq[row for $fname exists]);
  is ($row->file_content, $content, 'file content saved correctly');
  is (uncompress($row->file_content_compressed), $content, 'compressed file content saved correctly');
  is ($row->twenty, 613490247, 'q20 saved');
  is ($row->twentyfive, 601259067, 'q25 saved');
  is ($row->thirty, 564565526, 'q30 saved');
  is ($row->thirtyfive, 393329004, 'q35 saved');
  is ($row->forty, 0, 'q40 saved');
  is ($row->tag_index, undef, 'tag index returned as undef');
}

1;

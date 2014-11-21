use strict;
use warnings;
use Test::More tests => 11;
use Test::Exception;
use Cwd;
use File::Spec;
use GD qw(:DEFAULT :cmp);

use t::util;

my $fname = 'new.fastqcheck';
my $source_fname = File::Spec->catfile(cwd, 't', 'data', 'sources4visuals', '4360_1_1.fastqcheck');
my $schemas;
{
  my $util = t::util->new();
  lives_ok { $schemas = $util->test_env_setup()}  'test dbs created and populated';

  open my $fh, '<', $source_fname;
  local $/ = undef;
  my $text = <$fh>;
  close $fh;

  my $rs = $schemas->{qc}->resultset('Fastqcheck');
  $rs->create({section => 'forward', id_run => 4360, position => 1, file_name => $fname, file_content => $text,});
  is ($rs->search({file_name => $fname})->count, 1, 'one fastqcheck file saved');
}


{ use_ok 'npg_qc_viewer::Model::Visuals::Fastqcheck' }


{
  my $model = npg_qc_viewer::Model::Visuals::Fastqcheck->new();
  $model->schema($schemas->{qc});
  throws_ok { $model->fastqcheck2image() } 
     qr/file name is not defined/, 'fastqcheck file should be defined';
  throws_ok { $model->fastqcheck2image({path => 'does/not/exists.fastqcheck',}) } 
     qr/No such file or directory/, 'fastqcheck file should exist';
  throws_ok { $model->fastqcheck2image({path =>'does/not/exists.fastqcheck', read =>'forward', db_lookup => 0,}) } 
     qr/No such file or directory/, 'fastqcheck file should exist';
  throws_ok { $model->fastqcheck2image({path =>'does/not/exists.fastqcheck', db_lookup => 1,}) } 
     qr/does\/not\/exists\.fastqcheck is not in the long-term storage/, 'fastqcheck file should be stored in the db';
}


{
  my $expected = GD::Image->new( File::Spec->catfile(cwd, 't', 'data', 'rendered', '4360_1_1_fastqcheck.png'));  
  my $model = npg_qc_viewer::Model::Visuals::Fastqcheck->new();
  $model->schema($schemas->{qc});

  my $rendered;
  lives_ok { $rendered = GD::Image->new($model->fastqcheck2image(
                               {path=>$fname, read=>'forward', db_lookup=>1,})) } 'fastqcheck2image lives'; 
  ok (!($rendered->compare($expected) & GD_CMP_IMAGE), 'fastqcheck image generated OK');

  lives_ok { $rendered = GD::Image->new($model->fastqcheck2image(
                               {path=>$source_fname, read=>'forward', db_lookup=>0,})) } 'fastqcheck2image lives'; 
  ok (!($rendered->compare($expected) & GD_CMP_IMAGE), 'fastqcheck image generated OK');
}

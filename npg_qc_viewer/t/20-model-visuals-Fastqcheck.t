use strict;
use warnings;
use Test::More tests => 10;
use Test::Exception;
use Cwd;
use File::Spec;
use GD qw(:DEFAULT :cmp);

use_ok 'npg_qc_viewer::Model::Visuals::Fastqcheck';
isa_ok(npg_qc_viewer::Model::Visuals::Fastqcheck->new(), 'npg_qc_viewer::Model::Visuals::Fastqcheck');


{
  my $model = npg_qc_viewer::Model::Visuals::Fastqcheck->new();
  my $rendered = GD::Image->new($model->fastqcheck_legend());
  my $expected = GD::Image->new( File::Spec->catfile(cwd, 't', 'data', 'rendered', 'fastqcheck_legend.png'));  
  ok (!($rendered->compare($expected) & GD_CMP_IMAGE), 'legend image generated OK');
}


{
  my $model = npg_qc_viewer::Model::Visuals::Fastqcheck->new();
  throws_ok { $model->fastqcheck2image() } qr/file name is not defined/, 'fastqcheck2image needs args array';
  throws_ok { $model->fastqcheck2image({dodo=>1,}) } qr/file name is not defined/, 'fastqcheck2image needs non-empty args array';
}


{
  my $model = npg_qc_viewer::Model::Visuals::Fastqcheck->new();
  my $path = File::Spec->catfile(cwd, 't', 'data', 'sources4visuals', '4360_1_1.fastqcheck');
  lives_ok { GD::Image->new($model->fastqcheck2image({path=>$path,})) } 'fastqcheck2image lives with one arg';
}


{
  my $model = npg_qc_viewer::Model::Visuals::Fastqcheck->new();
  my $path = File::Spec->catfile(cwd, 't', 'data', 'sources4visuals', '4360_1_1.fastqcheck');

  my $rendered;
  lives_ok { $rendered = GD::Image->new($model->fastqcheck2image({path=>$path, read=>'forward',})) } 'fastqcheck2image lives if args are correct';
  my $expected = GD::Image->new( File::Spec->catfile(cwd, 't', 'data', 'rendered', '4360_1_1_fastqcheck.png'));  
  ok (!($rendered->compare($expected) & GD_CMP_IMAGE), 'fastqcheck image generated OK');
}


{
  my $model = npg_qc_viewer::Model::Visuals::Fastqcheck->new();
  my $path = File::Spec->catfile(cwd, 't', 'data', 'sources4visuals', 'empty.fastqcheck');

  my $rendered;
  lives_ok { $rendered = GD::Image->new($model->fastqcheck2image({path=>$path,})) } 'fastqcheck2image for an empty fastq file lives';
  ok (!$rendered, 'undef is returned for an empty fastq file');
}

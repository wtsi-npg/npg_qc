use strict;
use warnings;
use Test::More tests => 8;
use Test::Exception;
use Cwd;
use File::Spec;
use Perl6::Slurp;
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
  throws_ok { $model->fastqcheck2image() } qr/Fastqcheck file content is required/,
    'fastqcheck2image needs file content';
  throws_ok { $model->fastqcheck2image(q[]) } qr/Fastqcheck file content is required/,
    'file content cannot be empty';
  throws_ok { $model->fastqcheck2image('aaa') } qr/Read is required/,
    'fastqcheck2image needs read';
}

{
  my $model = npg_qc_viewer::Model::Visuals::Fastqcheck->new();
  my $content = slurp(File::Spec->catfile(cwd, 't', 'data', 'sources4visuals', '4360_1_1.fastqcheck'));

  my $rendered;
  lives_ok { $rendered = GD::Image->new($model->fastqcheck2image($content, 'forward')) }
    'fastqcheck2image lives if args are correct';
  my $expected = GD::Image->new( File::Spec->catfile(cwd, 't', 'data', 'rendered', '4360_1_1_fastqcheck.png'));  
  ok (!($rendered->compare($expected) & GD_CMP_IMAGE), 'fastqcheck image generated OK');
}

1;

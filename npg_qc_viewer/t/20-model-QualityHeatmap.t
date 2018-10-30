use strict;
use warnings;
use Test::More tests => 7;
use Test::Exception;
use Cwd;
use File::Spec;
use Perl6::Slurp;
use GD qw(:DEFAULT :cmp);

use_ok 'npg_qc_viewer::Model::QualityHeatmap';
isa_ok(npg_qc_viewer::Model::QualityHeatmap->new(), 'npg_qc_viewer::Model::QualityHeatmap');
my $dir = File::Spec->catfile(cwd, 't', 'data', 'qualmap');

{
  my $model = npg_qc_viewer::Model::QualityHeatmap->new();
  my $rendered = GD::Image->new($model->legend());
  my $expected = GD::Image->new( File::Spec->catfile($dir, 'qualmap_legend.png'));  
  ok (!($rendered->compare($expected) & GD_CMP_IMAGE), 'legend image generated OK');
}

{
  my $model = npg_qc_viewer::Model::QualityHeatmap->new();
  throws_ok { $model->data2image() } qr/Result object or string is required/,
    'data2image needs file content';
  throws_ok { $model->data2image(q[]) } qr/Result object or string is required/,
    'file content cannot be empty';
#  throws_ok { $model->data2image('aaa') } qr/Result object is required/,
#    'data2image needs read';
}

{
  my $model = npg_qc_viewer::Model::QualityHeatmap->new();
  my $content = slurp(File::Spec->catfile($dir, '4360_1#1.stats'));

  my $rendered;
  lives_ok { $rendered = GD::Image->new($model->data2image($content, 'forward')) }
    'data2image lives if args are correct';

  my $out = 't/my1.png';
  open my $h, '>', $out;
  binmode $h;
  print $h $rendered->png;
  close $h;

  my $expected = GD::Image->new( File::Spec->catfile($dir, 'qualmap.png'));  
  ok (!($rendered->compare($expected) & GD_CMP_IMAGE), 'image generated OK');
}

1;

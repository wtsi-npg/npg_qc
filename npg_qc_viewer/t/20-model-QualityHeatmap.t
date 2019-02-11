use strict;
use warnings;
use Test::More tests => 11;
use Test::Exception;
use Cwd;
use File::Spec;
use Perl6::Slurp;
use GD qw(:DEFAULT :cmp);

use_ok 'npg_qc::autoqc::results::samtools_stats';
use_ok 'npg_qc_viewer::Model::QualityHeatmap';

isa_ok(npg_qc_viewer::Model::QualityHeatmap->new(),
  'npg_qc_viewer::Model::QualityHeatmap');
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
}

{
  my $model = npg_qc_viewer::Model::QualityHeatmap->new();
  my $content = slurp(File::Spec->catfile($dir, '4360_1#1.stats'));

  my $rendered;
  lives_ok { $rendered = GD::Image->new($model->data2image($content, 'forward')) }
    'data2image executes without error';
  my $i = File::Spec->catfile($dir, 'qualmap.png');
  my $expected = GD::Image->new($i);
  ok (!($rendered->compare($expected) & GD_CMP_IMAGE), 'image generated OK');
}

{
  my $obj = npg_qc::autoqc::results::samtools_stats->load(
            join q[/], $dir, '26607_1#20_F0xB00.samtools_stats.json');
  my $model = npg_qc_viewer::Model::QualityHeatmap->new();

  foreach my $read (qw(forward reverse index)) {
    my $rendered = GD::Image->new($model->data2image($obj, $read));
    my $i = File::Spec->catfile($dir, "$read.png");
    my $expected = GD::Image->new($i);
    ok (!($rendered->compare($expected) & GD_CMP_IMAGE), "$read image generated OK"); 
  }
}

1;

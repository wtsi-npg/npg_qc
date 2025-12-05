package sample_retriever_test;
use Moose;
with 'npg_qc::ultimagen::sample_retriever';

package main_test;
use strict;
use warnings;
use Test::More tests => 9;
use Test::Exception;

use_ok('sample_retriever_test');

my $rf = 't/data/ultimagen/425347-20250821_1214';

throws_ok { sample_retriever_test->new()->get_samples() }
  qr/Either runfolder_path or manifest_path should be set/,
  'error if no attributes are set';

my $samples_from_li = sample_retriever_test->new(
  runfolder_path => $rf
)->get_samples();
my $samples_from_ma = sample_retriever_test->new(
  runfolder_path => $rf,
  manifest_path => "${rf}/manifest.csv"
)->get_samples();

is (scalar @{$samples_from_li}, 8, 'returned eight samples');
is_deeply ($samples_from_li, $samples_from_ma, 'identical sample info');
my $sample = $samples_from_li->[0];
is ($sample->id(), 'iNeuron15923026', 'correct sample id');
is ($sample->library_name(), '1_GEX_iA_iN_SCREEN', 'correct library name');
is ($sample->index_label(), 'Z0001', 'correct index label');
is ($sample->index_sequence(), 'CAGCTCGAATGCGAT', 'correct index sequence');
is ($sample->tag_index, 1, 'correct NPG tag index');

1;

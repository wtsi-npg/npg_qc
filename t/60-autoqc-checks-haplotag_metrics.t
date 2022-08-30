use strict;
use warnings;
use Test::More tests => 3;
use Test::Exception;
use File::Temp qw( tempdir );
use File::Copy::Recursive qw(dircopy);
use Perl6::Slurp;
use JSON;

local $ENV{'NPG_CACHED_SAMPLESHEET_FILE'} = q[t/data/autoqc/haplotag_metrics/samplesheet_45159.csv];

my $tempdir = tempdir(CLEANUP => 0);

use_ok ('npg_qc::autoqc::checks::haplotag_metrics');

my $data_dir = join q[/], $tempdir, 'haplotag_metrics';
dircopy('t/data/autoqc/haplotag_metrics', $data_dir) or die 'Failed to copy';

subtest 'test attributes and simple methods' => sub {
  plan tests => 1;

  my $c = npg_qc::autoqc::checks::haplotag_metrics->new(
   tag_index => 1,
   position  => 3,
   id_run    => 45159);
  isa_ok ($c, 'npg_qc::autoqc::checks::haplotag_metrics');
  
};

subtest 'finding files, calculating metrics' => sub {
  plan tests => 22;

  my $fproot = $data_dir .q{/45159_3#1};
  my $hfile   = $fproot .'._SamHaplotag_Clear_BC';

  my $r1 = npg_qc::autoqc::checks::haplotag_metrics->new(
    id_run           => 45159,
    position         => 3,
    tag_index        => 1,
    input_files      => [$hfile],
  );
  my $r2 = npg_qc::autoqc::checks::haplotag_metrics->new(
    rpt_list         => '45159:3:1',
    input_files      => [$hfile],
  );

  for my $r (($r1, $r2 )) {
    is($r->_file_path_root, $fproot, 'file path root');

    $r->execute();

    my $j;
    lives_ok { $j = $r->result()->freeze } 'serialization to json is ok';

    is($r->result->{'clear_count'}, 499, 'Clear count');
    is($r->result->{'unclear_count'}, 99, 'UnClear count');
    is($r->result->{'missing_count'}, 1, 'Missing count');
    is($r->result->{'pass'}, 1, 'Pass');

    is($r->result->{'clear_file'}, $fproot . '._SamHaplotag_Clear_BC', 'Clear file');
    is($r->result->{'unclear_file'}, $fproot . '._SamHaplotag_UnClear_BC', 'UnClear file');
    is($r->result->{'missing_file'}, $fproot . '._SamHaplotag_Missing_BC_QT_tags', 'Missing file');

    like($j, qr/npg_tracking::glossary::composition/,
        'serialized object contains composition info');
    like($j, qr/npg_tracking::glossary::composition::component::illumina/,
        'serialized object contains component info');
  }

};

1;

use strict;
use warnings;
use Test::More tests => 43;
use Test::Exception;

use_ok('npg_qc::autoqc::checks::tag_metrics');

{
  my $qc = npg_qc::autoqc::checks::tag_metrics->new(position => 2, path => 'nonexisting', id_run => 2549);
  throws_ok {$qc->execute()} qr/directory\ nonexisting\ does\ not\ exist/, 'execute: error on nonexisting path';
}

{
  my $check = npg_qc::autoqc::checks::tag_metrics->new(path => 't/data/autoqc/090721_IL29_2549/data', position =>1, id_run => 2549);
  isa_ok($check, 'npg_qc::autoqc::checks::tag_metrics');
  ok($check->can_run, 'can run the check on a lane');

  $check = npg_qc::autoqc::checks::tag_metrics->new(path => 't/data/autoqc/090721_IL29_2549/data', position =>1, id_run => 2549, tag_index => 1);
  ok(!$check->can_run, 'cannot run the check on a plex with tag index 1');

  $check = npg_qc::autoqc::checks::tag_metrics->new(path => 't/data/autoqc/090721_IL29_2549/data', position =>1, id_run => 2549, tag_index => 0);
  ok(!$check->can_run, 'cannot run the check on a plex with tag index 0');
}

{
 my $check = npg_qc::autoqc::checks::tag_metrics->new(path      => 't/data/autoqc/090721_IL29_2549/data',
                                                      position  => 1,
                                                      id_run    => 2549);
 is(npg_qc::autoqc::checks::tag_metrics->spiked_control_description, 'SPIKED_CONTROL', 'spiked control description as a class method');
 is($check->spiked_control_description, 'SPIKED_CONTROL', 'spiked control description as an instance method');
 lives_ok {$check->execute(); } 'input file does not exist, invoking execute lives';
 is ($check->result->comments, 'Neither t/data/autoqc/090721_IL29_2549/data/2549_1_1.bam.tag_decode.metrics nor t/data/autoqc/090721_IL29_2549/data/2549_1.bam.tag_decode.metrics file found', 'comment with an error');
}

{
  my $header = q[# illumina.BamIndexDecoder INPUT=/dev/stdin OUTPUT=/nfs/sf29/ILorHSany_sf29/analysis/110713_HS12_06551_B_B08M0ABXX/Data/Intensities/PB_basecalls_20110824-121746/6551_1.bam BARCODE_FILE=/nfs/sf29/ILorHSany_sf29/analysis/110713_HS12_06551_B_B08M0ABXX/lane_1.taglist METRICS_FILE=/nfs/sf29/ILorHSany_sf29/analysis/110713_HS12_06551_B_B08M0ABXX/Data/Intensities/PB_basecalls_20110824-121746/6551_1.bam.metrics VALIDATION_STRINGENCY=SILENT CREATE_MD5_FILE=true    BARCODE_TAG_NAME=RT MAX_MISMATCHES=1 MIN_MISMATCH_DELTA=3 MAX_NO_CALLS=2 TMP_DIR=/tmp/gq1 VERBOSITY=INFO QUIET=false COMPRESSION_LEVEL=5 MAX_RECORDS_IN_RAM=500000 CREATE_INDEX=false
];

  my $check = npg_qc::autoqc::checks::tag_metrics->new(path      => 't/data/autoqc/tag_metrics',
                                                       position  => 1,
                                                       id_run    => 6551);

  lives_ok {$check->_parse_header($header)} 'header parsing lives';
  my $result = $check->result;
  is($result->barcode_tag_name, 'RT', 'barcode tag name is RT');
  is($result->max_mismatches_param, 1, 'max mismatches is 1');
  is($result->min_mismatch_delta_param, 3, 'min_mismatch_delta is 3');
  is($result->max_no_calls_param, 2, 'max_no_calls is 2');
}

{
  my @column_header = qw/BARCODE BARCODE_NAME LIBRARY_NAME SAMPLE_NAME DESCRIPTION
                         READS PF_READS PERFECT_MATCHES PF_PERFECT_MATCHES
                         ONE_MISMATCH_MATCHES PF_ONE_MISMATCH_MATCHES PCT_MATCHES
                         RATIO_THIS_BARCODE_TO_BEST_BARCODE_PCT PF_PCT_MATCHES
                         PF_RATIO_THIS_BARCODE_TO_BEST_BARCODE_PCT PF_NORMALIZED_MATCHES
                        /;

  my @tag = ('ACTTGATG', 8, 2798530, 'ERS024598', 'ERP000182: For further',
             6286769,6286769,6227524,6227524,59245,59245,0.053184,0.193679,
             0.053184, 0.193679, 0.708167);

  my $check = npg_qc::autoqc::checks::tag_metrics->new(path      => 't/data/autoqc/tag_metrics',
                                                       position  => 1,
                                                       id_run    => 6551);
  lives_ok {$check->_set_column_indices(join "\t", @column_header)} 'column header parsing lives';
  my $hmap = $check->_columns;
  is(scalar keys %{$hmap}, 11, 'indices for 11 columns saved');
  is($hmap->{BARCODE}, 0, 'BARCODE index is 0');
  is($hmap->{PF_READS}, 6, 'PF_READS index is 6');
  is($hmap->{PCT_MATCHES}, 11, 'PCT_MATCHES index is 11');

  lives_ok {$check->_parse_tag_metrics(join "\t", @tag)} 'tag parsing lives';
  my $r = $check->result;
  is($r->tags->{8}, 'ACTTGATG', 'BARCODE index and sequence');
  is($r->reads_count->{8}, 6286769, 'reads count');
  is($r->reads_pf_count->{8}, 6286769, 'pf reads count');
  is($r->perfect_matches_count->{8}, 6227524, 'perfect_matches_count count');
  is($r->one_mismatch_matches_count->{8}, 59245, 'one_mismatch_matches_count count');
  is($r->matches_percent->{8}, 0.053184, 'matches percent');
  is($r->spiked_control_index, undef, 'spiked control index undefined');
  
  $tag[1] = 2;
  $tag[4] = 'ERP000182: ' . $check->spiked_control_description;
  lives_ok {$check->_parse_tag_metrics(join "\t", @tag)} 'tag parsing lives';
  is(join(q[ ], sort keys %{$r->tags}), '2 8', 'two barcodes parsed');
  is($r->spiked_control_index, 2, 'spiked control index is 2');
  is($r->reads_count->{2}, 6286769, 'reads count');

  $tag[1] = 3;
  throws_ok {$check->_parse_tag_metrics(join "\t", @tag)} 
    qr/Multiple indices are marked as spiked control/, 'multiple spiked control detected, error raised';
}

{
  my $check = npg_qc::autoqc::checks::tag_metrics->new(path      => 't/data/autoqc/tag_metrics',
                                                       position  => 1,
                                                       id_run    => 6551);

  is(scalar @{$check->input_files}, 1, 'one input file found');
  is($check->input_files->[0], 't/data/autoqc/tag_metrics/6551_1.bam.tag_decode.metrics','input file name');
  is($check->result->pass, undef, 'check outcome undefined');
  lives_ok { $check->execute } 'executing is OK';

  my $r = $check->result;
  is(join(q[ ], sort {$a <=> $b}  keys %{$r->tags}), '0 1 2 3 4 5 6 7 8 9 10 11 12 168', '14 barcodes parsed');
  is($r->tags->{10}, 'TAGCTTGT', 'tag 10 sequence is correct');
  is($r->tags->{0}, 'NNNNNNNN', 'tag zero sequence is correct');
  is($r->matches_percent->{0}, 0.023683, 'matches percent  is correct');
  is($r->spiked_control_index, 168, 'spiked control index is 168');
  is($r->pass, 1, 'check passed');
}

1;



use strict;
use warnings;
use Test::More tests => 8;
use Test::Exception;
use Test::Deep;
use Moose::Meta::Class;
use JSON;
use npg_testing::db;

use_ok('npg_qc::Schema::Result::AlignmentFilterMetrics');

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema]);

my $json = 
q { 
{
  "info":
  {
    "Check":"npg_qc::autoqc::checks::alignment_filter_metrics",
    "Aligner":"AlignmentFilter",
    "Aligner_version":"1.09",
    "Check_version":"16223"
  },
  "tag_index":"95",
  "all_metrics":
  {
    "programCommand":"uk.ac.sanger.npg.picard.AlignmentFilter INPUT_ALIGNMENT=[/nfs/sf19/ILorHSany_sf19/analysis/130125_HS23_09225_B_C1CBDACXX/Data/Intensities/BAM_basecalls_20130203-192218/PB_cal_bam/lane1/9225_1#95.bam, /tmp/3cyvq4E579/output_fifo.bam] OUTPUT_ALIGNMENT=[/nfs/sf19/ILorHSany_sf19/analysis/130125_HS23_09225_B_C1CBDACXX/Data/Intensities/BAM_basecalls_20130203-192218/PB_cal_bam/archive/lane1/9225_1#95_phix.bam, /nfs/sf19/ILorHSany_sf19/analysis/130125_HS23_09225_B_C1CBDACXX/Data/Intensities/BAM_basecalls_20130203-192218/PB_cal_bam/archive/lane1/9225_1#95.bam] METRICS_FILE=/nfs/sf19/ILorHSany_sf19/analysis/130125_HS23_09225_B_C1CBDACXX/Data/Intensities/BAM_basecalls_20130203-192218/PB_cal_bam/archive/lane1/9225_1#95.bam_alignment_filter_metrics.json VALIDATION_STRINGENCY=SILENT CREATE_MD5_FILE=true    VERBOSITY=INFO QUIET=false COMPRESSION_LEVEL=5 MAX_RECORDS_IN_RAM=500000 CREATE_INDEX=false",
    "refList":[
     [{"ur":null,"ln":5386,"sp":null,"as":null,"sn":"phix-illumina.fa"}],
     [{"ur":"ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/phase2_reference_assembly_sequence/hs37d5.fa.gz","ln":249250621,"sp":"Human","as":"NCBI37","sn":"1"}]
    ],
    "numberAlignments":2,
    "totalReads":28220671,
    "readsCountByAlignedNumForward":[81030,28139641,0],
    "readsCountByAlignedNumReverse":[119035,28101635,1],
    "readsCountPerRef":[120,28161403],
    "readsCountUnaligned":59148,
    "chimericReadsCount":[[52,14],[0,28079687]]
  },
  "position":"1",
  "path":"/nfs/sf19/ILorHSany_sf19/analysis/130125_HS23_09225_B_C1CBDACXX/Data/Intensities/BAM_basecalls_20130203-192218/PB_cal_bam/archive/lane1",
  "id_run":"9225"
  }
 };

my $values = from_json($json);
my $rs = $schema->resultset('AlignmentFilterMetrics');

{
  isa_ok($rs->new($values), 'npg_qc::Schema::Result::AlignmentFilterMetrics');
  my %values1 = %{$values};
  my $v1 = \%values1;

  $rs->result_class->deflate_unique_key_components($v1);
  is($v1->{'tag_index'}, 95, 'tag index not deflated');
  lives_ok {$rs->find_or_new($v1)->set_inflated_columns($v1)->update_or_insert()} 'lane record inserted';
  my $rs1 = $rs->search({});
  is ($rs1->count, 1, q[one row created in the table]);
  my $row = $rs1->next;
  is($row->tag_index, 95, 'tag index retrieved correctly');
  is(ref $row->all_metrics->{'refList'}, 'ARRAY', 'refList returned as an array');
  cmp_deeply($row->all_metrics->{'refList'}, $values->{'all_metrics'}->{'refList'},
    'refList array content is correct');
}

1;



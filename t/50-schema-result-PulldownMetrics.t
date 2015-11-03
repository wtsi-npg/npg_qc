use strict;
use warnings;
use Test::More tests => 8;
use Test::Exception;
use Test::Deep;
use Moose::Meta::Class;
use JSON;
use npg_testing::db;

use_ok('npg_qc::Schema::Result::PulldownMetrics');

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema]);

  my $json = q { 
  {
  "other_metrics":{"BAIT_DESIGN_EFFICIENCY":"0.761882","HS_PENALTY_30X":"8.869793","PCT_PF_UQ_READS":"0.87808","PCT_PF_READS":"1","AT_DROPOUT":null,"PCT_TARGET_BASES_20X":"0.725205","PCT_USABLE_BASES_ON_BAIT":"0.461668","SAMPLE":null,"READ_GROUP":null,"PCT_TARGET_BASES_30X":"0.591139","BAIT_SET":"S02972011-GRCh37_hs37d5-CTR","LIBRARY":null,"GC_DROPOUT":null,"PCT_TARGET_BASES_10X":"0.841458","FOLD_80_BASE_PENALTY":"3.02982","PCT_USABLE_BASES_ON_TARGET":"0.368722","PCT_PF_UQ_READS_ALIGNED":"0.901849","PCT_TARGET_BASES_2X":"0.942171","PCT_OFF_BAIT":"0.25087","HS_PENALTY_20X":"7.850276","PCT_SELECTED_BASES":"0.74913","PF_READS":"62743300","HS_PENALTY_10X":"7.090912","GENOME_SIZE":"3137454505","ON_BAIT_VS_SELECTED":"0.779202"},
  "position":"1","bait_territory":51543125,"fold_enrichment":35.531502,"unique_bases_aligned_num":3721789329,"bait_path":"/lustre/scratch109/srpipe/baits/Human_all_exon_50MB/1000Genomes_hs37d5","total_reads_num":62743300,"library_size":87721234,"target_territory":39269754,
  "info":{"Check":"npg_qc::autoqc::checks::pulldown_metrics","Aligner":"Picard CalculateHsMetrics.jar","Aligner_version":"1.72(1230)","Check_version":"16569"},
  "unique_reads_num":55093662,
  "path":"/nfs/sf19/ILorHSany_sf19/analysis/130125_HS23_09225_B_C1CBDACXX/Data/Intensities/BAM_basecalls_20130203-192218/PB_cal_bam/archive/lane1","on_bait_bases_num":2172494409,
  "off_bait_bases_num":933686236,
  "id_run":"9225",
  "tag_index":"0",
  "mean_target_coverage":45.447307,
  "mean_bait_coverage":42.149063,
  "unique_reads_aligned_num":49686179,
  "near_bait_bases_num":615608684,
  "zero_coverage_targets_fraction":0.037688,
  "on_target_bases_num":1735110712
  }
};

my $values = from_json($json);
my $rs = $schema->resultset('PulldownMetrics');
isa_ok($rs->new_result($values), 'npg_qc::Schema::Result::PulldownMetrics');

{
  my %values1 = %{$values};
  my $v1 = \%values1;

  $rs->deflate_unique_key_components($v1);
  is($v1->{'tag_index'}, 0, 'tag index zero not deflated');
  lives_ok {$rs->find_or_new($v1)->set_inflated_columns($v1)->update_or_insert()} 'tag zero record inserted';
  my $rs1 = $rs->search({});
  is ($rs1->count, 1, q[one row created in the table]);
  my $row = $rs1->next;
  is($row->tag_index, 0, 'tag index zero retrieved correctly');
  is(ref $row->other_metrics, 'HASH', 'other_metrics returned as a hash ref');
  cmp_deeply($row->other_metrics, $values->{'other_metrics'},
    'other_metrics hash content is correct');
}
1;



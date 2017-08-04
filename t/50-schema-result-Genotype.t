use strict;
use warnings;
use Test::More tests => 11;
use Test::Exception;
use Test::Deep;
use Moose::Meta::Class;
use JSON;

use npg_testing::db;
use t::autoqc_util;

use_ok('npg_qc::Schema::Result::Genotype');

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema]);

  my $json = q { 
{"bam_call_string":"TGGGGTGGCCCTGGCCAATGTGGAAAAGAAAACCCCCTGATCGGGACCGATC",
"position":"1",
"alternate_match_count":0,
"alternate_relaxed_match_count":0,
"bam_gt_depths_string":"20;107;66;51;11;43;22;20;162;59;62;88;50;31;29;31;38;40;54;66;55;37;30;14;82;23",
"sample_name_relaxed_match":{"matched_sample_name":"SC_ESGIISO5388097","match_count":26,"match_pct":1,"match_type":"RM_SampleNameMatch","common_snp_count":26,"mismatch_count":0},
"alternate_matches":{"matched_sample_name":"SC_ESGIISO5388097","match_count":26,"match_pct":1,"match_type":"RM_SampleNameMatch","common_snp_count":26,"mismatch_count":0},
"alternate_relaxed_matches":{"matched_sample_name":"SC_ESGIISO5388097","match_count":26,"match_pct":1,"match_type":"RM_SampleNameMatch","common_snp_count":26,"mismatch_count":0},
"reference":"hs37d5.fa",
"snp_call_set":"W30467",
"bam_file":"9225_1#93.bam",
"bam_call_count":26,
"sample_name_match":{"match_pct":1,"match_type":"SampleNameMatch","common_snp_count":26,"mismatch_count":0,"match_score":"1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1","matched_sample_name":"SC_ESGIISO5388097","match_count":26,"matched_gt":"32311322233323112133323233"},
"info":{"Check":"npg_qc::autoqc::checks::genotype","Check_version":"16588","Caller":"/software/solexa/bin/aligners/bin/samtools_irods","Caller_version":"0.1.18-dev (r982:313:irods_v03)"},
"pass":1,
"search_parameters":{"report_only_poss_dups":"Y","calls_per_sample":26,"base_gt":"32311322233323112133323233","min_common_snps":21,"min_sample_callrate":95,"high_concordance_threshold":70,"poss_dup_level":95,"comparison_sets":"All"},
"bam_gt_likelihood_string":"150,0,255;255,255,0;255,0,255;255,111,0;235,33,0;211,0,255;255,63,0;255,57,0;255,255,0;255,0,255;255,0,255;255,0,255;255,141,0;255,0,255;255,87,0;255,93,0;0;0;255,0,255;255,0,255;255,0,255;255,102,0;247,0,255;255,39,0;255,0,255;254,0,204",
"expected_sample_name":"SC_ESGIISO5388097",
"path":"/nfs/sf19/ILorHSany_sf19/analysis/130125_HS23_09225_B_C1CBDACXX/Data/Intensities/BAM_basecalls_20130203-192218/PB_cal_bam/archive/lane1",
"id_run":"9225",
"genotype_data_set":"SQNMGTDATA/20130205161039",
"tag_index":"93","bam_file_md5":"a44b2825ec60391cac8c49b616fa055a"}
};

my $values = from_json($json);
$values->{'id_seq_composition'} =
  t::autoqc_util::find_or_save_composition($schema,
    {id_run => 9225, position => 1, tag_index => 93});
my $rs = $schema->resultset('Genotype');
isa_ok($rs->new_result($values), 'npg_qc::Schema::Result::Genotype');
{
  my %values1 = %{$values};
  my $v1 = \%values1;

  lives_ok {$rs->find_or_new($v1)->set_inflated_columns($v1)->update_or_insert()} 'tag record inserted';
  my $rs1 = $rs->search({});
  is ($rs1->count, 1, q[one row created in the table]);
  my $row = $rs1->next;
  is($row->tag_index, 93, 'tag index retrieved correctly');
  is(ref $row->sample_name_relaxed_match, 'HASH', 'sample_name_relaxed_match returned as a hash ref');
  cmp_deeply($row->sample_name_relaxed_match, $values->{'sample_name_relaxed_match'},
    'actual_quantile_y array content is correct');

  $v1 = \%values1; 
  delete $v1->{'id_run'};
  delete $v1->{'position'};
  delete $v1->{'tag_index'};
  my $row1;
  lives_ok {$row1 = $rs->find_or_new($v1)->set_inflated_columns($v1)->update_or_insert()}
    'another or the same row?';
  is ($row->id_genotype, $row1->id_genotype, 'new row is not created');

  $v1->{'snp_call_set'} = 'new set';
  lives_ok {$row1 = $rs->find_or_new($v1)->set_inflated_columns($v1)->update_or_insert()}
    'row for another snip set is created';
  isnt ($row->id_genotype, $row1->id_genotype, 'new row is created');
}

1;

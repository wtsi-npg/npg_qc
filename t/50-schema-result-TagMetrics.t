use strict;
use warnings;
use Test::More tests => 6;
use Test::Exception;
use Test::Deep;
use Moose::Meta::Class;
use JSON;
use npg_testing::db;

use_ok('npg_qc::Schema::Result::TagMetrics');

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema]);

my $json = q { 
{"metrics_file":"/nfs/sf19/ILorHSany_sf19/analysis/130125_HS23_09225_B_C1CBDACXX/Data/Intensities/BAM_basecalls_20130203-192218/9225_4.bam.tag_decode.metrics","barcode_tag_name":"BC","position":"5","min_mismatch_delta_param":1,"max_no_calls_param":2,
  "reads_pf_count":{"6":"21444896","3":"21072937","7":"18987467","168":"793860","2":"20768317","8":"19094802","1":"24316092","4":"20748369","0":"2822055","5":"20695941"},
  "max_mismatches_param":1,"spiked_control_index":168,
  "perfect_matches_count":{"6":"21220408","3":"20799555","7":"18862057","168":"785951","2":"20638140","8":"18952008","1":"24145882","4":"20554319","0":"0","5":"20457406"},
  "matches_percent":{"6":"0.125596","3":"0.123418","7":"0.111204","168":"0.004649","2":"0.121634","8":"0.111832","1":"0.142412","4":"0.121517","0":"0.016528","5":"0.12121"},
  "perfect_matches_pf_count":{"6":"21220408","3":"20799555","7":"18862057","168":"785951","2":"20638140","8":"18952008","1":"24145882","4":"20554319","0":"0","5":"20457406"},
  "info":{"Check":"npg_qc::autoqc::checks::tag_metrics","Check_version":"14685"},
  "pass":1,"path":"/nfs/sf19/ILorHSany_sf19/analysis/130125_HS23_09225_B_C1CBDACXX/Data/Intensities/BAM_basecalls_20130203-192218",
  "one_mismatch_matches_pf_count":{"6":"224488","3":"273382","7":"125410","168":"7909","2":"130177","8":"142794","1":"170210","4":"194050","0":"0","5":"238535"},
  "id_run":"9225",
  "tags":{"6":"GCCAATGT","3":"TTAGGCAT","7":"CAGATCTG","168":"ACAACGCA","2":"CGATGTTT","8":"ACTTGATG","1":"ATCACGTT","4":"TGACCACT","0":"NNNNNNNN","5":"ACAGTGGT"},
  "matches_pf_percent":{"6":"0.125596","3":"0.123418","7":"0.111204","168":"0.004649","2":"0.121634","8":"0.111832","1":"0.142412","4":"0.121517","0":"0.016528","5":"0.12121"},
  "one_mismatch_matches_count":{"6":"224488","3":"273382","7":"125410","168":"7909","2":"130177","8":"142794","1":"170210","4":"194050","0":"0","5":"238535"},
  "reads_count":{"6":"21444896","3":"21072937","7":"18987467","168":"793860","2":"20768317","8":"19094802","1":"24316092","4":"20748369","0":"2822055","5":"20695941"}}
};

my $values = from_json($json);
my $rs = $schema->resultset('TagMetrics');
isa_ok($rs->new_result($values), 'npg_qc::Schema::Result::TagMetrics');

{
  my %values1 = %{$values};
  my $v1 = \%values1;

  $rs->deflate_unique_key_components($v1);
  lives_ok {$rs->find_or_new($v1)->set_inflated_columns($v1)->update_or_insert()} 'tag record inserted';
  my $rs1 = $rs->search({});
  is ($rs1->count, 1, q[one row created in the table]);
  my $row = $rs1->next;
  is(ref $row->one_mismatch_matches_count, 'HASH', 'one_mismatch_matches_count returned as hash ref');
  cmp_deeply($row->one_mismatch_matches_count, $values->{'one_mismatch_matches_count'},
    'one_mismatch_matches_count hash content is correct'); 
}   
1;



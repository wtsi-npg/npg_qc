use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;
use Test::Warn;
use File::Temp qw/tempdir/;
use File::Copy;

use_ok('npg_qc::autoqc::checks::meta');

my $dir = tempdir( CLEANUP => 1 );
my $test_data_dir = 't/data/autoqc/meta';
my $conf_file_path = "$test_data_dir/product_release.yml";

local $ENV{NPG_CACHED_SAMPLSHEET_FILE} =
    't/data/autoqc/meta/samplesheet_27483.csv';

subtest 'construction object, deciding whether to run' => sub {
  plan tests => 18;

  my $check = npg_qc::autoqc::checks::meta->new(
    conf_path => $test_data_dir,
    qc_in     => $test_data_dir,
    rpt_list  => '27483:1:2');
  isa_ok ($check, 'npg_qc::autoqc::checks::meta');
  isa_ok ($check->result, 'npg_qc::autoqc::results::meta');
  my $can_run;
  warnings_like { $can_run = $check->can_run }
    [qr/Reading product configuration from/,
     qr/Study config not found for/],
    'can_run is accompanied by warnings';
  ok (!$can_run, 'can_run returns false - no study config');
  is ($check->result->comments,
    'No criteria defined in the product configuration file',
    'reason logged');
  lives_ok { $check->execute() } 'cannot run, but execute method runs OK';

  $check = npg_qc::autoqc::checks::meta->new(
    conf_path => "$test_data_dir/no_robo",
    qc_in     => $test_data_dir,
    rpt_list  => '27483:1:2');
  warnings_like { $can_run = $check->can_run }
    [qr/Reading product configuration from/,
     qr/robo_qc section is not present for/],
    'can_run is accompanied by warnings';
  ok (!$can_run, 'can_run returns false - no robo config');
  is ($check->result->comments,
    'No criteria defined in the product configuration file',
    'reason logged');

  $check = npg_qc::autoqc::checks::meta->new(
    conf_path => "$test_data_dir/no_criteria",
    qc_in     => $test_data_dir,
    rpt_list  => '27483:1:2');
  warnings_like { $can_run = $check->can_run }
    [qr/Reading product configuration from/,
     qr/No roboqc criteria defined for library type 'RNA PolyA'/],
    'can_run is accompanied by warnings';
  ok (!$can_run, 'can_run returns false - no criteria for this library type');
  is ($check->result->comments,
    'No criteria defined in the product configuration file',
    'reason logged');

  $check = npg_qc::autoqc::checks::meta->new(
    conf_path => "$test_data_dir/with_criteria",
    qc_in     => $test_data_dir,
    rpt_list  => '27483:1:2');
  warnings_like { $can_run = $check->can_run }
    [qr/Reading product configuration from/],
    'can_run is accompanied by warnings';
  ok ($can_run, 'can_run returns true');
  ok (!$check->result->comments, 'No comments logged');
  my $expected_criteria = {'and' => [
                           '( bam_flagstats.target_proper_pair_mapped_reads / bam_flagstats.target_mapped_reads ) > 0.95',
                           'bam_flagstats.target_mapped_bases > 85_000_000_000',
                           'bam_flagstats.target_percent_gt_coverage_threshold > 95',
                           'verify_bam_id.freemix < 0.01',
                           '( bcfstats.genotypes_nrd_dividend / bcfstats.genotypes_nrd_divisor ) < 0.02'
                          ]};
  is_deeply ($check->_criteria, $expected_criteria, 'criteria parsed correctly');

  $check = npg_qc::autoqc::checks::meta->new(
    conf_path => "$test_data_dir/error1",
    qc_in     => $test_data_dir,
    rpt_list  => '27483:1:2');
  throws_ok { $check->can_run } qr/acceptance_criteria key is missing/,
    'conf file format is incorrect';
  $check = npg_qc::autoqc::checks::meta->new(
    conf_path => "$test_data_dir/error2",
    qc_in     => $test_data_dir,
    rpt_list  => '27483:1:2');
  throws_ok { $check->can_run } qr/library_type key is missing/,
    'conf file format is incorrect'; 
};

subtest 'setting options for qc store' => sub {
  plan tests => 4;

  my $check = npg_qc::autoqc::checks::meta->new(
    conf_path => "$test_data_dir/with_criteria",
    qc_in     => $test_data_dir,
    rpt_list  => '27483:1:2');
  my $expected_class_names = [qw/bam_flagstats bcfstats verify_bam_id/];
  is_deeply ($check->_result_class_names, $expected_class_names, 'class names');
  is_deeply ($check->_qc_store->checks_list, $expected_class_names,
    'class names correctly propagated to the qc store object');

  ok (!$check->use_db, 'default is not to use the db');
  ok (!$check->_qc_store->use_db, 
    'db option correctly propagated to the qc store object');
};

subtest 'finding files - file system' => sub {
  plan tests => 15;

  my $expected = 'Expected results for bam_flagstats, bcfstats, verify_bam_id,';

  my $check = npg_qc::autoqc::checks::meta->new(
    conf_path => "$test_data_dir/with_criteria",
    qc_in     => $test_data_dir,
    rpt_list  => '27483:1:2');
  throws_ok { $check->_results } qr/$expected found none/, 'no results - error';

  # should have all three for the entiry and phix for bam_flagstats and qx_yield
  # and gradually add them to qc_in

  local $ENV{NPG_CACHED_SAMPLSHEET_FILE} =
    't/data/autoqc/meta/samplesheet_29524.csv';

  for my $name (('29524#2.qX_yield.json',
                 '29524#2_phix.bam_flagstats.json',
                 '29524#7.bam_flagstats.json')) {
    copy "$test_data_dir/$name", "$dir/$name";
    my $c = npg_qc::autoqc::checks::meta->new(
      conf_path => $test_data_dir,
      qc_in     => $dir,
      rpt_list  => '29524:1:2;29524:2:2;29524:3:2;29524:4:2');
    throws_ok { $c->_results } qr/$expected found none/, 'no results - error';    
  }

  my $name = '29524#2.bam_flagstats.json';
  copy "$test_data_dir/$name", "$dir/$name";
  $check = npg_qc::autoqc::checks::meta->new(
    conf_path => $test_data_dir,
    qc_in     => $dir,
    rpt_list  => '29524:1:2;29524:2:2;29524:3:2;29524:4:2');
  throws_ok { $check->_results }
    qr/$expected found results for bam_flagstats/, 'not all results - error';

  $name = '29524#2.verify_bam_id.json';
  copy "$test_data_dir/$name", "$dir/$name";
  $check = npg_qc::autoqc::checks::meta->new(
    conf_path => $test_data_dir,
    qc_in     => $dir,
    rpt_list  => '29524:1:2;29524:2:2;29524:3:2;29524:4:2');
  throws_ok { $check->_results }
    qr/$expected found results for bam_flagstats, verify_bam_id/,
    'not all results - error';

  $name = '29524#2.bcfstats.json';
  copy "$test_data_dir/$name", "$dir/$name";
  $check = npg_qc::autoqc::checks::meta->new(
    conf_path => $test_data_dir,
    qc_in     => $test_data_dir,
    rpt_list  => '29524:1:2;29524:2:2;29524:3:2;29524:4:2');
  lives_ok { $check->_results } 'no error - all expected results loaded';
  is_deeply ([sort keys %{$check->_results}],
             [sort qw/bam_flagstats bcfstats verify_bam_id/], 'correct keys');
  
  for my $name (keys %{$check->_results}) {
    my $result = $check->_results->{$name};
    is (ref $result, 'npg_qc::autoqc::results::'. $name, 'corrrect type of object hashed');
    is ($result->composition->get_component(0)->tag_index, 2, 'tag index correct');
  }
  ok (!$check->_results->{bam_flagstats}->composition->get_component(0)->subset,
    'subset is undefined despite phix result present in test data');
};

1;

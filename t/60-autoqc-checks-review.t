use strict;
use warnings;
use Test::More tests => 8;
use Test::Exception;
use Test::Warn;
use File::Temp qw/tempdir/;
use File::Copy;
use File::Slurp qw/read_file write_file/;
use JSON qw/from_json to_json/;
use List::MoreUtils qw/any/;

use npg_testing::db;
use npg_qc::autoqc::qc_store;
use npg_tracking::glossary::composition;

use_ok('npg_qc::autoqc::checks::review');

my $dir = tempdir( CLEANUP => 1 );
my $test_data_dir = 't/data/autoqc/review';
my $conf_file_path = "$test_data_dir/product_release.yml";

local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
    't/data/autoqc/review/samplesheet_27483.csv';

my $criteria_list = [
  '( bam_flagstats.target_proper_pair_mapped_reads / bam_flagstats.target_mapped_reads ) > 0.95',
  '( bcfstats.genotypes_nrd_dividend / bcfstats.genotypes_nrd_divisor ) < 0.02',
  'bam_flagstats.target_mapped_bases > 85_000_000_000',
  'bam_flagstats.target_percent_gt_coverage_threshold > 95',
  'verify_bam_id.freemix < 0.01'
];

subtest 'construction object, deciding whether to run' => sub {
  plan tests => 19;

  my $check = npg_qc::autoqc::checks::review->new(
    conf_path => $test_data_dir,
    qc_in     => $test_data_dir,
    rpt_list  => '27483:1:2');
  isa_ok ($check, 'npg_qc::autoqc::checks::review');
  isa_ok ($check->result, 'npg_qc::autoqc::results::review');
  my $can_run;
  warnings_like { $can_run = $check->can_run }
    [qr/Study config not found for/],
    'can_run is accompanied by warnings';
  ok (!$can_run, 'can_run returns false - no study config');
  is ($check->result->comments,
    'No criteria defined in the product configuration file',
    'reason logged');
  lives_ok { $check->execute() } 'cannot run, but execute method runs OK';
  is ($check->result->pass, undef,
    'pass attribute of the result object is undefined');
  is ($check->result->criteria_md5, undef,
    'criteria_md5 attribute of the result object is undefined');

  $check = npg_qc::autoqc::checks::review->new(
    conf_path => "$test_data_dir/no_robo",
    qc_in     => $test_data_dir,
    rpt_list  => '27483:1:2');
  warnings_like { $can_run = $check->can_run }
    [qr/robo_qc section is not present for/],
    'can_run is accompanied by warnings';
  ok (!$can_run, 'can_run returns false - no robo config');
  is ($check->result->comments,
    'No criteria defined in the product configuration file',
    'reason logged');

  $check = npg_qc::autoqc::checks::review->new(
    conf_path => "$test_data_dir/no_criteria",
    qc_in     => $test_data_dir,
    rpt_list  => '27483:1:2');
  warnings_like { $can_run = $check->can_run }
    [qr/No roboqc criteria defined for library type 'RNA PolyA'/],
    'can_run is accompanied by warnings';
  ok (!$can_run, 'can_run returns false - no criteria for this library type');
  is ($check->result->comments,
    'No criteria defined in the product configuration file',
    'reason logged');

  $check = npg_qc::autoqc::checks::review->new(
    conf_path => "$test_data_dir/with_criteria",
    qc_in     => $test_data_dir,
    rpt_list  => '27483:1:2');
  ok ($check->can_run, 'can_run returns true');
  ok (!$check->result->comments, 'No comments logged');
  is_deeply ($check->_criteria, {'and' => $criteria_list}, 'criteria parsed correctly');

  $check = npg_qc::autoqc::checks::review->new(
    conf_path => "$test_data_dir/error1",
    qc_in     => $test_data_dir,
    rpt_list  => '27483:1:2');
  throws_ok { $check->can_run } qr/acceptance_criteria key is missing/,
    'conf file format is incorrect';
  $check = npg_qc::autoqc::checks::review->new(
    conf_path => "$test_data_dir/error2",
    qc_in     => $test_data_dir,
    rpt_list  => '27483:1:2');
  throws_ok { $check->can_run } qr/library_type key is missing/,
    'conf file format is incorrect'; 
};

subtest 'setting options for qc store' => sub {
  plan tests => 4;

  my $check = npg_qc::autoqc::checks::review->new(
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

subtest 'finding result - file system' => sub {
  plan tests => 15;

  my $expected = 'Expected results for bam_flagstats, bcfstats, verify_bam_id,';
  my $rpt_list = '29524:1:2;29524:2:2;29524:3:2;29524:4:2';

  my $check = npg_qc::autoqc::checks::review->new(
    conf_path => "$test_data_dir/with_criteria",
    qc_in     => $test_data_dir,
    rpt_list  => '27483:1:2');
  throws_ok { $check->_results } qr/$expected found none/, 'no results - error';

  # should have all three for the entiry and phix for bam_flagstats and qx_yield
  # and gradually add them to qc_in

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
    't/data/autoqc/review/samplesheet_29524.csv';

  for my $name (('29524#2.qX_yield.json',
                 '29524#2_phix.bam_flagstats.json',
                 '29524#7.bam_flagstats.json')) {
    copy "$test_data_dir/$name", "$dir/$name";
    my $c = npg_qc::autoqc::checks::review->new(
      conf_path => $test_data_dir,
      qc_in     => $dir,
      rpt_list  => $rpt_list);
    throws_ok { $c->_results } qr/$expected found none/, 'no results - error';    
  }

  my $name = '29524#2.bam_flagstats.json';
  copy "$test_data_dir/$name", "$dir/$name";
  $check = npg_qc::autoqc::checks::review->new(
    conf_path => $test_data_dir,
    qc_in     => $dir,
    rpt_list  => $rpt_list);
  throws_ok { $check->_results }
    qr/$expected found results for bam_flagstats/, 'not all results - error';

  $name = '29524#2.verify_bam_id.json';
  copy "$test_data_dir/$name", "$dir/$name";
  $check = npg_qc::autoqc::checks::review->new(
    conf_path => $test_data_dir,
    qc_in     => $dir,
    rpt_list  => '29524:1:2;29524:2:2;29524:3:2;29524:4:2');
  throws_ok { $check->_results }
    qr/$expected found results for bam_flagstats, verify_bam_id/,
    'not all results - error';

  $name = '29524#2.bcfstats.json';
  copy "$test_data_dir/$name", "$dir/$name";
  $check = npg_qc::autoqc::checks::review->new(
    conf_path => $test_data_dir,
    qc_in     => $test_data_dir,
    rpt_list  => $rpt_list);
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

subtest 'finding results - database' => sub {
  plan tests => 15;

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
    't/data/autoqc/review/samplesheet_29524.csv';

  my $rpt_list = '29524:1:2;29524:2:2;29524:3:2;29524:4:2';

  my $schema =  Moose::Meta::Class->create_anon_class(
    roles => [qw/npg_testing::db/])->new_object()
                                   ->create_test_db(q[npg_qc::Schema]);
  my $init = {
    conf_path => $test_data_dir,
    rpt_list  => $rpt_list,
    use_db    => 1,
    _qc_store => npg_qc::autoqc::qc_store->new(
      use_db      => 1,
      qc_schema   => $schema,
      checks_list => [qw/bam_flagstats bcfstats verify_bam_id/]
    )
  };
  my $check;
  lives_ok { $check = npg_qc::autoqc::checks::review->new($init) }
    'object created without qc_in defined';
  
  my $expected = 'Expected results for bam_flagstats, bcfstats, verify_bam_id,';
  throws_ok { $check->_results } qr/$expected found none/, 'no results - error';

  # create composition, but not records in the result tables
  my $composition = npg_tracking::glossary::composition->thaw(
                    read_file "$test_data_dir/29524#2.composition.json");
  my $row = $schema->resultset('BamFlagstats')
            ->find_or_create_seq_composition($composition); 
  $check = npg_qc::autoqc::checks::review->new($init);
  throws_ok { $check->_results } qr/$expected found none/, 'no results - error';

  my $create_qc_record = sub {
    my ($file_name, $rs_name) = @_;
    my $values = from_json(read_file "$test_data_dir/$file_name");
    delete $values->{'__CLASS__'};
    delete $values->{'composition'};
    delete $values->{'result_file_path'};
    $values->{'id_seq_composition'} = $row->id_seq_composition;
    $schema->resultset($rs_name)->create($values);
  };

  # create a record in one of the result tables
  $create_qc_record->('29524#2.bam_flagstats.json', 'BamFlagstats');

  $init->{'qc_in'} = $test_data_dir;

  $check = npg_qc::autoqc::checks::review->new($init);
  throws_ok { $check->_results }
    qr/$expected found results for bam_flagstats/, 'not all results - error';

  # create records in all necessary tables plus one more
  $create_qc_record->('29524#2.qX_yield.json', 'QXYield');
  $create_qc_record->('29524#2.bcfstats.json', 'Bcfstats');
  $create_qc_record->('29524#2.verify_bam_id.json', 'VerifyBamId');

  
  $check = npg_qc::autoqc::checks::review->new($init);
  lives_ok { $check->_results } 'no error - all expected results loaded';
  is_deeply ([sort keys %{$check->_results}],
             [sort qw/bam_flagstats bcfstats verify_bam_id/], 'correct keys');
  for my $name (keys %{$check->_results}) {
    my $result = $check->_results->{$name};
    like (ref $result, qr/\Anpg_qc::Schema::Result/, 'DBIx object retrieved');
    is ($check->_results->{$name}->class_name, $name, 'result type is correct');
    is ($result->composition->get_component(0)->tag_index, 2, 'tag index correct');
  }
};

subtest 'single expression evaluation' => sub {
  plan tests => 10;

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
    't/data/autoqc/review/samplesheet_29524.csv';
  my $rpt_list = '29524:1:2;29524:2:2;29524:3:2;29524:4:2';

  my $criteria =  [
    '( bam_flagstats.target_proper_pair_mapped_reads / bam_flagstats.target_mapped_reads ) > 0.95',
    'bam_flagstats.target_mapped_bases > 85_000_000_000',
    'bam_flagstats.target_percent_gt_coverage_threshold > 95',
    'verify_bam_id.freemix < 0.01',
    '( bcfstats.genotypes_nrd_dividend / bcfstats.genotypes_nrd_divisor ) < 0.02'
                  ];

  my $check = npg_qc::autoqc::checks::review->new(
    conf_path => $test_data_dir,
    qc_in     => $test_data_dir,
    rpt_list  => $rpt_list);

  throws_ok {$check->_evaluate_expression('verify_bam.freemix < 0.01')}
    qr/No autoqc result for evaluation of/,
    'error if check name is unknown';
  throws_ok {$check->_evaluate_expression('verify_bam_id.freemix_free < 0.01')}
    qr/Can't locate object method \"freemix_free\"/,
    'error if method name is unknown';

  for my $c (@{$criteria}) {
    lives_and { is $check->_evaluate_expression($c), 1 } "pass for $c";
  }
  
  is ($check->_evaluate_expression('verify_bam_id.freemix > 0.01'), 0,
    'negative outcome');
  is ($check->_evaluate_expression('bam_flagstats.target_mapped_bases > 85_000_000_000_000'), 0,
    'negative outcome');
  is ($check->_evaluate_expression(
    '( bcfstats.genotypes_nrd_dividend * bcfstats.genotypes_nrd_divisor ) < 0.02'), 0,
    'negative outcome');
};

subtest 'evaluation within the execute method' => sub {
  plan tests => 24;

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
    't/data/autoqc/review/samplesheet_29524.csv';
  my $rpt_list = '29524:1:2;29524:2:2;29524:3:2;29524:4:2';

  my $check = npg_qc::autoqc::checks::review->new(
    conf_path => $test_data_dir,
    qc_in     => $dir,
    rpt_list  => $rpt_list);

  lives_ok { $check->execute } 'execute method runs OK';
  is ($check->result->pass, 1, 'result pass attribute is set to 1');
  my %expected = map { $_ => 1 } @{$criteria_list};
  is_deeply ($check->result->evaluation_results(), \%expected,
    'evaluation results are saved');
  my $outcome = $check->result->qc_outcome;
  is ($outcome->{'mqc_outcome'} , 'Accepted preliminary', 'correct outcome string');
  is ($outcome->{'username'}, 'robo_qc', 'correct process id');
  ok ($outcome->{'timestamp'}, 'timestamp saved');

  my $target = "$dir/29524#2.bam_flagstats.json";

  my $failures = {};
  $failures->{3}  = [qw/target_mapped_bases/];
  $failures->{7}  = [qw/target_mapped_bases target_percent_gt_coverage_threshold/];
  $failures->{17} = [qw/target_percent_gt_coverage_threshold/];

  for my $index (qw/3 7 17/) {

    my $f = '29524#' . $index . '.bam_flagstats.json';
    my $values = from_json(read_file "$test_data_dir/$f");
    for my $component (@{$values->{composition}->{components}}) {
      $component->{tag_index} = 2;
    }
    write_file($target, to_json($values));

    $check = npg_qc::autoqc::checks::review->new(
      final_qc_outcome => 1,
      conf_path       => $test_data_dir,
      qc_in           => $dir,
      rpt_list        => $rpt_list);
    lives_ok { $check->execute } 'execute method runs OK';
    is ($check->result->pass, 0, 'result pass attribute is set to 0');
    my $e = {};
    my @failed = @{$failures->{$index}};
    for my $c (@{$criteria_list}) {
      $e->{$c} = (any { $c =~ /$_/ } @failed) ? 0 : 1;
    }

    is_deeply ($check->result->evaluation_results(), $e, 'evaluation results are saved');
    $outcome = $check->result->qc_outcome;
    is ($outcome->{'mqc_outcome'} , 'Rejected final', 'correct outcome string');
    is ($outcome->{'username'}, 'robo_qc', 'correct process id');
    ok ($outcome->{'timestamp'}, 'timestamp saved');
  }  
};

subtest 'error in evaluation' => sub {
  plan tests => 5;

  my $f = '29524#3.bam_flagstats.json';
  my $values = from_json(read_file "$test_data_dir/$f");
  delete $values->{target_mapped_bases};
  for my $component (@{$values->{composition}->{components}}) {
    $component->{tag_index} = 2;
  }
  my $target = "$dir/29524#2.bam_flagstats.json";
  write_file($target, to_json($values));

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
    't/data/autoqc/review/samplesheet_29524.csv';
  my $rpt_list = '29524:1:2;29524:2:2;29524:3:2;29524:4:2'; 

  my $check = npg_qc::autoqc::checks::review->new(
    conf_path        => $test_data_dir,
    qc_in            => $dir,
    rpt_list         => $rpt_list,
    final_qc_outcome => 1);
  throws_ok { $check->execute }
    qr/Error evaluating expression .+ Use of uninitialized value/,
    'final outcome - not capturing the error';

  $check = npg_qc::autoqc::checks::review->new(
    conf_path        => $test_data_dir,
    qc_in            => $dir,
    rpt_list         => $rpt_list,
    final_qc_outcome => 0);
  lives_ok { $check->execute }
    'preliminary outcome - capturing the error';
  is ($check->result->pass, undef, 'pass value undefined');
  is ($check->result->qc_outcome->{'mqc_outcome'}, 'Undecided',
    'correct outcome string');
  is ($check->result->criteria_md5, '27c522a795e99e3aea57162541de75b1',
    'criteria_md5 attribute of the result object is set');
};

1;

use strict;
use warnings;
use Test::More tests => 12;
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
use st::api::lims;

use_ok('npg_qc::autoqc::checks::review');

my $dir = tempdir( CLEANUP => 1 );
my $test_data_dir = 't/data/autoqc/review';
my $conf_file_path = "$test_data_dir/product_release.yml";
my $rf_path = 't/data/autoqc/200117_A00715_0080_BHY7T3DSXX';

local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
    't/data/autoqc/review/samplesheet_27483.csv';

my $criteria_list = [
  '( bam_flagstats.target_proper_pair_mapped_reads / bam_flagstats.target_mapped_reads ) > 0.95',
  '( bcfstats.genotypes_nrd_dividend / bcfstats.genotypes_nrd_divisor ) < 0.02',
  'bam_flagstats.target_mapped_bases > 85_000_000_000',
  'bam_flagstats.target_percent_gt_coverage_threshold > 95',
  'verify_bam_id.freemix < 0.01'
];

subtest 'constructing object, deciding whether to run' => sub {
  plan tests => 33;

  my $check = npg_qc::autoqc::checks::review->new(
    conf_path => $test_data_dir,
    qc_in     => $test_data_dir,
    rpt_list  => '27483:1:2');
  isa_ok ($check, 'npg_qc::autoqc::checks::review');
  isa_ok ($check->result, 'npg_qc::autoqc::results::review');

  lives_ok { npg_qc::autoqc::checks::review->new(
    conf_path      => $test_data_dir,
    qc_in          => $test_data_dir,
    runfolder_path => $test_data_dir,
    rpt_list       => '27483:1:2;27483:2:2')
  } 'object created OK for components from the same run';
  throws_ok { npg_qc::autoqc::checks::review->new(
    conf_path      => $test_data_dir,
    qc_in          => $test_data_dir,
    runfolder_path => $test_data_dir,
    rpt_list       => '27483:1:2;27484:2:2')
  } qr/'runfolder_path' attribute should not be set/,
    'error creating an object for components from different runs';

  my $can_run;
  warnings_like { $can_run = $check->can_run }
    [qr/Study-specific RoboQC config not found/, qr/RoboQC configuration is absent/],
    'can_run is accompanied by warnings';
  ok (!$can_run, 'can_run returns false - no study config');
  like ($check->result->comments, qr/RoboQC configuration is absent/,
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
    [qr/Study-specific RoboQC config not found/, qr/Review check cannot be run/],
    'can_run is accompanied by warnings';
  ok (!$can_run, 'can_run returns false - no robo config');
  is ($check->result->comments, 'RoboQC configuration is absent',
    'reason logged');

  $check = npg_qc::autoqc::checks::review->new(
    conf_path => "$test_data_dir/not_hash",
    qc_in     => $test_data_dir,
    rpt_list  => '27483:1:2');
  throws_ok { $check->can_run }
    qr/Robo config should be a hash/,
    'error in can_run when robo config section is an array';
  throws_ok { $check->execute }
    qr/Robo config should be a hash/,
    'error in execute when robo config section is an array';

  $check = npg_qc::autoqc::checks::review->new(
    conf_path => "$test_data_dir/no_criteria_section",
    qc_in     => $test_data_dir,
    rpt_list  => '27483:1:2');
  throws_ok { $check->can_run }
    qr/criteria section is not present in/,
    'error in can_run when the criteria section is missing';
  throws_ok { $check->execute }
    qr/criteria section is not present in/,
    'error in execute when the criteria section is missing';
 
  $check = npg_qc::autoqc::checks::review->new(
    conf_path => "$test_data_dir/no_criteria",
    qc_in     => $test_data_dir,
    rpt_list  => '27483:1:2');
  throws_ok { $check->can_run }
    qr/should have both the applicability_criteria and acceptance_criteria key/,
    'error in can_run when acceptance criteria not defined';
  throws_ok { $check->execute }
    qr/should have both the applicability_criteria and acceptance_criteria key/,
    'error in execute when acceptance criteria not defined';
  
  $check = npg_qc::autoqc::checks::review->new(
    conf_path => "$test_data_dir/no_applicability_criteria",
    qc_in     => $test_data_dir,
    rpt_list  => '27483:1:2');
  throws_ok { $check->can_run }
    qr/should have both the applicability_criteria and acceptance_criteria key/,
    'error in can_run when applicability criteria not defined ' .
    'in one of multiple criterium objects';
  throws_ok { $check->execute }
    qr/should have both the applicability_criteria and acceptance_criteria key/,
    'error in execute when applicability criteria not defined ' .
    'in one of multiple criterium objects';

  $check = npg_qc::autoqc::checks::review->new(
    conf_path => "$test_data_dir/with_criteria",
    qc_in     => $test_data_dir,
    rpt_list  => '27483:1:2');
  ok ($check->can_run, 'can_run returns true');
  ok (!$check->result->comments, 'No comments logged');

  lives_ok {
    $check = npg_qc::autoqc::checks::review->new(
      conf_path => "$test_data_dir/with_criteria",
      qc_in     => $test_data_dir,
      rpt_list  => '27483:1:2',
      lims      => st::api::lims->new(rpt_list => '27483:1:2')
    )
  } 'can set lims via the constructor';
  ok ($check->can_run, 'can_run returns true');

  $check = npg_qc::autoqc::checks::review->new(
    conf_path => "$test_data_dir/no_applicability4single",
    qc_in     => $test_data_dir,
    rpt_list  => '27483:1:2');
  ok (!$check->can_run, 'can_run returns false');
  like ($check->result->comments,
    qr/applicability_criteria is not defined for one of RoboQC criteria/,
    'Error logged');

  $check = npg_qc::autoqc::checks::review->new(
    conf_path => "$test_data_dir/with_na_criteria",
    qc_in     => $test_data_dir,
    rpt_list  => '27483:1:2');
  ok (!$check->can_run, 'can_run returns false');
  is ($check->result->comments,
    'None of the RoboQC applicability criteria is satisfied',
    'Comment logged');

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
    't/data/autoqc/review/samplesheet_29524.csv';

  $check = npg_qc::autoqc::checks::review->new(
    conf_path => "$test_data_dir/no_known_applicability_type",
    qc_in     => $test_data_dir,
    rpt_list  => '27483:1:2');
  ok (!$check->can_run, 'can_run returns false');
  like ($check->result->comments,
    qr/None of known applicability type criteria is defined/,
    'Error logged');

  $check = npg_qc::autoqc::checks::review->new(
    conf_path => "$test_data_dir/lims_applicability_empty",
    qc_in     => $test_data_dir,
    rpt_list  => '27483:1:2');
  ok (!$check->can_run, 'can_run returns false');
  like ($check->result->comments,
    qr/lims type applicability criteria is not defined/,
    'Error logged');    
};

subtest 'caching appropriate criteria object' => sub {
  plan tests => 2;
  
  my $check = npg_qc::autoqc::checks::review->new(
    conf_path => "$test_data_dir/with_criteria",
    qc_in     => $test_data_dir,
    rpt_list  => '27483:1:2');
  my @list = grep { $_ !~ /genotype|freemix/} @{$criteria_list};
  is_deeply ($check->_criteria, {'and' => \@list},
    'criteria parsed correctly');

  $check = npg_qc::autoqc::checks::review->new(
    conf_path => "$test_data_dir/with_na_criteria",
    qc_in     => $test_data_dir,
    rpt_list  => '27483:1:2');
  is_deeply ($check->_criteria, {}, 'empty criteria hash')
};

subtest 'execute when no criteria apply' => sub {
  plan tests => 5;

  my $check = npg_qc::autoqc::checks::review->new(
    conf_path => "$test_data_dir/with_na_criteria",
    qc_in     => $test_data_dir,
    rpt_list  => '27483:1:2');
  lives_ok { $check->execute }
    'no error in execute when no criteria apply';
  my $result = $check->result;
  is ($result->comments,
    'None of the RoboQC applicability criteria is satisfied',
    'correct comment logged');
  is_deeply ($result->criteria, {}, 'empty criteria hash');
  is_deeply ($result->qc_outcome, {}, 'empty qc_outcome hash');
  is_deeply ($result->evaluation_results, {}, 'empty evaluation_results hash');
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

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
    't/data/autoqc/review/samplesheet_29524.csv';

  my $check = npg_qc::autoqc::checks::review->new(
    conf_path => $test_data_dir,
    qc_in     => $test_data_dir,
    rpt_list  => '27483:1:2');
  throws_ok { $check->_results } qr/$expected found none/, 'no results - error';

  # should have all three for the entiry and phix for bam_flagstats and qx_yield
  # and gradually add them to qc_in

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
    my $result = $check->_results->{$name}->[0];
    is (ref $result, 'npg_qc::autoqc::results::'. $name, 'corrrect type of object hashed');
    is ($result->composition->get_component(0)->tag_index, 2, 'tag index correct');
  }
  ok (!$check->_results->{bam_flagstats}->[0]->composition->get_component(0)->subset,
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
    my $result = $check->_results->{$name}->[0];
    like (ref $result, qr/\Anpg_qc::Schema::Result/, 'DBIx object retrieved');
    is ($result->class_name, $name, 'result type is correct');
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
  plan tests => 48;

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
    't/data/autoqc/review/samplesheet_29524.csv';
  my $rpt_list = '29524:1:2;29524:2:2;29524:3:2;29524:4:2';

  # NovaSeq run is required, MiSeq is given
  my $o = npg_qc::autoqc::checks::review->new(
    runfolder_path => 't/data/autoqc/191210_MS2_MiSeq_walk-up_246_A_MS8539685-050V2',
    conf_path => $test_data_dir,
    qc_in     => $dir,
    rpt_list  => $rpt_list
  );
  ok (!$o->can_run, 'the check cannot be run');
  is_deeply($o->_criteria, {}, 'no criteria to evaluate');
  lives_ok { $o->execute } 'execute method runs OK';
  is ($o->result->pass, undef, 'result pass attribute is unset');

  my @check_objects = ();

  push @check_objects, npg_qc::autoqc::checks::review->new(
    runfolder_path => $rf_path,
    conf_path => $test_data_dir,
    qc_in     => $dir,
    rpt_list  => $rpt_list);
  push @check_objects, npg_qc::autoqc::checks::review->new(
    conf_path => "$test_data_dir/mqc_type",
    qc_in     => $dir,
    rpt_list  => $rpt_list);
  push @check_objects, npg_qc::autoqc::checks::review->new(
    conf_path => "$test_data_dir/uqc_type",
    qc_in     => $dir,
    rpt_list  => $rpt_list);

  my $count = 0;
  foreach my $check (@check_objects) {
    lives_ok { $check->execute } 'execute method runs OK';
    is ($check->result->pass, 1, 'result pass attribute is set to 1');
    is ($check->result->library_type, 'HiSeqX PCR free',
      'result library_type attribute is set correctly');
    my %expected = map { $_ => 1 } @{$criteria_list};
    is_deeply ($check->result->evaluation_results(), \%expected,
      'evaluation results are saved');
    my $outcome = $check->result->qc_outcome;
    if ($count < 2) {
      is ($outcome->{'mqc_outcome'} , 'Accepted preliminary', 'correct outcome string');
    } elsif ($count == 2) {
      is ($outcome->{'uqc_outcome'} , 'Accepted', 'correct outcome string');
      ok ($outcome->{'rationale'} , 'rationale is set');
    }
    is ($outcome->{'username'}, 'robo_qc', 'correct process id');
    ok ($outcome->{'timestamp'}, 'timestamp saved');
    $count++;
  }

  # Undefined library type should not be a problem.
  my $lane_lims = (st::api::lims->new(id_run=> 29524)->children())[0];
  is ($lane_lims->library_type, undef, 'library type is undefined on lane level');
  my $check = npg_qc::autoqc::checks::review->new(
    conf_path => $test_data_dir,
    qc_in     => $test_data_dir,
    rpt_list  => $rpt_list,
    lims      => $lane_lims
  );
  lives_ok { $check->execute } 'execute method runs OK';
  is ($check->result->library_type, undef, 'library_type attribute is unset');

  $check = npg_qc::autoqc::checks::review->new(
    conf_path => "$test_data_dir/unknown_qc_type",
    qc_in     => $dir,
    rpt_list  => $rpt_list);
  throws_ok { $check->execute }
    qr/Invalid QC type \'someqc\' in a robo config/,
    'error if qc outcome type is not recignised';

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
      runfolder_path  => $rf_path,
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
    my $outcome = $check->result->qc_outcome;
    is ($outcome->{'mqc_outcome'} , 'Rejected final', 'correct outcome string');
    is ($outcome->{'username'}, 'robo_qc', 'correct process id');
    ok ($outcome->{'timestamp'}, 'timestamp saved');
  }  
};

subtest 'study-specific vs default robo definition' => sub {
  plan tests => 11;

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
    't/data/autoqc/review/samplesheet_29524.csv';
  my $rpt_list = '29524:1:2;29524:2:2;29524:3:2;29524:4:2';

  # robo config in the default section only
  my $check = npg_qc::autoqc::checks::review->new(
    runfolder_path => $rf_path,
    conf_path => "$test_data_dir/default_section",
    qc_in     => $test_data_dir,
    rpt_list  => $rpt_list
  );
  ok ($check->can_run, 'the check can run');
  lives_ok { $check->execute } 'execute method runs OK';
  is ($check->result->pass, 1, 'result pass attribute is set to 1');
  my %expected = map { $_ => 1 } @{$criteria_list};
  is_deeply ($check->result->evaluation_results(), \%expected,
    'evaluation results are saved');
  is ($check->result->qc_outcome->{'mqc_outcome'} , 'Accepted preliminary',
    'correct outcome string');

  # robo config in the default section and in the study section (empty)
  $check = npg_qc::autoqc::checks::review->new(
    runfolder_path => $rf_path,
    conf_path => "$test_data_dir/default_and_study_section",
    qc_in     => $test_data_dir,
    rpt_list  => $rpt_list
  );
  ok ($check->can_run, 'the check cannot run');

  # invalid robo config in the default section, valid in the study section
  $check = npg_qc::autoqc::checks::review->new(
    runfolder_path => $rf_path,
    conf_path => "$test_data_dir/wrong_default_and_study_section",
    qc_in     => $test_data_dir,
    rpt_list  => $rpt_list
  );
  ok ($check->can_run, 'the check can run');
  lives_ok { $check->execute } 'execute method runs OK';
  is ($check->result->pass, 1, 'result pass attribute is set to 1');
  is_deeply ($check->result->evaluation_results(), \%expected,
    'evaluation results are saved');
  is ($check->result->qc_outcome->{'mqc_outcome'} , 'Accepted preliminary',
    'correct outcome string');
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
    runfolder_path   => $rf_path,
    conf_path        => $test_data_dir,
    qc_in            => $dir,
    rpt_list         => $rpt_list,
    final_qc_outcome => 1);
  throws_ok { $check->execute }
    qr/Error evaluating expression .+ Use of uninitialized value/,
    'final outcome - not capturing the error';

  $check = npg_qc::autoqc::checks::review->new(
    runfolder_path   => $rf_path,
    conf_path        => $test_data_dir,
    qc_in            => $dir,
    rpt_list         => $rpt_list,
    final_qc_outcome => 0);
  lives_ok { $check->execute }
    'preliminary outcome - capturing the error';
  is ($check->result->pass, undef, 'pass value undefined');
  is_deeply ($check->result->qc_outcome, {},
    'QC outcome is not set');
  is ($check->result->criteria_md5, '27c522a795e99e3aea57162541de75b1',
    'criteria_md5 attribute of the result object is set');
};

subtest 'evaluating generic for artic results' => sub { 
  plan tests => 62;

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
    't/data/autoqc/generic/artic/samplesheet_35177.csv';
  my $gdir = join q[/], $test_data_dir, 'generic';
  my $rs_criterium2 = "generic:ncov2019_artic_nf.doc->{meta}->{'num_input_reads'} and (generic:ncov2019_artic_nf.doc->{'QC summary'}->{qc_pass} eq 'TRUE')";
  my $rs_criterium1 = "(generic:ncov2019_artic_nf.doc->{meta}->{'max_negative_control_filtered_read_count'} < 100) or ((generic:ncov2019_artic_nf.doc->{meta}->{'max_negative_control_filtered_read_count'} <= 1000) and (generic:ncov2019_artic_nf.doc->{'QC summary'}->{num_aligned_reads} > 100 * generic:ncov2019_artic_nf.doc->{meta}->{'max_negative_control_filtered_read_count'}))";

  # qc_in does not contain any autoqc results
  # real sample
  my $check = npg_qc::autoqc::checks::review->new(
    conf_path        => $gdir,
    qc_in            => $gdir,
    rpt_list         => '35177:2:1');
  is ($check->can_run, 1, 'check can run');
  lives_ok { $check->execute }
    'no autoqc results retrieved (none available) - normal exit';
  my $result = $check->result;
  isa_ok ($result, 'npg_qc::autoqc::results::review');
  like ($result->comments,
    qr/Not able to run evaluation: Expected results for generic, found none/,
    'error captured');
  is ($result->pass, undef, 'pass attribute is not set');
  is_deeply ($result->evaluation_results, {},
    'evauation results are an empty hash');
  is_deeply ($result->qc_outcome, {}, 'qc outcome is an empty hash');
  is_deeply ($result->criteria, {'and' => [$rs_criterium1,$rs_criterium2]},
    'criteria are set');

  # qc_in contains a generic result for the ampliconstats pipeline
  # real sample
  $check = npg_qc::autoqc::checks::review->new(
    conf_path        => $gdir,
    qc_in            => "$gdir/plex206",
    rpt_list         => '35177:2:206',
    final_qc_outcome => 1);
  is ($check->can_run, 1, 'check can run');
  throws_ok { $check->execute }
    qr/Not able to run evaluation: No autoqc generic result for ncov2019_artic_nf/,
    'message as an error';

  # qc_in contains two artic generic results for the same product
  $check = npg_qc::autoqc::checks::review->new(
    conf_path        => $gdir,
    qc_in            => "$gdir/plex1",
    rpt_list         => '35177:2:2',
    final_qc_outcome => 1);
  is ($check->can_run, 1, 'check can run');
  throws_ok { $check->execute }
    qr/Not able to run evaluation: Multiple autoqc results/,
    'message as an error';

  # qc_in contains other autoqc results for this entity, including
  # generic for ampliconstats
  # real sample
  $check = npg_qc::autoqc::checks::review->new(
    conf_path        => $gdir,
    qc_in            => "$gdir/plex1",
    rpt_list         => '35177:2:1');
  lives_ok { $check->execute } 'normal exit';
  $result = $check->result;
  isa_ok ($result, 'npg_qc::autoqc::results::review');
  is ($result->comments, undef, 'No comments');
  is ($result->pass, 1, 'pass attribute is set to 1');
  is_deeply ($result->evaluation_results,
    {$rs_criterium1 => 1, $rs_criterium2 => 1},
    'correct evauation results');
  is_deeply ($result->criteria, {'and' => [$rs_criterium1,$rs_criterium2]},
    'criteria are set');
  is ($result->criteria_md5, 'e83710ef788ab5e849c5be46d50f1254',
    'criteria md5 is set');
  my $outcome = $result->qc_outcome;
  is ($outcome->{username}, 'robo_qc', 'username is set in outcome');
  is ($outcome->{'mqc_outcome'} , 'Accepted preliminary',
    'correct outcome string');

  # zero number of input reads, no artic summary
  # real sample
  $check = npg_qc::autoqc::checks::review->new(
    conf_path        => $gdir,
    qc_in            => "$gdir/plex4",
    rpt_list         => '35177:2:4');
  lives_ok { $check->execute } 'normal exit';
  $result = $check->result;
  is ($result->comments, undef, 'No comments');
  is ($result->pass, 0, 'pass attribute is set to 0');
  is_deeply ($result->evaluation_results,
    {$rs_criterium1 => 1, $rs_criterium2 => 0},
    'correct evauation results');
  is ($result->qc_outcome->{'mqc_outcome'} , 'Rejected preliminary',
    'correct outcome string');

  # artic fail, generic ampliconstats is present
  # real sample
  $check = npg_qc::autoqc::checks::review->new(
    conf_path        => $gdir,
    qc_in            => "$gdir/plex97",
    rpt_list         => '35177:2:97');
  lives_ok { $check->execute } 'normal exit';
  $result = $check->result;
  is ($result->comments, undef, 'No comments');
  is ($result->pass, 0, 'pass attribute is set to 0');
  is_deeply ($result->evaluation_results,
    {$rs_criterium1 => 1, $rs_criterium2 => 0},
    'correct evauation results');
  is ($result->qc_outcome->{'mqc_outcome'} , 'Rejected preliminary',
    'correct outcome string');

  # non-zero number of input reads, no artic summary
  # real sample
  $check = npg_qc::autoqc::checks::review->new(
    conf_path        => $gdir,
    qc_in            => "$gdir/plex205",
    rpt_list         => '35177:2:205');
  lives_ok { $check->execute } 'normal exit';
  $result = $check->result;
  like ($result->comments,
    qr/Error evaluating expression .+ Use of uninitialized value/,
    'evaluation error logged');
  is ($result->pass, undef, 'pass attribute is not set');
  is_deeply ($result->evaluation_results, {}, 'no evauation results');
  is_deeply ($result->qc_outcome, {}, 'no qc outcome');
  
  # artic pass
  # positive control
  $check = npg_qc::autoqc::checks::review->new(
    conf_path        => $gdir,
    qc_in            => "$gdir/plex159",
    rpt_list         => '35177:2:159');
  lives_ok { $check->execute } 'normal exit';
  $result = $check->result;
  is ($result->comments, undef, 'No comments');
  is ($result->pass, 1, 'pass attribute is set to 1');
  is_deeply ($result->evaluation_results,
    {$rs_criterium1 => 1, $rs_criterium2 => 1},
    'correct evauation results');
  is ($result->qc_outcome->{'mqc_outcome'} , 'Accepted preliminary',
    'correct outcome string');

  my $nc_criterium = "( generic:ncov2019_artic_nf.doc->{meta}->{'num_input_reads'} == 0) or (generic:ncov2019_artic_nf.doc->{'QC summary'}->{num_aligned_reads} < 100)";
  # artic "num_aligned_reads":"33"
  # negative control
  $check = npg_qc::autoqc::checks::review->new(
    conf_path        => $gdir,
    qc_in            => "$gdir/plex137",
    rpt_list         => '35177:2:137');
  lives_ok { $check->execute } 'normal exit';
  $result = $check->result;
  is ($result->comments, undef, 'No comments');
  is ($result->pass, 1, 'pass attribute is set to 1');
  is_deeply ($result->criteria, {'and' => [$nc_criterium]},
    'criteria recorded correctly');
  is_deeply ($result->evaluation_results, {$nc_criterium => 1},
    'correct evauation results');
  is ($result->qc_outcome->{'mqc_outcome'} , 'Accepted preliminary',
    'correct outcome string');

  # artic "num_aligned_reads":"108"
  # negative control
  $check = npg_qc::autoqc::checks::review->new(
    conf_path        => $gdir,
    qc_in            => "$gdir/plex140",
    rpt_list         => '35177:2:140');
  lives_ok { $check->execute } 'normal exit';
  $result = $check->result;
  is ($result->comments, undef, 'No comments');
  is ($result->pass, 0, 'pass attribute is set to 0');
  is_deeply ($result->evaluation_results, {$nc_criterium => 0},
    'correct evauation results');
  is ($result->qc_outcome->{'mqc_outcome'} , 'Rejected preliminary',
    'correct outcome string');
 
  # no artic summary, "num_input_reads":"0"
  # negative control
  $check = npg_qc::autoqc::checks::review->new(
    conf_path        => $gdir,
    qc_in            => "$gdir/plex157",
    rpt_list         => '35177:2:157');
  lives_ok { $check->execute } 'normal exit';
  $result = $check->result;
  is ($result->comments, undef, 'No comments');
  is ($result->pass, 1, 'pass attribute is set to 1');
  is_deeply ($result->evaluation_results, {$nc_criterium => 1},
    'correct evauation results');
  is ($result->qc_outcome->{'mqc_outcome'} , 'Accepted preliminary',
    'correct outcome string');

  # no artic summary, "num_input_reads":"154"
  # negative control
  $check = npg_qc::autoqc::checks::review->new(
    conf_path        => $gdir,
    qc_in            => "$gdir/plex160",
    rpt_list         => '35177:2:160');
  lives_ok { $check->execute } 'normal exit';
  $result = $check->result;
  like ($result->comments,
    qr/Error evaluating expression .+ Use of uninitialized value/,
    'evaluation error logged');
  is ($result->pass, undef, 'pass attribute is not set');
  is_deeply ($result->evaluation_results, {}, 'no evauation results');
  is_deeply ($result->qc_outcome, {}, 'no qc outcome');
};

1;

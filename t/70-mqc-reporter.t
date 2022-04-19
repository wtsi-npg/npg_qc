use strict;
use warnings;
use Test::More tests => 5;
use Test::Exception;
use Test::Warn;
use Moose::Meta::Class;
use LWP::UserAgent;
use HTTP::Response;
use npg_testing::db;

local $ENV{NPG_WEBSERVICE_CACHE_DIR} = 't/data/reporter';

*LWP::UserAgent::request = *main::post_nowhere;
sub post_nowhere {
  return HTTP::Response->new(200);
}

use_ok('npg_qc::mqc::reporter');

my @pairs = ([6600,7], [6600,8], [5515,8]);

sub _create_schema {
  return Moose::Meta::Class->create_anon_class(
    roles => [qw/npg_testing::db/])->new_object()->create_test_db(
    q[npg_qc::Schema], q[t/data/reporter/npg_qc]);
}

sub _create_mlwh_schema {
  return Moose::Meta::Class->create_anon_class(
    roles => [qw/npg_testing::db/]
  )->new_object()->create_test_db(
    q[WTSI::DNAP::Warehouse::Schema], q[t/data/reporter/mlwarehouse]
  );
}

sub _get_data {
  my ($schema, $pair, $field) = @_;
  my $row = $schema->resultset('MqcOutcomeEnt')->search({id_run => $pair->[0], position => $pair->[1]})->next(); 
  if (!$row) {
    die 'cannot find db row';
  }
  return $row->$field;
}

my $npg_qc_schema = _create_schema();
my $mlwh_schema   = _create_mlwh_schema();
my $config_file   = q[t/data/.npg/npg_tracking-Schema];

subtest 'Initial' => sub {
  plan tests => 7;

  my $reporter = npg_qc::mqc::reporter->new(
     qc_schema   => $npg_qc_schema,
     mlwh_schema => $mlwh_schema,
     config_file => $config_file
  );
  isa_ok($reporter, 'npg_qc::mqc::reporter');

  is ( $reporter->lims_url, 'https://lims.sanger.ac.uk',
    'LIMS server url is correct');
  is ( $reporter->_url(33, 'pass'),
    'https://lims.sanger.ac.uk/npg_actions/assets/33/pass_qc_state',
    'url for sending');
 
  local $ENV{dev} = q[dev];
  $reporter = npg_qc::mqc::reporter->new(
     qc_schema   => $npg_qc_schema,
     mlwh_schema => $mlwh_schema,
     config_file => $config_file
  );
  is ( $reporter->_url(33, 'fail'),
    'https://lims-dev.sanger.ac.uk/npg_actions/assets/33/fail_qc_state',
    'url for sending');
  is ( $reporter->_payload(33, 'pass'),
    '<?xml version="1.0" encoding="UTF-8"?><qc_information>' .
    '<message>Asset 33  passed manual qc</message></qc_information>',
    'payload');
  is ( $reporter->_payload(33, 'fail'),
    '<?xml version="1.0" encoding="UTF-8"?><qc_information>' .
    '<message>Asset 33  failed manual qc</message></qc_information>',
    'payload');

  local $ENV{dev} = q[test];
  $reporter = npg_qc::mqc::reporter->new(
     qc_schema   => $npg_qc_schema,
     mlwh_schema => $mlwh_schema,
     config_file => $config_file
  );
  throws_ok { $reporter->lims_url } qr/LIMS server url is not defined/,
    'error when LIMS server url is not defined in teh config file';
};

subtest 'Succesfully posting report for 3 lanes' => sub {
  plan tests => 15;

  my $reporter = npg_qc::mqc::reporter->new(
    qc_schema   => $npg_qc_schema,
    mlwh_schema => $mlwh_schema,
    verbose     => 1,
    config_file => $config_file
  );

  foreach my $p (@pairs) {
    ok (!_get_data($npg_qc_schema, $p, 'reported'), 'reporting time is not set');
    ok (!_get_data($npg_qc_schema, $p, 'modified_by'), 'modified_by field is not set');
  }
  $reporter->load();
  foreach my $p (@pairs) {
    ok (_get_data($npg_qc_schema, $p, 'reported'), 'reporting time is set');
    is (_get_data($npg_qc_schema, $p, 'username'), 'cat', 'original username');
    ok (_get_data($npg_qc_schema, $p, 'modified_by'), 'modified_by field is set');
  }
};

subtest 'Not reporting, individual cases' => sub {
  plan tests => 15;

  my $reporter = npg_qc::mqc::reporter->new(
    qc_schema   => $npg_qc_schema,
    mlwh_schema => $mlwh_schema,
    verbose     => 1,
    config_file => $config_file
  );

  my $row = $npg_qc_schema->resultset('MqcOutcomeEnt')->search({id_run=>6600, position=>4})->next;
  ok($row, 'row for run 6600 position 4 exists - test prerequisite');
  ok(!$row->reported, 'row for run 6600 position 4 reported time not set - test prerequisite');
  $row->update({id_mqc_outcome => 3});
  $row = $npg_qc_schema->resultset('MqcOutcomeEnt')->search({id_run=>6600, position=>4})->next;
  ok ($row->has_final_outcome, 'outcome is final');
  $reporter->load();
  ok(!$row->reported, 'row for run 6600 position 4 reported time not set');

  $row->update({id_mqc_outcome => 1});
  $row = $npg_qc_schema->resultset('MqcOutcomeEnt')->search({id_run=>6600, position=>4})->next;
  ok (!$row->has_final_outcome, 'set outcome back to not final');

  $reporter = npg_qc::mqc::reporter->new(
    qc_schema   => $npg_qc_schema,
    mlwh_schema => $mlwh_schema,
    verbose     => 1,
    config_file => $config_file
  );

  $row = $npg_qc_schema->resultset('MqcOutcomeEnt')->search({id_run=>6600, position=>5})->next;
  ok($row, 'row for run 6600 position 5 exists - test prerequisite');
  ok(!$row->reported, 'row for run 6600 position 5 reported time not set - test prerequisite');
  $row->update({id_mqc_outcome => 3});
  $row = $npg_qc_schema->resultset('MqcOutcomeEnt')->search({id_run=>6600, position=>5})->next;
  ok ($row->has_final_outcome, 'outcome is final');
  $reporter->load() ;
  ok(!$row->reported, 'row for run 6600 position 5 reported time not set');
  $row->update({id_mqc_outcome => 1});
  $row = $npg_qc_schema->resultset('MqcOutcomeEnt')->search({id_run=>6600, position=>5})->next;
  ok (!$row->has_final_outcome, 'set outcome back to not final');

  $reporter = npg_qc::mqc::reporter->new(
    qc_schema   => $npg_qc_schema,
    mlwh_schema => $mlwh_schema,
    verbose     => 1,
    dry_run     => 1,
    config_file => $config_file
  );

  $row = $npg_qc_schema->resultset('MqcOutcomeEnt')->search({id_run=>6600, position=>6})->next;
  ok($row, 'row for run 6600 position 6 exists - test prerequisite');
  ok(!$row->reported, 'row for run 6600 position 6 reported time not set - test prerequisite');
  $row->update({id_mqc_outcome => 3});
  $row = $npg_qc_schema->resultset('MqcOutcomeEnt')->search({id_run=>6600, position=>6})->next;
  ok ($row->has_final_outcome, 'outcome is final');
  warnings_like { $reporter->load() } [
    qr/DRY RUN: .*: No lane id for run 6600 lane 6/,],
    'Warning about absence of lane id is logged';
  ok(!$row->reported, 'row for run 6600 position 6 reported time not set');
};

*LWP::UserAgent::request = *main::postfail_nowhere;
sub postfail_nowhere {
  my $r = HTTP::Response->new(500);
  $r->content('Some error in LIMs');
  return $r;
}

subtest 'Testing failing to report, getting 500 status from lims' => sub {
  plan tests => 7;

  my $npg_qc_schema = _create_schema();
  my $mlwh_schema   = _create_mlwh_schema();

  my $reporter = npg_qc::mqc::reporter->new(
    qc_schema   => $npg_qc_schema,
    mlwh_schema => $mlwh_schema,
    config_file => $config_file
  );
  lives_ok { $reporter->load() } 'no error';

  foreach my $p (@pairs) {
    ok (!_get_data($npg_qc_schema, $p, 'reported'), 'reporting time is not set');
    ok (!_get_data($npg_qc_schema, $p, 'modified_by'), 'modified_by field is not set');
  }
};

1;

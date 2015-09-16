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
  diag "Posting nowhere...\n";
  return HTTP::Response->new(200);
}

use_ok('npg_qc::mqc::reporter');

subtest 'Initial' => sub {
  plan tests => 2;
  my $reporter = npg_qc::mqc::reporter->new();
  isa_ok($reporter, 'npg_qc::mqc::reporter');
  like( $reporter->_create_url(33, 'pass'),
     qr/npg_actions\/assets\/33\/pass_qc_state/,
     'url for sending');
};

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

sub _create_tracking_schema {
  return Moose::Meta::Class->create_anon_class(
    roles => [qw/npg_testing::db/]
  )->new_object()->create_test_db(
    q[npg_tracking::Schema], q[t/data/reporter/npg_tracking]
  );
}

sub _get_data {
  my ($schema, $pair, $field) = @_;
  my $row = $schema->resultset('MqcOutcomeEnt')
                   ->search({id_run => $pair->[0], position => $pair->[1]})->next(); 
  if (!$row) {
    die 'cannot find db row';
  }
  return $row->$field;
}

my $npg_qc_schema       = _create_schema();
my $mlwh_schema         = _create_mlwh_schema();
my $npg_tracking_schema = _create_tracking_schema();
my $reporter = npg_qc::mqc::reporter->new(qc_schema => $npg_qc_schema, 
                                          mlwh_schema => $mlwh_schema, 
                                          tracking_schema => $npg_tracking_schema, 
                                          verbose => 1, 
                                          report_gclp => 1
);

subtest 'Succesful posting 3 lanes to report' => sub {
  plan tests => 6 + 9;
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
  plan tests => 7 + 5 + 5;
  my $row = $npg_qc_schema->resultset('MqcOutcomeEnt')->search({id_run=>6600, position=>4})->next;
  ok($row, 'row for run 6600 position 4 exists - test prerequisite');
  ok(!$row->reported, 'row for run 6600 position 4 reported time not set - test prerequisite');
  $row->update({id_mqc_outcome => 3});
  ok ($row->has_final_outcome, 'outcome is final');
  warnings_like { $reporter->load() } [
    qr/GCLP run, nothing to do for run 6600 position 4/,],
    'Message GCLP run logged';
  ok(!$row->reported, 'row for run 6600 position 4 reported time not set');
  ok($row->has_final_outcome, 'outcome is final');
  $row->update({id_mqc_outcome => 1});
  ok (!$row->has_final_outcome, 'set outcome back to not final');

  $row = $npg_qc_schema->resultset('MqcOutcomeEnt')->search({id_run=>6600, position=>5})->next;
  ok($row, 'row for run 6600 position 5 exists - test prerequisite');
  ok(!$row->reported, 'row for run 6600 position 5 reported time not set - test prerequisite');
  $row->update({id_mqc_outcome => 3});
  ok ($row->has_final_outcome, 'outcome is final');
  $reporter->load() ;
  ok(!$row->reported, 'row for run 6600 position 5 reported time not set');
  $row->update({id_mqc_outcome => 1});
  ok (!$row->has_final_outcome, 'set outcome back to not final');

  $row = $npg_qc_schema->resultset('MqcOutcomeEnt')->search({id_run=>6600, position=>6})->next;
  ok($row, 'row for run 6600 position 6 exists - test prerequisite');
  ok(!$row->reported, 'row for run 6600 position 6 reported time not set - test prerequisite');
  $row->update({id_mqc_outcome => 3});
  ok ($row->has_final_outcome, 'outcome is final');
  warnings_like { $reporter->load() } [
    qr/Error retrieving mlwarehouse data for run 6600 position 6/,],
    'Warning no mlwarehouse data found logged';
  ok(!$row->reported, 'row for run 6600 position 6 reported time not set');
};

#
# test failed postings
#

*LWP::UserAgent::request = *main::postfail_nowhere;
sub postfail_nowhere {
  diag "Posting nowhere...\n";
  my $r = HTTP::Response->new(500);
  $r->content('Some error in LIMs');
  return $r;
}

subtest 'Testing failing to report, getting 500 status from lims' => sub {
  plan tests => 6;
  my $npg_qc_schema       = _create_schema();
  my $mlwh_schema         = _create_mlwh_schema();
  my $npg_tracking_schema = _create_tracking_schema();

  my $reporter = npg_qc::mqc::reporter->new(qc_schema => $npg_qc_schema,
                                            mlwh_schema => $mlwh_schema,
                                            tracking_schema => $npg_tracking_schema);
  $reporter->load();
  $reporter->load();

  foreach my $p (@pairs) {
    ok (!_get_data($npg_qc_schema, $p, 'reported'), 'reporting time is not set');
    ok (!_get_data($npg_qc_schema, $p, 'modified_by'), 'modified_by field is not set');
  }
};

1;


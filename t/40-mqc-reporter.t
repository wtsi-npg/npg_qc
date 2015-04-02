use strict;
use warnings;
use Test::More tests => 47;
use Test::Exception;
use Test::Warn;
use Moose::Meta::Class;
use LWP::UserAgent;
use HTTP::Response;

local $ENV{NPG_WEBSERVICE_CACHE_DIR} = 't/data/reporter';

*LWP::UserAgent::request = *main::post_nowhere;
sub post_nowhere {
  diag "Posting nowhere...\n";
  return HTTP::Response->new(200);
}

use_ok('npg_qc::mqc::reporter');

{
  my $reporter = npg_qc::mqc::reporter->new();
  isa_ok($reporter, 'npg_qc::mqc::reporter');
  like( $reporter->_create_url(33, 'pass'),
     qr/npg_actions\/assets\/33\/pass_qc_state/,
     'url for sending');
}

my @pairs = ([6600,7], [6600,8], [5515,8]);

sub _create_schema {
  return Moose::Meta::Class->create_anon_class(
    roles => [qw/npg_testing::db/])->new_object()->create_test_db(
    q[npg_qc::Schema], q[t/data/reporter/npg_qc]);
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
my $reporter = npg_qc::mqc::reporter->new(qc_schema => $npg_qc_schema, verbose => 1);

#
# test successful posting
#

{
  foreach my $p (@pairs) {
    ok (!_get_data($npg_qc_schema, $p, 'reported'), 'reporting time is not set');
    ok (!_get_data($npg_qc_schema, $p, 'modified_by'), 'modified_by field is not set');
  }

  $reporter->load();
  is($reporter->nPass, 2, 'correct number of passes');
  is($reporter->nFail, 1, 'correct number of fails');
  is($reporter->nError, 0, 'correct number of errors');

  $reporter->load();
  is($reporter->nPass, 0, 'correct number of passes after loading');
  is($reporter->nFail, 0, 'correct number of fails after loading');
  is($reporter->nError, 0, 'correct number of errors after loading');

  foreach my $p (@pairs) {
    ok (_get_data($npg_qc_schema, $p, 'reported'), 'reporting time is set');
    is (_get_data($npg_qc_schema, $p, 'username'), 'cat', 'original username');
    ok (_get_data($npg_qc_schema, $p, 'modified_by'), 'modified_by field is set');
  }
}

{
  my $row = $npg_qc_schema->resultset('MqcOutcomeEnt')->search({id_run=>6600, position=>5})->next;
  ok($row, 'row for run 6600 position 5 exists - test prerequisite');
  ok(!$row->reported, 'row for run 6600 position 5 reported time not set - test prerequisite');
  $row->update({id_mqc_outcome => 3});
  ok ($row->has_final_outcome, 'outcome is final');
  warning_like { $reporter->load() } qr/Lane id is not set for run 6600 position 5/,
    'absence of lane id is logged';
  ok(!$row->reported, 'row for run 6600 position 5 reported time not set');
  $row->update({id_mqc_outcome => 1});
  ok (!$row->has_final_outcome, 'set outcome back to not final');
  
  $row = $npg_qc_schema->resultset('MqcOutcomeEnt')->search({id_run=>6600, position=>6})->next;
  ok($row, 'row for run 6600 position 6 exists - test prerequisite');
  ok(!$row->reported, 'row for run 6600 position 6 reported time not set - test prerequisite');
  $row->update({id_mqc_outcome => 3});
  ok ($row->has_final_outcome, 'outcome is final');
  warnings_like { $reporter->load() } [
    qr/Error retrieving lane id for run 6600 position 6/,
    qr/Lane id is not set for run 6600 position 6/],
    'error retrieving lane id is logged';
  ok(!$row->reported, 'row for run 6600 position 6 reported time not set');
}

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

{
  my $npg_qc_schema = _create_schema();

  my $reporter = npg_qc::mqc::reporter->new(qc_schema => $npg_qc_schema);
  $reporter->load();
  is($reporter->nPass, 2, 'correct number of passes');
  is($reporter->nFail, 1, 'correct number of fails');
  is($reporter->nError, 3, 'correct number of errors');

  $reporter->load();
  is($reporter->nPass, 2, 'correct number of passes after failing');
  is($reporter->nFail, 1, 'correct number of fails after failing');
  is($reporter->nError, 3, 'correct number of errors after failing');

  foreach my $p (@pairs) {
    ok (!_get_data($npg_qc_schema, $p, 'reported'), 'reporting time is not set');
    ok (!_get_data($npg_qc_schema, $p, 'modified_by'), 'modified_by field is not set');
  }
}

1;


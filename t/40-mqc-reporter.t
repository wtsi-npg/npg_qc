use strict;
use warnings;
use Test::More tests => 36;
use Test::Exception;
use Moose::Meta::Class;

local $ENV{NPG_WEBSERVICE_CACHE_DIR} = 't/data/reporter';

use_ok('npg_qc::mqc::reporter');

{
  my $reporter = npg_qc::mqc::reporter->new();
  isa_ok($reporter, 'npg_qc::mqc::reporter');
  like( $reporter->_create_url(33, 'pass'),
     qr/npg_actions\/assets\/33\/pass_qc_state/,
     'url for sending');
}

#
# subclass to always return success on posting to LIMS
#
package test_reporter_pass;
    use Moose;
    extends 'npg_qc::mqc::reporter';
    sub _report { return ''; }
    1;


#
# subclass to always return failure to post to LIMS
#
package test_reporter_fail;
    use Moose;
    extends 'npg_qc::mqc::reporter';
    sub _report { return 'Problem posting to SequenceScape'; }
    1;


package main;

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

#
# test successful posting
#
{
  my $npg_qc_schema = _create_schema();

  foreach my $p (@pairs) {
    ok (!_get_data($npg_qc_schema, $p, 'reported'), 'reporting time is not set');
    ok (!_get_data($npg_qc_schema, $p, 'modified_by'), 'modified_by field is not set');
  }

  my $reporter = test_reporter_pass->new(qc_schema => $npg_qc_schema, verbose => 1);
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

#
# test failed postings
#
{
  my $npg_qc_schema = _create_schema();

  my $reporter = test_reporter_fail->new(qc_schema => $npg_qc_schema);
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


#########
# Author:       js10 
# Created:      2015-02-13
#

use strict;
use warnings;
use Test::More tests => 14;
use Test::Exception;

BEGIN {
    $ENV{dev} = 'dev';
}

use_ok('npg_qc::mqc::reporter');

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

#
# Test that the actual class loads
#
{
  my $reporter = npg_qc::mqc::reporter->new();
  isa_ok($reporter, 'npg_qc::mqc::reporter');
}

#
# test successful posting
#
{
  my $npg_qc_schema = Moose::Meta::Class->create_anon_class(roles => [qw/npg_testing::db/])->new_object()->create_test_db(q[npg_qc::Schema], q[t/data/reporter/npg_qc]);
  my $reporter = test_reporter_pass->new(qc_schema => $npg_qc_schema, verbose => 1);
  $reporter->load();
  is($reporter->nPass, 2, 'correct number of passes');
  is($reporter->nFail, 1, 'correct number of fails');
  is($reporter->nError, 0, 'correct number of errors');

  $reporter->load();
  is($reporter->nPass, 0, 'correct number of passes after loading');
  is($reporter->nFail, 0, 'correct number of fails after loading');
  is($reporter->nError, 0, 'correct number of errors after loading');
}

#
# test failed postings
#
{
  my $npg_qc_schema = Moose::Meta::Class->create_anon_class(roles => [qw/npg_testing::db/])->new_object()->create_test_db(q[npg_qc::Schema], q[t/data/reporter/npg_qc]);
  my $reporter = test_reporter_fail->new(qc_schema => $npg_qc_schema);
  $reporter->load();
  is($reporter->nPass, 2, 'correct number of passes');
  is($reporter->nFail, 1, 'correct number of fails');
  is($reporter->nError, 3, 'correct number of errors');

  $reporter->load();
  is($reporter->nPass, 2, 'correct number of passes after failing');
  is($reporter->nFail, 1, 'correct number of fails after failing');
  is($reporter->nError, 3, 'correct number of errors after failing');
}

1;


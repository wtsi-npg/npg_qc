#########
# Author:       js10 
# Created:      2015-02-13
#

use strict;
use warnings;
use Test::More tests => 7;
use Test::Exception;

use_ok('npg_qc::qc2ss');

my $url = 'http://dev.psd.sanger.ac.uk:6600';

#sqlite db is used for testing
my $npg_qc_schema = Moose::Meta::Class->create_anon_class(roles => [qw/npg_testing::db/])->new_object()->create_test_db(q[npg_qc::Schema], q[t/data/qc2ss/npg_qc]);
my $npg_wh_schema = Moose::Meta::Class->create_anon_class(roles => [qw/npg_testing::db/])->new_object()->create_test_db(q[npg_warehouse::Schema], q[t/data/qc2ss/npg_wh]);

{
  my $qc2ss = npg_qc::qc2ss->new();
  isa_ok($qc2ss, 'npg_qc::qc2ss');
  is($qc2ss->lims_url, 'http://psd-support.internal.sanger.ac.uk:6600', 'Picked up correct URL');
}

{
  my $qc2ss = npg_qc::qc2ss->new( lims_url => $url, qc_schema => $npg_qc_schema, wh_schema => $npg_wh_schema);
  isa_ok($qc2ss, 'npg_qc::qc2ss');
  is($qc2ss->lims_url, $url, 'passed URL ok');
  $qc2ss->load();
  is($qc2ss->nPass, 2, 'correct number of passes');
  is($qc2ss->nFail, 1, 'correct number of fails');
}

1;

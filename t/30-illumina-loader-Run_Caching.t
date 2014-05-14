#########
# Author:        gq1
# Maintainer:    $Author$
# Created:       2008-09-30
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

use strict;
use warnings;
use Test::More  tests => 2;
#use Test::Exception;
use npg_testing::db;

use_ok('npg_qc::illumina::loader::Run_Caching');
$ENV{dev} = 'test';
my $schema = npg_testing::db::deploy_test_db(q[npg_qc::Schema],q[t/data/fixtures]);
{
  my $rc = npg_qc::illumina::loader::Run_Caching->new({schema => $schema});
  isa_ok($rc, 'npg_qc::illumina::loader::Run_Caching', '$rc model');
}

1;

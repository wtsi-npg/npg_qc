#########
# Author:        jmtc
#

use strict;
use warnings;
use Test::More tests => 3;
use Test::Exception;
use Test::Deep;
use JSON;
use Moose::Meta::Class;
use npg_testing::db;

use_ok('npg_qc::Schema::Result::MqcOutcomeEnt', "Model check");

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema]);

my $table = 'MqcOutcomeEnt';

#Test insert
#Test select
#Test update
#Test status workflow validation

1;
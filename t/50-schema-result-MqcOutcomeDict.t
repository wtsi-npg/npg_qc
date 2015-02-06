#########
# Author:        jmtc
#

use strict;
use warnings;
use Test::More tests => 1;
use Test::Exception;
use Test::Deep;
use JSON;
use Moose::Meta::Class;
use npg_testing::db;

#Test model mapping
use_ok('npg_qc::Schema::Result::MqcOutcomeDict', "Model check");

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema]);

my $table = 'MqcOutcomeDict';

1;
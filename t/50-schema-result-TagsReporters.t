use strict;
use warnings;
use Test::More tests => 2;
use Test::Exception;
use Moose::Meta::Class;
use npg_testing::db;

use_ok('npg_qc::Schema::Result::TagsReporters');

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema]);

lives_ok {$schema->resultset('TagsReporters')} 'result set retrieved';

1;



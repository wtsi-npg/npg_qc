#########
# Author:        mg8
#

use strict;
use warnings;
use Test::More tests => 3;
use Test::Exception;
use Moose::Meta::Class;

use_ok 'npg_qc::Schema';

my $schema_package = q[npg_qc::Schema];
my $schema;
lives_ok{ $schema = Moose::Meta::Class->create_anon_class(
            roles => [qw/npg_testing::db/])->new_object()
            ->create_test_db($schema_package) } 'test db created';
isa_ok($schema, $schema_package);

1;


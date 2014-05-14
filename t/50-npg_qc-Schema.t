#########
# Author:        mg8
# Last Modified: $Date: 2011-04-21 15:32:17 +0100 (Thu, 21 Apr 2011) $ $Author: mg8 $
# Id:            $Id: 20-model-NpgQcDB.t 13084 2011-04-21 14:32:17Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-catalyst-qc/branches/prerelease-12.0/npg_qc_viewer/t/20-model-NpgQcDB.t $
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


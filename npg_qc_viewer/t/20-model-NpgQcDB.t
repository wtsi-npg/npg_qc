use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;
use File::Temp qw(tempfile);
use t::util;

use_ok 'npg_qc_viewer::Model::NpgQcDB';

my $util = t::util->new();
my $schema_package = q[npg_qc::Schema];
my ($fh,$tmpdbfilename) = tempfile(UNLINK => 1);
my $schema;

lives_ok{ $schema = $util->create_test_db($schema_package, q[], $tmpdbfilename) }
                              'test db created';

my $m;
lives_ok {
  $m = npg_qc_viewer::Model::NpgQcDB->new( connect_info => {
                               dsn      => ('dbi:SQLite:'.$tmpdbfilename),
                               user     => q(),
                               password => q()
                                                               })
} 'create new model object';

isa_ok($m, 'npg_qc_viewer::Model::NpgQcDB');

1;


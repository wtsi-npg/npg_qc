use strict;
use warnings;
use Carp;
use Test::More tests => 7;
use Test::Exception;
use Test::Deep;
use File::Temp qw(tempfile);
use DateTime;

use t::util;

BEGIN { use_ok 'npg_qc_viewer::Model::WarehouseDB' }

my $util = t::util->new();
my $schema_package = q[npg_warehouse::Schema];
my $fixtures_path = q[t/data/fixtures/warehouse];
my ($fh,$tmpdbfilename) = tempfile(UNLINK => 1);
my $schema;

lives_ok{ $schema = $util->create_test_db($schema_package, $fixtures_path, $tmpdbfilename) }
                              'test db created and populated';

$schema->resultset('NpgPlexInformation')->search({id_run => 4950, 'tag_index' => {'!=' => 0,},})->update({sample_id=>118118,});

my $m;
lives_ok {
  $m = npg_qc_viewer::Model::WarehouseDB->new( connect_info => {
                               dsn      => ('dbi:SQLite:'.$tmpdbfilename),
                               user     => q(),
                               password => q()
                                                               })
} 'create new model object';

isa_ok($m, 'npg_qc_viewer::Model::WarehouseDB');

{
    my $rs=$m->resultset(q(NpgInformation));
    ok (defined $rs, "NpgInformation resultset");
    ok ($rs->count, "NpgInformation resultset has data");
    $rs = $rs->search({id_run=>3500});
    cmp_ok($rs->count,'==',8, "lane count for run 3500");
}

1;


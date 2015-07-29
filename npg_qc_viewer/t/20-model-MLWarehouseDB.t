use strict;
use warnings;
use Test::More tests => 5;
use Test::Exception;
use File::Temp qw(tempfile);

use t::util;

BEGIN { use_ok 'npg_qc_viewer::Model::MLWarehouseDB' }

my $util = t::util->new();
my $schema_package = q[WTSI::DNAP::Warehouse::Schema];
my $fixtures_path = q[t/data/fixtures/mlwarehouse];
my ($fh,$tmpdbfilename) = tempfile(UNLINK => 1);
my $schema;

lives_ok{ $schema = $util->create_test_db(
  $schema_package, $fixtures_path, $tmpdbfilename) }
  'test db created and populated';

my $m;
lives_ok {
  $m = npg_qc_viewer::Model::MLWarehouseDB->new( connect_info => {
                                                   dsn      => ('dbi:SQLite:'.$tmpdbfilename),
                                                   user     => q(),
                                                   password => q()
  })
} 'create new model object';

isa_ok($m, 'npg_qc_viewer::Model::MLWarehouseDB');

subtest 'Data in test data' => sub {
  plan tests => 3;
  my $rs=$m->resultset(q(IseqProductMetric));
  ok (defined $rs, "IseqProductMetric resultset");
  ok ($rs->count,  "IseqProductMetric resultset has data");
  $rs = $rs->search({id_run=>3500});
  cmp_ok($rs->count,'==',8, "lane count for run 3500");
};

1;

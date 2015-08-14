use strict;
use warnings;
use Test::More tests => 8;
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
  my $rs = $m->resultset(q(IseqProductMetric));
  ok (defined $rs, "IseqProductMetric resultset");
  ok ($rs->count,  "IseqProductMetric resultset has data");
  $rs = $rs->search({id_run=>3500});
  cmp_ok($rs->count,'==',8, "lane count for run 3500");
};

subtest 'Data for library' => sub {
  plan tests => 4;

  my $rs;
  $rs = $m->search_product_by_id_library_lims(q[NT15219S]);
  ok (defined $rs, q[Resultset for library by id_library_lims]);
  cmp_ok($rs->count, '>', 0, q[Found flowcell by id_library_lims]);
  my $flowcell = $rs->next->iseq_flowcell;
  cmp_ok($flowcell->id_library_lims, 'eq', q[NT15219S], q[Correct id library lims]);
  cmp_ok($flowcell->flowcell_barcode, 'eq', q[42DGLAAXX], q[Correct flowcell]);
};

subtest 'Data for pool' => sub {
  plan tests => 5;
  my $rs;
  $rs = $m->search_product_by_id_pool_lims(q[NT19992S]);
  ok (defined $rs, q[Resultset for library by id_pool_lims]);
  cmp_ok($rs->count, '>', 0, q[Found flowcell by id_pool_lims]);
  my $flowcell = $rs->next->iseq_flowcell;
  cmp_ok($flowcell->id_pool_lims,     'eq', q[NT19992S], q[Correct id pool lims]);
  cmp_ok($flowcell->id_library_lims,  'eq', q[NT19992S], q[Correct id library lims]);
  cmp_ok($flowcell->flowcell_barcode, 'eq', q[42DGLAAXX], q[Correct flowcell]);
};

subtest 'Data for sample' => sub {
  plan tests => 11;

  my $rs = $m->resultset(q[Sample]);
  ok (defined $rs, "Sample resultset");
  $rs = $rs->search({id_sample_lims => 2617});
  cmp_ok($rs->count, '==', 1, "Found sample by id_sample_lims");

  $rs = $m->search_product_by_sample_id(2617);
  cmp_ok($rs->count, '>', 0, "Found product when using method from Model");
  my $product = $rs->next;

  ok (defined $product->iseq_flowcell, "Product has iseq_flowcell.");
  ok (defined $product->iseq_flowcell->sample, "iseq_flowcell has sample.");
  my $sample = $product->iseq_flowcell->sample;
  cmp_ok($sample->id_sample_lims, '==', 2617, q[Correct id sample lims]);
  cmp_ok($sample->name, 'eq', q[random_sample_name], q[Correct sample name from name]);

  $rs = $m->search_product_by_sample_id(2617);
  cmp_ok($rs->count, '>', 0, "Found product when using method from Model");
  
  $rs = $m->search_sample_by_sample_id(2617);
  cmp_ok($rs->count, '>', 0, "Found product when using method from Model");
  $sample = $rs->next;
  cmp_ok($sample->id_sample_lims, '==', 2617, q[Correct id sample lims]);
  cmp_ok($sample->name, 'eq', q[random_sample_name], q[Correct sample name from name]);

};

1;

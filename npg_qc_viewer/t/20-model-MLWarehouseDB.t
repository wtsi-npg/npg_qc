use strict;
use warnings;
use Test::More tests => 6;
use Test::Exception;
use File::Temp qw(tempfile);
use npg_qc_viewer::TransferObjects::SampleFacade;

use t::util;

#  use Digest::SHA qw(sha256 sha256_hex sha256_base64);
#  my $data = "2";
#  my $digest = sha256($data); note $digest;
#  $digest = sha256_hex($data); note $digest;
#  $digest = sha256_base64($data); note $digest;

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

subtest 'Data for sample' => sub {
  plan tests => 9;
  my $rs;
  $rs = $m->resultset(q[Sample]);
  ok (defined $rs, "Sample resultset");
  $rs = $rs->search({id_sample_lims => 2617});
  cmp_ok($rs->count, '==', 1, "Found sample by id_sample_lims");

  $rs = $m->search_product_by_sample_id(2617);
  cmp_ok($rs->count, '>', 0, "Found product when using method from Model");
  my $product = $rs->next;

  ok (defined $product->iseq_flowcell, "Product has iseq_flowcell.");
  ok (defined $product->iseq_flowcell->sample, "iseq_flowcell has sample.");
  my $sample_facade = npg_qc_viewer::TransferObjects::SampleFacade->new({row => $product->iseq_flowcell->sample});
  cmp_ok($sample_facade->id_sample_lims, '==', 2617, q[Correct id sample lims]);
  cmp_ok($sample_facade->name, 'eq', q[NA20774-TOS], q[Correct sample name from name]);

  $rs = $m->search_product_by_sample_id(2617);
  cmp_ok($rs->count, '>', 0, "Found product when using method from Model");
  $product = $rs->next;
  my $sample = $product->iseq_flowcell->sample;
  $sample->name( undef );

  $sample_facade = npg_qc_viewer::TransferObjects::SampleFacade->new({row => $sample});
  cmp_ok($sample_facade->name, '==', 2617, q[Correct sample name from id sample lims]);
};

1;

use strict;
use warnings;
use Test::More tests => 6;
use Test::Exception;
use File::Temp qw(tempfile);
use npg_qc_viewer::TransferObjects::SampleFacade;

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

subtest 'Data for sample' => sub {
  plan tests => 7;
  my $rs;
  $rs = $m->resultset(q[Sample]);
  ok (defined $rs, "Sample resultset");
  $rs = $rs->search({id_sample_lims => 2617});
  cmp_ok($rs->count, '==', 1, "Found sample by id_sample_lims");

  $rs = $m->search_sample_lims_by_id(2617);
  cmp_ok($rs->count, '==', 1, "Found sample when using method from Model");
  my $sample = $rs->next;

  my $sample_facade = npg_qc_viewer::TransferObjects::SampleFacade->new({row => $sample});
  cmp_ok($sample_facade->id_sample_lims, '==', 2617, q[Correct id sample lims]);
  cmp_ok($sample_facade->name, 'eq', q[NA20774-TOS], q[Correct sample name from name]);

  $rs = $m->search_sample_lims_by_id(2617);
  $rs->update({'name' => undef});
  cmp_ok($rs->count, '==', 1, "Found sample when using method from Model");
  $sample = $rs->next;

  $sample_facade = npg_qc_viewer::TransferObjects::SampleFacade->new({row => $sample});
  cmp_ok($sample_facade->name, '==', 2617, q[Correct sample name from id sample lims]);
};

1;

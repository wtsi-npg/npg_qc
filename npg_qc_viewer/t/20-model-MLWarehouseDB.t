use strict;
use warnings;
use lib 't/lib';
use Test::More tests => 10;
use Test::Exception;
use File::Temp qw/tempfile/;
use List::MoreUtils qw/all/;

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
                                    dsn      => ('dbi:SQLite:' . $tmpdbfilename),
                                    user     => q(),
                                    password => q()
  })
} 'create new model object';

isa_ok($m, 'npg_qc_viewer::Model::MLWarehouseDB');

subtest 'Search product metrics' => sub {
  plan tests => 5;
  
  throws_ok { $m->search_product_metrics() }
    qr/Conditions were not provided for search/,
    'No argument - error';
  my $data = {position=>1,};
  throws_ok { $m->search_product_metrics($data) }
    qr/Run id needed/,
    'Run id is missing - error';

  $data->{'id_run'} = 4950;
  my @rows = $m->search_product_metrics($data)->all();
  ok ((all { $_->id_run == 4950} @rows), 'Run id is correct');
  ok ((all { $_->position == 1}  @rows), 'Position is correct');
  my @tags = map {$_->tag_index} @rows;
  is_deeply(\@tags, [(0 .. 24)], 'rows are sorted correctly');
};

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

subtest 'tags for a lane' => sub {
  plan tests => 6;

  my $id_run = 4950;
  my $rs = $m->resultset(q(IseqProductMetric))->search({id_run=>$id_run, position=>1});
  is($rs->count, 25, q[Correct number of elements found]);
  
  #Make tag_index 24 look as phix
  my $to_phix = $rs->search({tag_index=>24})->next;
  my $iseq_flowcell = $to_phix->iseq_flowcell; 
  $iseq_flowcell->update({'entity_type' => 'library_indexed_spike'});

  $rs->search({tag_index=>10})->next->iseq_flowcell->delete();
  throws_ok {$m->tags4lane( {id_run => $id_run, position => 1} )}
    qr/Flowcell data missing for run 4950 position 1 tag_index 10/,
    'error when no link to the flowcell';
  $rs->search({tag_index=>10})->next->delete();

  is_deeply( $m->tags4lane( {id_run => $id_run, position => 1} ),
    [(1 .. 9, 11 .. 23)], 'correct array of tags' );

  $id_run = 4025;
  $rs = $m->resultset(q(IseqProductMetric))->search({id_run=>$id_run, position=>1});
  is($rs->count, 1, q[Correct number of elements found]);
  my $hash = $m->tags4lane({id_run=>$id_run, position=>1});
  is_deeply ($m->tags4lane({id_run=>$id_run, position=>1}),
    [], 'No qc tags for a lane');

  my $non_existing_run = 4951; 
  throws_ok{ $m->tags4lane({id_run=>$non_existing_run, position=>1}) }
    qr/No NPG mlwarehouse data for run 4951 position 1/,
    'Error when data are unavailable';
};

1;

use strict;
use warnings;
use Test::More tests => 11;
use Test::Exception;

use t::util;

my $module = 'npg_qc_viewer::Util::TransferObjectFactory';
use_ok $module;

my $schema;
lives_ok { $schema = t::util->new()->test_env_setup()->{'mlwh'} }  'test db created and populated';
my $pmrs = $schema->resultset('IseqProductMetric');
my $epmrs = $schema->resultset('EseqProductMetric');

subtest 'create factory' => sub {
  plan tests => 8;

  my $row = $pmrs->search({})->next();
  my $f = $module->new(product_metrics_row => $row);
  isa_ok($f, 'npg_qc_viewer::Util::TransferObjectFactory');
  ok(!$f->is_plex, 'plex flag is false by default');
  ok(!$f->is_pool, 'pool flag is false by default');

  throws_ok {$module->new(product_metrics_row => $row, is_pool => 1, is_plex => 1)}
    qr/An entity cannot be both pool and plex/,
    'entity cannot be both a plex and a pool';

  $f = $module->new(product_metrics_row => $row, is_pool => 1);
  ok(!$f->is_plex, 'plex flag is false');
  ok($f->is_pool, 'pool flag is true');
  $f = $module->new(product_metrics_row => $row, is_plex => 1);
  ok($f->is_plex, 'plex flag is true');
  ok(!$f->is_pool, 'pool flag is false');
};

subtest 'create Illumina lane object' => sub {
  plan tests => 17;

  my $row = $pmrs->search({id_run => 3055, position => 1})->next();
  my $f  = $module->new(product_metrics_row => $row, is_plex => 0);
  my $to = $f->create_object();
  isa_ok($to, 'npg_qc_viewer::Util::TransferObject');
  is ($to->id_run, 3055, 'run id');
  is ($to->position, 1, 'position');
  is ($to->num_cycles, 76, 'number of cycles');
  is ($to->time_comp, '2009-06-01T19:26:39', 'run complete time');
  is ($to->tag_index, undef, 'tag index');
  is ($to->tag_sequence, undef, 'tag sequence');
  is ($to->instance_qc_able, 1, 'qc_able');
  is ($to->rnd, 0, 'not r&d');
  is ($to->is_control, 0, 'not a control');
  is ($to->entity_id_lims, '1422510', 'entity_id_lims');
  ok (!$to->is_pool, 'not a pool');
  is ($to->study_name, 'random_study_name', 'study name');
  is ($to->sample_id, 2617, 'sample id');
  is ($to->sample_name, 'random_sample_name', 'sample name');
  is ($to->sample_supplier_name, undef, 'sample supplier name');
  is ($to->id_library_lims, 'NT13483B', 'id_library_lims');
};

subtest 'create Illumina control lane object' => sub {
  plan tests => 7;

  my $row = $pmrs->search({id_run => 4950, position => 4})->next();
  my $f  = $module->new(product_metrics_row => $row, is_plex => 0);
  my $to = $f->create_object();
  isa_ok($to, 'npg_qc_viewer::Util::TransferObject');
  is ($to->id_run, 4950, 'run id');
  is ($to->position, 4, 'position');
  is ($to->tag_index, undef, 'tag index');
  is ($to->tag_sequence, undef, 'tag sequence');
  is ($to->instance_qc_able, 0, 'qc_able');
  is ($to->is_control, 1, 'is a control');
};

subtest 'create Illumina plex object' => sub {
  plan tests => 16;

  my $row = $pmrs->search({id_run => 4950, position => 8, tag_index => 5})->next();
  my $f  = $module->new(product_metrics_row => $row, is_plex => 1);
  my $to = $f->create_object();
  is ($to->id_run, 4950, 'run id');
  is ($to->position, 8, 'position');
  is ($to->num_cycles, 224, 'number of cycles');
  is ($to->time_comp, '2010-07-13T13:06:44', 'run complete time');
  is ($to->tag_index, 5, 'tag index');
  is ($to->tag_sequence, 'ACAGTGGT', 'tag sequence');
  is ($to->instance_qc_able, 1, 'qc_able');
  is ($to->rnd, 0, 'not r&d');
  is ($to->is_control, 0, 'not a control');
  is ($to->entity_id_lims, '400472', 'entity_id_lims');
  ok (!$to->is_pool, 'not a pool');
  is ($to->study_name, 'random_study_name', 'study name');
  is ($to->sample_id, 33402, 'sample id');
  is ($to->sample_name, 'random_sample_name', 'sample name');
  is ($to->sample_supplier_name, undef, 'sample supplier name');
  is ($to->id_library_lims, 'NT206930M', 'id_library_lims');
};

subtest 'create Illumina pool object' => sub {
  plan tests => 17;

  my $row = $pmrs->search({id_run => 4950, position => 8, tag_index => 5})->next();
  my $f  = $module->new(product_metrics_row => $row, is_plex => 0, is_pool => 1);
  my $to = $f->create_object();
  is ($to->id_run, 4950, 'run id');
  is ($to->position, 8, 'position');
  is ($to->num_cycles, 224, 'number of cycles');
  is ($to->time_comp, '2010-07-13T13:06:44', 'run complete time');
  is ($to->tag_index, undef, 'tag index');
  is ($to->tag_sequence, undef, 'tag sequence');
  is ($to->instance_qc_able, 1, 'qc_able');
  is ($to->rnd, 0, 'not r&d');
  is ($to->is_control, 0, 'not a control');
  is ($to->entity_id_lims, '400472', 'entity_id_lims');
  ok ($to->is_pool, 'is a pool');
  is ($to->study_name, undef, 'study name');
  is ($to->sample_id, undef, 'sample id');
  is ($to->sample_name, undef, 'sample name');
  is ($to->sample_supplier_name, undef, 'sample supplier name');
  is ($to->id_library_lims, 'NT206937T', 'id_library_lims');

  $f  = $module->new(product_metrics_row => $row,
                     is_plex             => 0,
                     is_pool             => 1,
                     not_qcable          => 1);
  $to = $f->create_object();
  is ($to->instance_qc_able, 0, 'not qc_able');  
};

subtest 'create Illumina object not represented in LIMs' => sub {
  plan tests => 17;

  my $row = $pmrs->search({id_run => 4950, position => 8, tag_index => 0})->next();
  my $f  = $module->new(product_metrics_row => $row, is_plex => 1);
  my $to = $f->create_object();
  is ($to->id_run, 4950, 'run id');
  is ($to->position, 8, 'position');
  is ($to->num_cycles, 224, 'number of cycles');
  is ($to->time_comp, '2010-07-13T13:06:44', 'run complete time');
  is ($to->tag_index, 0, 'tag index');
  is ($to->tag_sequence, undef, 'tag sequence');
  is ($to->instance_qc_able, 0, 'qc_able');
  is ($to->rnd, 0, 'not r&d');
  is ($to->is_control, 0, 'not a control');
  is ($to->entity_id_lims, undef, 'entity_id_lims');
  ok (!$to->is_pool, 'not a pool');
  is ($to->study_name, undef, 'study name');
  is ($to->sample_id, undef, 'sample id');
  is ($to->sample_name, undef, 'sample name');
  is ($to->sample_supplier_name, undef, 'sample supplier name');
  is ($to->id_library_lims, undef, 'id_library_lims');

  $row = $pmrs->search({id_run => 4950, position => 8})->next();
  $f  = $module->new(product_metrics_row => $row, is_pool => 1);
  $to = $f->create_object();
  ok ($to->is_pool, 'is a pool');
};

subtest 'create Elembio plex object' => sub {
  plan tests => 16;

  my $row = $epmrs->search({id_run => 50932, lane => 1, tag_index => 2})->next();
  my $f  = $module->new(product_metrics_row => $row, is_plex => 1);
  my $to = $f->create_object();
  is ($to->id_run, 50932, 'run id');
  is ($to->position, 1, 'position');
  is ($to->num_cycles, 140, 'number of cycles');
  is ($to->time_comp, '2025-08-21T00:40:07', 'run complete time');
  is ($to->tag_index, 2, 'tag index');
  is ($to->tag_sequence, 'AAGATTGGAT-AGCGGGATTT', 'tag sequence');
  is ($to->instance_qc_able, 1, 'qc_able');
  is ($to->rnd, 0, 'not r&d');
  is ($to->is_control, 0, 'not a control');
  is ($to->entity_id_lims, '75736474', 'entity_id_lims');
  ok (!$to->is_pool, 'not a pool');
  is ($to->study_name, 'Biodiversity Cell Atlas (BCA)', 'study name');
  is ($to->sample_id, '10220688', 'sample id');
  is ($to->sample_name, 'rBCAxxxyyy', 'sample name');
  is ($to->sample_supplier_name, 'sgp276', 'sample supplier name');
  is ($to->id_library_lims, 'SQPP-85776-J:A1', 'id_library_lims');
};

subtest 'create Elembio pool object' => sub {
  plan tests => 17;

  my $row = $epmrs->search({id_run => 50932, lane => 1, tag_index => 2})->next();
  my $f  = $module->new(product_metrics_row => $row, is_plex => 0, is_pool => 1);
  my $to = $f->create_object();
  is ($to->id_run, 50932, 'run id');
  is ($to->position, 1, 'position');
  is ($to->num_cycles, 140, 'number of cycles');
  is ($to->time_comp, '2025-08-21T00:40:07', 'run complete time');
  is ($to->tag_index, undef, 'tag index');
  is ($to->tag_sequence, undef, 'tag sequence');
  is ($to->instance_qc_able, 1, 'qc_able');
  is ($to->rnd, 0, 'not r&d');
  is ($to->is_control, 0, 'not a control');
  is ($to->entity_id_lims, '75736474', 'entity_id_lims');
  ok ($to->is_pool, 'is a pool');
  is ($to->study_name, undef, 'study name');
  is ($to->sample_id, undef, 'sample id');
  is ($to->sample_name, undef, 'sample name');
  is ($to->sample_supplier_name, undef, 'sample supplier name');
  is ($to->id_library_lims, 'NT1861579Q', 'id_library_lims');

  $f  = $module->new(product_metrics_row => $row,
                     is_plex             => 0,
                     is_pool             => 1,
                     not_qcable          => 1);
  $to = $f->create_object();
  is ($to->instance_qc_able, 0, 'not qc_able');  
};

subtest 'create Elembio object not represented in LIMs' => sub {
  plan tests => 26;

  my $row = $epmrs->search({id_run => 50932, lane => 1, tag_index => 0})->next();
  my $f  = $module->new(product_metrics_row => $row, is_plex => 1);
  my $to = $f->create_object();
  is ($to->id_run, 50932, 'run id');
  is ($to->position, 1, 'position');
  is ($to->num_cycles, 140, 'number of cycles');
  is ($to->time_comp, '2025-08-21T00:40:07', 'run complete time');
  is ($to->tag_index, 0, 'tag index');
  is ($to->tag_sequence, undef, 'tag sequence');
  is ($to->instance_qc_able, 0, 'not qc_able');
  is ($to->rnd, 0, 'not r&d');
  is ($to->is_control, 0, 'not a control');
  is ($to->entity_id_lims, undef, 'entity_id_lims');
  ok (!$to->is_pool, 'not a pool');
  is ($to->study_name, undef, 'study name');
  is ($to->sample_id, undef, 'sample id');
  is ($to->sample_name, undef, 'sample name');
  is ($to->sample_supplier_name, undef, 'sample supplier name');
  is ($to->id_library_lims, undef, 'id_library_lims');

  # Currently controls are not represented in LIMS.
  $row = $epmrs->search({id_run => 50932, lane => 1, tag_index => 1})->next();
  $f  = $module->new(product_metrics_row => $row, is_plex => 1);
  $to = $f->create_object();
  is ($to->tag_index, 1, 'tag index');
  is ($to->tag_sequence, 'ATGTCGCTAG-CTAGCTCGTA', 'tag sequence');
  is ($to->instance_qc_able, 0, 'not qc_able');
  is ($to->is_control, 1, 'is a control');
  is ($to->entity_id_lims, undef, 'entity_id_lims');
  is ($to->study_name, undef, 'study name');
  is ($to->sample_id, undef, 'sample id');
  is ($to->sample_name, 'PhiX_Third', 'elembio sample name');
  is ($to->sample_supplier_name, undef, 'sample supplier name');
  is ($to->id_library_lims, undef, 'id_library_lims');
};

1;

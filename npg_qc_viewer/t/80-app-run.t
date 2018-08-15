use strict;
use warnings;
use lib 't/lib';
use Test::More tests => 36;
use Test::Exception;
use File::Temp qw/tempdir/;
use File::Path qw/make_path/;

use npg_tracking::glossary::composition::factory;
use npg_tracking::glossary::composition::component::illumina;
use t::util;

BEGIN {
  local $ENV{'HOME'} = 't/data';
}

my $util = t::util->new();
$util->modify_logged_user_method();

local $ENV{CATALYST_CONFIG} = $util->config_path;
local $ENV{TEST_DIR}        = $util->staging_path;

my $schemas;
lives_ok { $schemas = $util->test_env_setup()}  'test db created and populated';
use_ok 'Test::WWW::Mechanize::Catalyst', 'npg_qc_viewer';
my $mech = Test::WWW::Mechanize::Catalyst->new;

# This prefixes impact the javascript part of the application. Update as 
# necessary.
my $title_prefix = qq[NPG SeqQC v${npg_qc_viewer::VERSION}: ];
my $row_id_prefix = q[rpt_key:];

my $qc_schema = $schemas->{'qc'};
my $tmrs = $qc_schema->resultset('TagMetrics');
my $f = npg_tracking::glossary::composition::factory->new();
$f->add_component(npg_tracking::glossary::composition::component::illumina->new(
  id_run => 4950, position => 1));
my $fk_id = $tmrs->find_or_create_seq_composition($f->create_composition())
                 ->id_seq_composition();
$tmrs->create({
  id_run             => 4950,
  position           =>1,
  id_seq_composition => $fk_id,
  path               => 'some path',
  reads_pf_count     =>'{"2":89,"1":299626,"0":349419}'
});

{
  my $base = tempdir(UNLINK => 1);
  my $path = $base . q[/archive];
  my $run_folder = q[150621_MS6_04099_A_MS2023387-050V2];
  make_path $path.q[/].$run_folder;
  
  my $npg   = $schemas->{'npg'};
  
  foreach my $id_run ( 4950 ) {
    my $values = { id_run               => $id_run,
                   batch_id             => 4178,
                   folder_name          => $run_folder,
                   folder_path_glob     => $path, 
                   id_instrument        => 30,
                   id_instrument_format => 4,
                   is_paired            => 1,
                   priority             => 1,
                   team                 => '"joint"' 
    };
    
    my $row = $npg->resultset("Run")->create($values); #Insert new entity
    $row->set_tag(7, 'staging');
  }
}

{
  my $url = q[http://localhost/checks/runs/4025];
  $mech->get_ok($url);
  $mech->title_is($title_prefix . q[Results for run 4025 (run 4025 status: qc complete)]);
  $mech->content_contains('Back to Run 4025');
  $mech->content_contains("<br />152</div>");  # num cycles
  $mech->content_contains('NT28560W'); #library name
  $mech->content_contains('run 4025 lane 1'); #side menu link
  $mech->content_contains('Run annotations');
  $mech->content_contains('Lane annotations');
  $mech->content_contains('NPG QC');
  $mech->content_contains('20,442,728'); #for total qxYield
  $mech->content_contains($row_id_prefix . q[4025:1]); #Relevant for qcoutcomes js

  $schemas->{npg}->resultset('RunStatus')->search({id_run => 4025, iscurrent => 1},)
                                         ->update({ id_user => 64, id_run_status_dict => 26, });
  $mech->get_ok($url);
  $mech->title_is($title_prefix . q[Results for run 4025 (run 4025 status: qc in progress, taken by mg8)]);
}

subtest 'Tests for page features affecting JavaScript' => sub {
  plan tests => 6;

  #These tests are linked with the javascript part of the application
  #which uses the title of the page to check if manual qc GUI should
  #be shown. 
  my $url = q[http://localhost/checks/runs/10107];
  my $f = npg_tracking::glossary::composition::factory->new();
  $f->add_component(npg_tracking::glossary::composition::component::illumina->new(
    id_run => 10107, position => 1));
  my $fkid = $tmrs->find_or_create_seq_composition($f->create_composition())
                  ->id_seq_composition();
  $tmrs->create({
    id_run             => 10107,
    position           => 1,
    id_seq_composition => $fkid,
    path               => 'some path',
    reads_pf_count     => '{"2":1,"1":2000,"0":3000}'
  });
  $mech->get_ok($url);
  $mech->title_is($title_prefix . q[Results for run 10107 (run 10107 status: qc in progress, taken by melanie)]);

  $schemas->{npg}->resultset('RunStatus')->search({id_run => 10107, iscurrent => 1},)
                 ->update({ id_user => 50, id_run_status_dict => 25, });

  $mech->get_ok($url);
  $mech->title_is($title_prefix . q[Results for run 10107 (run 10107 status: qc on hold, taken by melanie)]);

  $mech->content_contains(q[<table id="results_summary"]);
  $mech->content_like(qr/.+<a [^>]+ id=\'summary_to_csv\' [^>]+>[\w\s]+<\/a>.+/mxi,
    'summary table id - affects export to CSV');
};

subtest 'extra column markup - affects export to CSV' => sub {
  # This tests check for functionaly which affects javascript part of
  # application. Update accordingly.
  plan tests => 23;
  my $id_run    = 4025;
  my $position  = 1;
  my $tag_index = 1;

  my $f = npg_tracking::glossary::composition::factory->new();
  $f->add_component(npg_tracking::glossary::composition::component::illumina->new(
    id_run => $id_run, position => $position, tag_index => $tag_index));
  my $fkid = $tmrs->find_or_create_seq_composition($f->create_composition())
                  ->id_seq_composition();

  my $gcbiasrs = $qc_schema->resultset('GcBias');
  $gcbiasrs->create({
    id_run => $id_run,
    position => $position,
    tag_index => $tag_index,
    id_seq_composition => $fkid,
    path => '/something',
  });

  my @urls = (
    qq(http://localhost/checks/runs?run=$id_run&lane=$position&show=plexes),
    qq(http://localhost/checks/runs?run=$id_run&lane=$position&show=all),
  );
  foreach my $url (@urls) {
    $mech->get_ok($url);
    $mech->content_contains(q[<table id="results_summary"]);
    $mech->content_contains(q[data-extra_cols_]);
    $mech->content_contains(q[data-extra_cols_sample_name='Sanger Sample ID']);
    $mech->content_contains(q[data-extra_cols_sample_name='']);
  }

  my $id_sample_tmp          = 1000;
  my $id_flowcell_tmp        = 100000;
  my $id_iseq_pr_metrics_tmp = 10000;
  my $id_sample_lims         = 'abc';
  my $sample_name            = q[AAABBBCCCDDD];

  my $mlwh = $schemas->{mlwh};
  my $sample_values = {
    id_sample_tmp    => $id_sample_tmp,
    uuid_sample_lims => '4a1e3190-b9c2-11df-9e66-00144f01a414',
    id_lims          => 'SQSCP',
    last_updated     => '2012-08-03 10:07:02',
    recorded_at      => '2012-08-03 10:07:02',
    created          => '2012-08-03 10:07:02',
    id_sample_lims   => $id_sample_lims,
    name             => $sample_name,
  };
  my $row_sample = $mlwh->resultset("Sample")->create($sample_values);

  my $flowcell_values = {
    id_iseq_flowcell_tmp => $id_flowcell_tmp,
    id_sample_tmp        => $id_sample_tmp,
    last_updated         => '2012-08-03 10:07:02',
    recorded_at          => '2012-08-03 10:07:02',
    id_lims              => 'SQSCP',
    id_flowcell_lims     => 100001,
    position             => $position,
    tag_index            => $tag_index,
    entity_type          => 'library_indexed',
    entity_id_lims       => '7583508',
    is_spiked            => 0,
    id_pool_lims         => 'NT329502B',

  };
  my $row_flowcell = $mlwh->resultset("IseqFlowcell")->create($flowcell_values);

  my $product_values = {
    id_run                 => $id_run,
    position               => $position,
    tag_index              => $tag_index,
    id_iseq_flowcell_tmp   => $id_flowcell_tmp,
    id_iseq_pr_metrics_tmp => $id_iseq_pr_metrics_tmp
  };
  my $row_product = $mlwh->resultset("IseqProductMetric")->create($product_values);

  foreach my $url (@urls) {
    $mech->get_ok($url);
    $mech->content_contains(q[<table id="results_summary"]);
    $mech->content_contains(q[data-extra_cols_]);
    $mech->content_contains(q[data-extra_cols_sample_name='Sanger Sample ID']);
    $mech->content_contains(qq[data-extra_cols_sample_name='$sample_name']);
  }

  my $url_sample = qq[http://localhost/checks/samples/$id_sample_lims];
  $mech->get_ok($url_sample);
  $mech->content_contains(qq[Sample '$sample_name']);
  $mech->content_contains(qq[data-extra_cols_sample_name='$sample_name']);

  $row_product->delete();
  $row_flowcell->delete();
  $row_sample->delete();
  $gcbiasrs->search({
    id_run    => $id_run,
    position  => $position,
    tag_index => $tag_index
  })->delete();
};

subtest 'Run 4025 Lane 1' => sub {
  plan tests => 9;
  my $url = q[http://localhost/checks/runs?run=4025&lane=1];
  $mech->get_ok($url);
  $mech->title_is($title_prefix . q[Results (lanes) for runs 4025 lanes 1 (run 4025 status: qc in progress, taken by mg8)]);
  $mech->content_contains("<br />152</div>");  # num cycles
  $mech->content_contains('NT28560W'); #library name
  $mech->content_lacks('NA18623pd2a 1');
  $mech->content_contains('run 4025 lane 1'); #side menu link
  $mech->content_lacks('run 4025 lane 2'); #side menu link
  $mech->content_lacks('Run annotations');
  $mech->content_lacks('Lane annotations');
};

subtest 'Library links for run + lane SE' => sub {
  plan tests => 5;

  my $where = { 'iseq_product_metrics.id_run' => 4025, 'me.id_pool_lims' => 'NT28560W'};
  my $rs = $schemas->{'mlwh'}->resultset('IseqFlowcell')
                             ->search($where, { join => 'iseq_product_metrics', })
                             ->update({'legacy_library_id' => 111111,});

  my $url = q[http://localhost/checks/runs?run=4025&lane=1];
  $mech->get_ok($url);
  $mech->content_contains("<br />152</div>");  # num cycles
  $mech->content_contains('NT28560W'); #library name
  $mech->content_contains('assets/111111'); #SE link
  $mech->content_contains('libraries?id=NT28560W'); #seqqc link for library
};

subtest 'Page title for run + show all' =>  sub {
  plan tests => 2;
  my $url = q[http://localhost/checks/runs?run=4025&show=all];
  $mech->get_ok($url);
  $mech->title_is($title_prefix . q[Results (all) for runs 4025 (run 4025 status: qc in progress, taken by mg8)]);
};

subtest 'mqc span' => sub {
  plan tests => 14;

  $schemas->{npg}->resultset('RunStatus')
                 ->search({id_run => 4950, iscurrent => 1},)
                 ->update({ id_user => 64, id_run_status_dict => 26, });

  my $url= q[http://localhost/checks/runs?run=4950&lane=1&show=all&db_lookup=1];
  $mech->get_ok($url);
  $mech->content_contains(q[rpt_key:4950:1:0]);
  $mech->content_lacks(q[<span class='lane_mqc_control'></span></td><td class="tag_info"><a href="#4950:1:0">]);
  $mech->content_contains(q[rpt_key:4950:1:1]);
  $mech->content_contains(q[<span class='lane_mqc_control'></span></td><td class="tag_info"><a href="#4950:1:1">]);
  $mech->content_contains(q[rpt_key:4950:1:5]);
  $mech->content_contains(q[<span class='lane_mqc_control'></span></td><td class="tag_info"><a href="#4950:1:5">]);

  my $where_lane = { 'iseq_product_metrics.id_run'   => 4950,
                     'iseq_product_metrics.position' => 1 };

  my $rs = $schemas->{'mlwh'}->resultset('IseqFlowcell')
                          ->search($where_lane, { join => 'iseq_product_metrics', });
  while ( my $flowcell = $rs->next ) {
    if($flowcell->tag_index && $flowcell->tag_index == 5) {
      $flowcell->update({ 'entity_type' => 'library_indexed_spike' });
    }
  }

  $mech->get_ok($url);
  $mech->content_contains(q[rpt_key:4950:1:0]);
  $mech->content_lacks(q[<span class='lane_mqc_control'></span></td><td class="tag_info"><a href="#4950:1:0">]);
  $mech->content_contains(q[rpt_key:4950:1:1]);
  $mech->content_contains(q[<span class='lane_mqc_control'></span></td><td class="tag_info"><a href="#4950:1:1">]);
  $mech->content_contains(q[rpt_key:4950:1:5]);
  $mech->content_lacks(q[<span class='lane_mqc_control'></span></td><td class="tag_info"><a href="#4950:1:5">]);

  ######
  #Reset test data
  $rs = $schemas->{'mlwh'}->resultset('IseqFlowcell')
                          ->search($where_lane, { join => 'iseq_product_metrics', });
  while ( my $flowcell = $rs->next ) {
    $flowcell->update({ 'entity_type' => 'library_indexed' });
  }
};

{
  my $url = q[http://localhost/checks/runs?run=4025&show=plexes];
  $mech->get_ok($url);
  $mech->title_is($title_prefix . q[Results (plexes) for runs 4025]);
  $mech->content_lacks("<br />152</div>");  # num cycles
  $mech->content_lacks('NT28560W'); #library name

  $url = q[http://localhost/checks/runs?run=4950&lane=1&show=lanes];
  $mech->get_ok($url);
  $mech->title_is($title_prefix . q[Results (lanes) for runs 4950 lanes 1]);
  $mech->content_contains(224);  # num cycles
  $mech->content_contains('NT207849B'); #library name
  $mech->content_contains('run 4950 lane 1'); #side menu link
  $mech->content_lacks('run 4950 lane 2'); #side menu link
}

subtest 'Test for run + lane + plexes' => sub {
  plan tests => 9;
  my $url = q[http://localhost/checks/runs?run=4950&lane=1&show=plexes];
  $mech->get_ok($url);
  $mech->title_is($title_prefix . q[Results (plexes) for runs 4950 lanes 1]);
  $mech->content_contains(224);  # num cycles
  $mech->content_contains('Help'); #side menu link
  $mech->content_contains('NT207825Q'); #library name for tag 1
  $mech->content_contains('ATCACGTT'); #tag sequence
  $mech->content_contains('Tag'); #column name
  $mech->content_lacks('NT207849B'); #library name for lane
  $mech->content_unlike(qr/run\ 4950\ lane\ 1$/);
};

subtest 'Test for run + lane + show all' => sub {
  plan tests => 14;
  my $url = q[http://localhost/checks/runs?run=4950&lane=1&show=all];
  $mech->get_ok($url);
  $mech->title_is($title_prefix . q[Results (all) for runs 4950 lanes 1]);
  $mech->content_contains('Page Top');
  $mech->content_contains('Back to Run 4950');
  $mech->content_contains(224);  # num cycles
  $mech->content_contains('NT207849B'); #library name for lane
  $mech->content_contains('ATCACGTT'); #tag sequence
  $mech->content_contains('Tag'); #column name
  $mech->content_contains('NT207825Q'); #library name for tag 1
  $mech->content_contains($row_id_prefix . q[4950:1"]); #Relevant for qcoutcomes js
  $mech->content_contains($row_id_prefix . q[4950:1:1"]); #Relevant for qcoutcomes js

  foreach my $menu_item (('Page Top','20','0')) {
    $mech->follow_link_ok({text => $menu_item}, qq[follow '$menu_item' menu item]);
  }
};

subtest 'Tag metrics as first check in summary table' =>  sub {
  plan tests => 27;

  my $qxrs = $qc_schema->resultset(q[QXYield]);

  for my $i (6 .. 8) {
    my $f = npg_tracking::glossary::composition::factory->new();
    $f->add_component(npg_tracking::glossary::composition::component::illumina->new(
      id_run => 4025, position => $i));
    my $fkid = $tmrs->find_or_create_seq_composition($f->create_composition())
                    ->id_seq_composition();
    $tmrs->create({
      id_run             => 4025,
      position           => $i,
      id_seq_composition => $fkid,
      tag_index          => -1,
      path=>'some path',
      metrics_file=>'some other path',
      barcode_tag_name=>'BC',
      tags=>'{"3":"TAGGCATGCTAAGCCT","1":"TAAGGCGAGCGTAAGA","4":"CTCTCTACGCGTAAGA","0":"NNNNNNNNNNNNNNNN","2":"TAGGCATGAAGGAGTA","5":"TAAGGCGAGTAAGGAG"}',
      reads_count=>'{"3":"169","1":"89436","4":"88734","0":"218304","2":"184300","5":"135309"}',
      reads_pf_count=>'{"3":"169","1":"89436","4":"88734","0":"218304","2":"184300","5":"135309"}',
      perfect_matches_count=>'{"3":"120","1":"84364","4":"83074","0":"0","2":"173449","5":"128520"}',
      perfect_matches_pf_count=>'{"3":"120","1":"84364","4":"83074","0":"0","2":"173449","5":"128520"}',
      one_mismatch_matches_count=>'{"3":"49","1":"5072","4":"5660","0":"0","2":"10851","5":"6789"}',
      one_mismatch_matches_pf_count=>'{"3":"49","1":"5072","4":"5660","0":"0","2":"10851","5":"6789"}',
      matches_percent=>'{"3":"0.000012","1":"0.006554","4":"0.006503","0":"0.015999","2":"0.013507","5":"0.009916"}',
      matches_pf_percent=>'{"3":"0.000012","1":"0.006554","4":"0.006503","0":"0.015999","2":"0.013507","5":"0.009916"}',
      max_mismatches_param=>'1',
      min_mismatch_delta_param=>'1',
      max_no_calls_param=>'2',
      pass=>'1',
      info=>'{"Check":"npg_qc::autoqc::checks::tag_metrics","Check_version":"59.6"}',
    });
   
    for my $j (-1 .. 5) {
      $f = npg_tracking::glossary::composition::factory->new();
      $f->add_component(npg_tracking::glossary::composition::component::illumina->new(
        id_run => 4025, position => $i, tag_index => ($j == -1 ? undef : $j)));
      my $qfkid = $qxrs->find_or_create_seq_composition($f->create_composition())
                       ->id_seq_composition();
      my $obj = $qxrs->update_or_new({
        id_run             => 4025,
        position           => $i,
        tag_index          => $j,
        id_seq_composition => $qfkid,
        path               => q[some path],
        filename1          => q[some filename],
        filename2          => q[other filename],
        threshold_quality  => '20',
        yield1             => '1952450',
        yield2             => '1891079',
        comments           => 'Unrecognised instrument model',
        info => '{"Check":"npg_qc::autoqc::checks::qX_yield","Check_version":"59.6"}'
      });
      if (!$obj->in_storage) {
        $obj->insert;
      }
    } 
  }

  my $url = q[http://localhost/checks/runs?db_lookup=1&run=4025&lane=8&show=all];
  $mech->get_ok($url);
  $mech->title_is($title_prefix . q[Results (all) for runs 4025 lanes 8 (run 4025 status: qc in progress, taken by mg8)]);
  $mech->content_contains(q[<th rowspan="2">Tag</th><th>tag<br />metrics<br/>], q[Tag metrics next to tag column]); 
  $mech->content_contains(q[<td class="tag_info"><a href="#4025:8"></a></td> <td class="check_summary passed"><a href="#tmc_4025:8">69.52</a><br />], 
                          q[Original content for tag metrics for lane level]);
  $mech->content_contains(q[<a href="#4025:8:1">1</a></td> <td class="check_summary outcome_unknown">0.7], q[Tag metrics for tag 1]);
  $mech->content_contains(q[<a href="#4025:8:2">2</a></td> <td class="check_summary outcome_unknown">1.4], q[Tag metrics for tag 2]);
  $mech->content_contains(q[<a href="#4025:8:3">3</a></td> <td class="check_summary failed">0.0], q[Tag metrics for tag 3]);
  $mech->content_contains(q[<a href="#4025:8:4">4</a></td> <td class="check_summary outcome_unknown">0.7], q[Tag metrics for tag 4]);
  $mech->content_contains(q[<a href="#4025:8:0">0</a></td> <td class="check_summary outcome_unknown">1.6], q[Tag metrics for tag 0]);
  
  $url = q[http://localhost/checks/runs?db_lookup=1&run=4025&lane=6&lane=7&lane=8&show=all];
  $mech->get_ok($url);
  $mech->title_is($title_prefix . q[Results (all) for runs 4025 lanes 6 7 8 (run 4025 status: qc in progress, taken by mg8)]);
  $mech->content_contains(q[<th rowspan="2">Tag</th><th>tag<br />metrics<br/>], q[Tag metrics next to tag column]);
  for my $i (6 .. 8) {
    $mech->content_contains(qq[<td class="tag_info"><a href="#4025:$i"></a></td> <td class="check_summary passed"><a href="#tmc_4025:$i">69.52</a><br />], 
                            q[Original content for tag metrics for lane level]);
    $mech->content_contains(qq[<th rowspan="2">Tag</th><th>tag<br />metrics<br/>], q[Tag metrics next to tag column]);
    $mech->content_contains(qq[<a href="#4025:$i:1">1</a></td> <td class="check_summary outcome_unknown">0.7], qq[Tag metrics for lane $i tag 1]);
    $mech->content_contains(qq[<a href="#4025:$i:3">3</a></td> <td class="check_summary failed">0.0], qq[Tag metrics for lane $i tag 3]);
    $mech->content_contains(qq[<a href="#4025:$i:0">0</a></td> <td class="check_summary outcome_unknown">1.6], qq[Tag metrics for lane $i tag 0]);
  }
};

subtest 'R&D visual cue and links to LIMS' => sub {
  plan tests => 4;

  my $where = { 'iseq_product_metrics.id_run' => 4025, };
  $schemas->{'mlwh'}->resultset('IseqFlowcell')
          ->search($where, { join => 'iseq_product_metrics', })
          ->update({'is_r_and_d' => 1,});
  $where->{'me.position'} = 1;
  $schemas->{'mlwh'}->resultset('IseqFlowcell')
                    ->search($where, { join => 'iseq_product_metrics', })
                    ->update({'id_lims' => 'C_GCLP'});

  my $url = q[http://localhost/checks/runs/4025];
  $mech->get_ok($url);
  $mech->content_contains('NT28560W'); #library name
  $mech->content_contains('<a href="">random_sample_name</a></span><span class="watermark">R&amp;D</span>'); #GCLP (no link), R&D watermark
  $mech->content_contains('9286">random_sample_name</a></span><span class="watermark">R&amp;D</span>'); #link to a sample an d R&D watermark
};

subtest 'Displaying user info' => sub {
  plan tests => 8;

  my $url = q[http://localhost/checks/runs/4025];
  $mech->get_ok($url);
  $mech->content_contains('Not logged in');
  $mech->content_lacks('(mqc)');
 
  $mech->get_ok($url . '?user=tiger&password=secret');
  $mech->content_contains('Logged in as tiger');
  $mech->content_lacks('(mqc)');

  $mech->get_ok($url . '?user=cat&password=secret');
  $mech->content_contains('Logged in as cat (mqc)');
};

1;



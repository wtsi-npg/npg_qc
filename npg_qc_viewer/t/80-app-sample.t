use strict;
use warnings;
use Test::More tests => 5;
use Test::Exception;
use Test::Warn;
use List::MoreUtils qw ( each_array );

use Test::WWW::Mechanize::Catalyst;

use t::util;

my $schemas;
my $util = t::util->new();
local $ENV{'CATALYST_CONFIG'} = $util->config_path;
local $ENV{'TEST_DIR'}        = $util->staging_path;
local $ENV{'HOME'}            = 't/data';

my $mech;

subtest 'Initial' => sub {
  plan tests => 2;
  lives_ok { $schemas = $util->test_env_setup()}  'test db created and populated';
  use_ok 'Test::WWW::Mechanize::Catalyst', 'npg_qc_viewer';
  $mech = Test::WWW::Mechanize::Catalyst->new;
};

subtest 'Sample without link to flowcell' => sub {
  plan tests => 3;
  my $mlwh   = $schemas->{mlwh};
  
  my $id_sample_lims = 2109;
  my $values = { id_sample_tmp    => 5064,
                 uuid_sample_lims => '4a1e3190-b9c2-11df-9e66-00144f01a414',
                 id_lims          => 'SQSCP',
                 last_updated     => '2012-08-03 10:07:02',
                 recorded_at      => '2012-08-03 10:07:02',
                 created          => '2012-08-03 10:07:02',
                 id_sample_lims   => $id_sample_lims,
                 name             => q[random_sample_name],
  };
  my $row = $mlwh->resultset("Sample")->create($values);
  
  my $url = qq[http://localhost/checks/samples/$id_sample_lims];
  warnings_like{$mech->get_ok($url)} [ qr/Use of uninitialized value \$id in exists/,], 
                                       'Expected warning for runfolder location';
  $mech->title_is(qq[NPG SeqQC v${npg_qc_viewer::VERSION}: Sample 'random_sample_name']);
};

subtest 'Sample 9272' => sub {
  plan tests => 4;
  my $sample_id = 9272; #id_run 4025
  my $version = $npg_qc_viewer::VERSION;
  my $url = qq[http://localhost/checks/samples/$sample_id];
  warnings_like{$mech->get_ok($url)} [ qr/Use of uninitialized value \$id in exists/, ], 
                                       'Expected warnings';
  $mech->title_is(qq[NPG SeqQC v${version}: Sample 'random_sample_name']);
  $mech->content_contains(q[NT28560W &lt;&lt; random_sample_name &lt;&lt; random_study_name]);
};

subtest 'Test for summary table id for sample - affects export to CSV.' => sub {
  plan tests => 4;
  my $sample_id = 9272; #id_run 4025
  my $url = qq[http://localhost/checks/samples/$sample_id];
  warnings_like{$mech->get_ok($url)} [ qr/Use of uninitialized value \$id in exists/, ], 
                                       'Expected warnings';
  $mech->content_contains(q[<table id="results_summary"]);
  $mech->content_contains(q[<a href="#" id="summary_to_csv" title="Download the summary table as a CSV file">Summary to CSV file</a>]);
};

subtest 'Full provenance in title for different samples of same run' => sub {
  plan tests => 8;
  
  my $version = $npg_qc_viewer::VERSION;
  
  my @samples = qw( 9272 9286 );
  
  my @sample_names = qw( sample1 sample2 );
  
  my $it = each_array ( @samples, @sample_names );
  
  while ( my ($sample_id, $sample_name) = $it->() ) {
    my $where = { 'me.id_sample_lims' => $sample_id, };
    my $rs = $schemas->{'mlwh'}->resultset('Sample')->search($where, { join => {'iseq_flowcells' => 'iseq_product_metrics'}, });
    
    while (my $sample = $rs->next ) {
      $sample->update({'name' => $sample_name,});
    }
  }

  my @provenances = ( q[NT28560W &lt;&lt; sample1 &lt;&lt; random_study_name], 
                      q[NT28561A &lt;&lt; sample2 &lt;&lt; random_study_name],
                    );

  $it = each_array( @samples, @sample_names, @provenances);
  while ( my ($sample_id, $sample_name, $provenance) = $it->() ) {
    my $url = qq[http://localhost/checks/samples/$sample_id];
    warnings_like{$mech->get_ok($url)} [ qr/Use of uninitialized value \$id in exists/,], 
                                         'Expected warning for uninitialized id';
    $mech->title_is(qq[NPG SeqQC v${version}: Sample '$sample_name']);
    $mech->content_contains($provenance);
  }
};

1;


use strict;
use warnings;
use lib 't/lib';
use Test::More tests => 9;
use Test::Exception;
use Test::WWW::Mechanize::Catalyst;

use t::util;

my $util = t::util->new();
$util->modify_logged_user_method();

local $ENV{'CATALYST_CONFIG'} = $util->config_path;
local $ENV{'HOME'}            = 't/data';

my $mech;

{
  lives_ok { $util->test_env_setup()}  'test db created and populated';
  use_ok 'Test::WWW::Mechanize::Catalyst', 'npg_qc_viewer';
  $mech = Test::WWW::Mechanize::Catalyst->new;
}

subtest 'Basic test for ibraries' => sub {
  plan tests => 5;
  my $lib_name = 'NT28560W';
  my $url = q[http://localhost/checks/libraries?id=] . $lib_name;
  $mech->get_ok($url);
  $mech->title_is(qq[NPG SeqQC v${npg_qc_viewer::VERSION}: Libraries: 'NT28560W']);
  $mech->content_contains($lib_name);
  my $id_run = '4025';
  $mech->content_contains($id_run);
  my $sample_name = 'random_sample_name';
  $mech->content_contains($sample_name);
};

subtest 'Sample links for library SE' => sub {
  plan tests => 2;

  my $url = q[http://localhost/checks/libraries?id=NT28560W];
  $mech->get_ok($url);
  $mech->content_contains(q[samples/9272]); #Link to sample in SE
};

{
  #no id_run for this library
  # the strings are in the title, test the whole contents when done
  my $lib_name = 'NT207825Q';
  my $url = q[http://localhost/checks/libraries?id=] . $lib_name;
  $mech->get_ok($url);
  $mech->title_is(qq[NPG SeqQC v${npg_qc_viewer::VERSION}: Libraries: '$lib_name']);
  $mech->content_contains($lib_name);
  my $id_run = q[4950];
  $mech->content_contains($id_run);
}

subtest 'Test for summary table id for library - affects export to CSV.' => sub {
  plan tests => 3;

  my $lib_name = 'NT207825Q';
  my $url = q[http://localhost/checks/libraries?id=] . $lib_name;
  $mech->get_ok($url);
  $mech->content_contains(q[<table id="results_summary"]);
  $mech->content_like(qr/.+<a [^>]+ id=\'summary_to_csv\' [^>]+>[\w\s]+<\/a>.+/mxi);
};

1;


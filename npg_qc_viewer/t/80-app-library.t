use strict;
use warnings;
use Test::More tests => 13;
use Test::Exception;
use Test::WWW::Mechanize::Catalyst;
use Test::Warn;

use t::util;

my $util = t::util->new();
local $ENV{CATALYST_CONFIG} = $util->config_path;
local $ENV{TEST_DIR}        = $util->staging_path;

my $mech;

{
  lives_ok { $util->test_env_setup()}  'test db created and populated';
  use_ok 'Test::WWW::Mechanize::Catalyst', 'npg_qc_viewer';
  $mech = Test::WWW::Mechanize::Catalyst->new;
}

{
  my $lib_name = 'NT28560W';
  my $url = q[http://localhost/checks/libraries?id=] . $lib_name;
  warning_like{$mech->get_ok($url)} qr/Use of uninitialized value \$id in exists/, 
                                      'Expected warning for runfolder location';
  $mech->title_is(qq[NPG SeqQC v${npg_qc_viewer::VERSION}: Libraries: 'NT28560W']);
  $mech->content_contains($lib_name);

  my $id_run = '4025';
  $mech->content_contains($id_run);
  my $sample_name = 'random_sample_name';
  $mech->content_contains($sample_name);
}

{
  #no id_run for this library
  # the strings are in the title, test the whole contents when done
  my $lib_name = 'NT207825Q';
  my $url = q[http://localhost/checks/libraries?id=] . $lib_name;
  warnings_like{$mech->get_ok($url)} [qr/Failed to get runfolder location/, 
                                      qr/Use of uninitialized value \$id in exists/], 
                                      'Expected warning for runfolder location';
  $mech->title_is(qq[NPG SeqQC v${npg_qc_viewer::VERSION}: Libraries: '$lib_name']);
  $mech->content_contains($lib_name);
  my $id_run = q[4950];
  $mech->content_contains($id_run);
}



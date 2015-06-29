use strict;
use warnings;
use Test::More tests => 12;
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
  my $lib_name = 'NA18545pd2a 1';
  my $url = q[http://localhost/checks/libraries?name=] . $lib_name;
  warnings_like{$mech->get_ok($url)} [qr/No paths to run folder found/, 
                                      qr/Use of uninitialized value \$id in exists/], 
                                      'Expected warning for runfolder location';
  $mech->title_is(q[Libraries: 'NA18545pd2a 1']);
  $mech->content_contains($lib_name);
  my $sample_name = 'NA18545pd2a';
  $mech->content_contains($sample_name);
}


{
  #no id_run for this library
  # the strings are in the title, test the whole contents when done
  my $lib_name = 'AC0001C 1';
  my $url = q[http://localhost/checks/libraries?name=] . $lib_name;
  warnings_like{$mech->get_ok($url)} [qr/No paths to run folder found/, 
                                      qr/Use of uninitialized value \$id in exists/], 
                                      'Expected warning for runfolder location';
  $mech->title_is(q[Libraries: 'AC0001C 1']);
  $mech->content_contains(q[AC0001C]);
  $mech->content_contains($lib_name);
}



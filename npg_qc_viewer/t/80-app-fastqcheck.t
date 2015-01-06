use strict;
use warnings;
use Test::More tests => 8;
use Test::Exception;
use Cwd;
use File::Spec;
use Test::WWW::Mechanize::Catalyst;

use t::util;

my $util = t::util->new();
local $ENV{CATALYST_CONFIG} = $util->config_path;
local $ENV{TEST_DIR}        = $util->staging_path;

my $mech;
my $fname = '4360_1_1.fastqcheck';
my $path = File::Spec->catfile(cwd, 't', 'data', 'sources4visuals', $fname);
my $schemas;

{
  lives_ok { $schemas = $util->test_env_setup() }  'test db created and populated';
  use_ok 'Test::WWW::Mechanize::Catalyst', 'npg_qc_viewer';
  $mech = Test::WWW::Mechanize::Catalyst->new;
}

{
  $mech->get_ok(q[http://localhost/visuals/fastqcheck_legend]);
}

{
  my $url = q[http://localhost/visuals/fastqcheck?path=] . $path;
  $mech->get_ok($url);
  $url = q[http://localhost/visuals/fastqcheck?path=] . $path . q[&read=forward];
  $mech->get_ok($url);
  $url = q[http://localhost/visuals/fastqcheck?path=] . $path . q[&read=forward&db_lookup=0];
  $mech->get_ok($url);
}

{
  open my $fh, '<', $path;
  local $/ = undef;
  my $text = <$fh>;
  close $fh;

  my $rs = $schemas->{qc}->resultset('Fastqcheck');
  $rs->create({section => 'forward', id_run => 4360, position => 1, file_name => $fname, file_content => $text,});
  is ($rs->search({file_name => $fname})->count, 1, 'one fastqcheck file saved');
  my $url = q[http://localhost/visuals/fastqcheck?path=] . $fname . q[&read=forward&db_lookup=1];
  $mech->get_ok($url);
}

1;


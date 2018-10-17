use strict;
use warnings;
use lib 't/lib';
use Test::More tests => 7;
use Test::Exception;
use Cwd;
use File::Spec;
use Test::WWW::Mechanize::Catalyst;
use Perl6::Slurp;

use t::util;

BEGIN {
  local $ENV{'HOME'} = 't/data';
}

my $util = t::util->new();
local $ENV{CATALYST_CONFIG} = $util->config_path;

my $fname = '4360_1_1.fastqcheck';
my $path = File::Spec->catfile(cwd, 't', 'data', 'qualmap');

my $schemas;
lives_ok { $schemas = $util->test_env_setup() }  'test db created and populated';
use_ok 'Test::WWW::Mechanize::Catalyst', 'npg_qc_viewer';
my $mech = Test::WWW::Mechanize::Catalyst->new;

{
  $mech->get_ok(q[http://localhost/visuals/qualmap_legend]);
}

{
  my $url = q[http://localhost/visuals/qualmap?paths_list=] . $path . q[&read=forward&rpt_list=4360:1];
  $mech->get_ok($url);
  $url = q[http://localhost/visuals/qualmap?paths_list=] . $path . q[&read=forward&db_lookup=0&rpt_list=4360:1];
  $mech->get_ok($url);
}

{
  my $text = slurp $path . '/' . $fname;
  my $rs = $schemas->{'qc'}->resultset('Fastqcheck');
  $rs->create({section => 'forward', id_run => 4360, position => 1, file_name => $fname, file_content => $text, split => 'none', tag_index => -1});
  my $where = {split => 'none', tag_index => -1};
  $where->{'id_run'}   = 4360;
  $where->{'position'} = 1;
  $where->{'section'}  = 'forward';
  is ($rs->search($where)->count, 1, 'one fastqcheck file saved');

  my $url = q[http://localhost/visuals/qualmap?rpt_list=4360:1&read=forward&db_lookup=1];
  $mech->get_ok($url);
}

1;


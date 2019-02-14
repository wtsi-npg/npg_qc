use strict;
use warnings;
use lib 't/lib';
use Test::More tests => 5;
use Test::Exception;
use Cwd;
use File::Spec;
use Test::WWW::Mechanize::Catalyst;

use t::util;

my $util = t::util->new();
local $ENV{CATALYST_CONFIG} = $util->config_path;

my $schemas;
lives_ok { $schemas = $util->test_env_setup() }  'test db created and populated';
use_ok 'Test::WWW::Mechanize::Catalyst', 'npg_qc_viewer';
my $mech = Test::WWW::Mechanize::Catalyst->new;

{
  $mech->get_ok(q[http://localhost/visuals/qualmap_legend]);

  my $path = File::Spec->catfile(cwd, 't', 'data', 'qualmap');
  my $file_path = join q[/], $path, '26607_1%2320_F0xB00.samtools_stats.json';
  my $url = q[http://localhost/visuals/qualmap?file_path=] . $file_path . q[&read=forward&rpt_list=4360:1];
  $mech->get_ok($url);
  $url = q[http://localhost/visuals/qualmap?file_path=] . $file_path . q[&read=forward&db_lookup=0&rpt_list=4360:1];
  $mech->get_ok($url);
}

1;


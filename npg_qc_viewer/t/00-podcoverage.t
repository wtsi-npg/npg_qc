use strict;
use warnings;
use Test::More;
use t::util;

eval "use Test::Pod::Coverage 1.04";
plan skip_all => 'Test::Pod::Coverage 1.04 required' if $@;

my @dirs = ('lib/npg_qc_viewer');
my @modules = all_modules(@dirs);
plan tests => scalar @modules;

my $util = t::util->new(fixtures => 0);
local $ENV{'HOME'} = 't/data';
$util->test_env_setup();
local $ENV{CATALYST_CONFIG} = $util->config_path;

foreach my $module (@modules) {
  pod_coverage_ok($module);
}
1;

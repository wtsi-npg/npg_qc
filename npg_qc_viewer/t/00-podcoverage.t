use strict;
use warnings;
use Test::More;

eval "use Test::Pod::Coverage 1.04";
plan skip_all => 'Test::Pod::Coverage 1.04 required' if $@;

my @dirs = ('lib/npg_qc_viewer');
my @modules = all_modules(@dirs);
plan tests => scalar @modules;

foreach my $module (@modules) {
  pod_coverage_ok($module);
}
1;

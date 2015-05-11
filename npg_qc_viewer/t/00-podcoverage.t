use strict;
use warnings;
use Test::More;

if (!$ENV{'TEST_AUTHOR'}) {
  my $msg = 'Author test.  Set $ENV{TEST_AUTHOR} to a true value to run.';
  plan( skip_all => $msg );
}

my $home = $ENV{'HOME'};
if (!$home || !-d "$home/.npg") {
  my $msg = 'Need access to .npg directory in home directory to read db credentials';
  plan( skip_all => $msg );
}

eval "use Test::Pod::Coverage 1.04";
plan skip_all => 'Test::Pod::Coverage 1.04 required' if $@;

my @dirs = ('lib/npg_qc_viewer');
my @modules = all_modules(@dirs);
plan tests => scalar @modules;

local $ENV{'dev'} = 'dev'; # Catalyst DBIx models connect to the db inside the constructor.
diag 'Allow connections to dev databases';
foreach my $module (@modules) {
  pod_coverage_ok($module);
}
1;

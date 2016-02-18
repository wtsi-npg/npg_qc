use strict;
use warnings;
use lib 't/lib';
use Test::More;
use English qw(-no_match_vars);
use t::util;

eval {
  require Test::Distribution;
};

if($EVAL_ERROR) {
  plan skip_all => 'Test::Distribution not installed';
} else {
  my $util = t::util->new(fixtures => 0);
  local $ENV{'HOME'} = 't/data';
  $util->test_env_setup();
  local $ENV{CATALYST_CONFIG} = $util->config_path;

  my @nots = qw(prereq pod);
  Test::Distribution->import('not' => \@nots); # Having issues with Test::Dist seeing my PREREQ_PM :(
}

1;

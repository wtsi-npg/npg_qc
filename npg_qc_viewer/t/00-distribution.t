use strict;
use warnings;
use Test::More;
use English qw(-no_match_vars);

if (!$ENV{'TEST_AUTHOR'}) {
  my $msg = 'Author test.  Set $ENV{TEST_AUTHOR} to a true value to run.';
  plan( skip_all => $msg );
}

my $home = $ENV{'HOME'};
if (!$home || !-d "$home/.npg") {
  my $msg = 'Need access to .npg directory in home directory to read db credentials';
  plan( skip_all => $msg );
}

eval {
  require Test::Distribution;
};

if($EVAL_ERROR) {
  plan skip_all => 'Test::Distribution not installed';
} else {
  local $ENV{'dev'} = 'dev'; # Catalyst DBIx models connect to the db inside the constructor.
  diag 'Allow connections to dev databases';
  my @nots = qw(prereq pod);
  Test::Distribution->import('not' => \@nots); # Having issues with Test::Dist seeing my PREREQ_PM :(
}

1;

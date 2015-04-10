use strict;
use warnings;
use Test::More tests => 2;
use Test::Exception;
use Cwd;
use File::Spec;

use t::util;

my $util = t::util->new();
local $ENV{CATALYST_CONFIG} = $util->config_path;
local $ENV{TEST_DIR}        = $util->staging_path;

{
  use_ok 'Catalyst::Test', 'npg_qc_viewer';
  use_ok 'npg_qc_viewer::Controller::Mqc_Run';
}

1;
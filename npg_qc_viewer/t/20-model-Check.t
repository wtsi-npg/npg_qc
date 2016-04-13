use strict;
use warnings;
use lib 't/lib';
use Test::More tests => 2;
use Test::Exception;
use t::util;

my $util = t::util->new(db_connect=>0);
local $ENV{CATALYST_CONFIG} = $util->config_path;

use_ok 'npg_qc_viewer::Model::Check';

{
  isa_ok(npg_qc_viewer::Model::Check->new(), 'npg_qc_viewer::Model::Check');
}

1;

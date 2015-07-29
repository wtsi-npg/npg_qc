use strict;
use warnings;
use Test::More tests => 1;
use Test::Exception;
use File::Temp qw(tempfile);

use t::util;

BEGIN { use_ok 'npg_qc_viewer::Model::WarehouseDB' }

1;
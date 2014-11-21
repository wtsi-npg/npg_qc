use strict;
use warnings;

use npg_qc_viewer;

my $app = npg_qc_viewer->apply_default_middlewares(npg_qc_viewer->psgi_app);
$app;


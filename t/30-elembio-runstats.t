use strict;
use warnings;
use Test::More;
use Test::Exception;

use_ok('npg_qc::elembio::run_stats');

my $stats = npg_qc::elembio::run_stats->new();

# Insert some useful tests with realistic data?

done_testing();
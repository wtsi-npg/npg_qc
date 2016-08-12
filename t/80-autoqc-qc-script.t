use strict;
use warnings;
use Test::More tests => 2;
use File::Temp qw/tempdir/;

local $ENV{NPG_WEBSERVICE_CACHE_DIR} = q[t/data/autoqc];
my $path = qq[t/data/autoqc/123456_IL2_2222/Data/Intensities/Bustard-2009-10-01/PB_cal/archive];
my $odir = tempdir(CLEANUP => 1);

my @args = ("bin/qc", "--id_run=2222", "--position=1", "--check=qX_yield", "--tag_index=1", "--qc_in=$path", "--qc_out=$odir");
is (system(@args), 0, 'script exited normally');

my $command = "bin/qc --id_run 2222 --position 1 --check qX_yield --tag_index 1 --qc_in $path --qc_out $odir";
is (system($command), 0, 'script exited normally');

1;

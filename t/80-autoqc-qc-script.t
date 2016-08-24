use strict;
use warnings;
use Test::More tests => 8;
use File::Temp qw/tempdir/;

local $ENV{NPG_WEBSERVICE_CACHE_DIR} = q[t/data/autoqc];
my $path = qq[t/data/autoqc/123456_IL2_2222/Data/Intensities/Bustard-2009-10-01/PB_cal/archive];
my $odir = tempdir(CLEANUP => 1);

my @args = ("bin/qc", "--id_run=2222", "--position=1", "--check=qX_yield", "--tag_index=1", "--qc_in=$path", "--qc_out=$odir");
is (system(@args), 0, 'tag level - script exited normally');
my $expected = join q[/], $odir, '2222_1#1.qX_yield.json';
ok(-e $expected, 'json output exists');
unlink $expected;

my $command = "bin/qc --id_run 2222 --position 1 --check qX_yield --tag_index 1 --qc_in $path --qc_out $odir";
is (system($command), 0, 'tag level - script exited normally');
ok(-e $expected, 'json output exists');
unlink $expected;

$command = "bin/qc --id_run 2222 --position 1 --check qX_yield --tag_index 1 --qc_in $path --qc_out $odir --reference some_ref";
is (system($command), 0, 'tag level, extra non-existing arguments - script exited normally');
ok(-e $expected, 'json output exists');

$command = "bin/qc --id_run 2222 --position 1 --check qX_yield --qc_in $path --qc_out $odir";
is (system($command), 0, 'lane level - script exited normally');
$expected = join q[/], $odir, '2222_1.qX_yield.json';
ok(-e $expected, 'json output exists');

1;

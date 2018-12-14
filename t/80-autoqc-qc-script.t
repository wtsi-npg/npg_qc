use strict;
use warnings;
use Test::More tests => 15;
use File::Temp qw/tempdir/;
use Cwd;

my $path = qq[t/data/samtools_stats];
my $odir = tempdir(CLEANUP => 1);
my $expected = join q[/], $odir, '26607_1#20.qX_yield.json';
my $app_ref_path = join q[/], cwd, q[t/data/autoqc/gc_fraction/Homo_sapiens.NCBI36.48.dna.all.fa];

my @args = ("bin/qc", "--rpt_list=26607:1:20", "--check=qX_yield", "--qc_in=$path", "--qc_out=$odir");
is (system(@args), 0, 'tag level - script exited normally');
ok(-e $expected, 'json output exists');
unlink $expected;

my $command = "bin/qc --id_run 26607 --position 1 --check qX_yield --tag_index 20 --qc_in $path --qc_out $odir";
is (system($command), 0, 'tag level - script exited normally');
ok(-e $expected, 'json output exists');
unlink $expected;

$command = "bin/qc --rpt_list=26607:1:20 --check qX_yield --input_files $path/26607_1#20_F0xB00.stats --qc_out $odir";
is (system($command), 0, 'lane level - script exited normally');
ok(-e $expected, 'json output exists');
unlink $expected;

$command = "bin/qc --rpt_list=26607:1:20 --check qX_yield --input_files $path/26607_1#20_F0xB00.stats --qc_out $odir --is_paired_read";
is (system($command), 0, 'lane level - script exited normally');
ok(-e $expected, 'json output exists');
unlink $expected;

$command = "bin/qc --rpt_list=26607:1:20 --check qX_yield --input_files $path/26607_1#20_F0xB00.stats --qc_out $odir --no-is_paired_read";
is (system($command), 0, 'lane level - script exited normally');
ok(-e $expected, 'json output exists');
unlink $expected;

$expected = join q[/], $odir, '26607_1#20.gc_fraction.json';

$command = "bin/qc --rpt_list=26607:1:20 --check gc_fraction --input_files $path/26607_1#20_F0xB00.stats --qc_out $odir --is_paired_read --ref_base_count_path $app_ref_path --repository t";
is (system($command), 0, 'lane level - script exited normally');
ok(-e $expected, 'json output exists');
unlink $expected;

$command = "bin/qc --rpt_list=26607:1:20 --check gc_fraction --input_files $path/26607_1#20_F0xB00.stats --qc_out $odir --no-is_paired_read --ref_base_count_path $app_ref_path --repository t";
is (system($command), 0, 'lane level - script exited normally');
ok(-e $expected, 'json output exists');
unlink $expected;

local $ENV{NPG_WEBSERVICE_CACHE_DIR} = q[t/data/autoqc/insert_size];

$command = "bin/qc --rpt_list 1937:1 --check insert_size --no-is_paired_read --qc_in t/data/autoqc --qc_out $odir --repository t/data/autoqc";
is (system($command), 0, 'script exited normally');

1;

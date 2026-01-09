use strict;
use warnings;
use Test::More tests => 2;
use Test::Exception;
use File::Temp qw/ tempdir /;
use Archive::Extract;
use Perl6::Slurp;
use JSON;

my $tmp = tempdir(CLEANUP => 1);

use_ok 'npg_qc::ultimagen::run_stats';

subtest 'parse run with six target samples' => sub {
  plan tests => 17;

  my $out = join q[/], $tmp, '424445-20251105_1219_qc_out';
  my $ae = Archive::Extract->new(
    archive => 't/data/ultimagen/424445-20251105_1219.tar.gz');
  $ae->extract(to => $tmp) or die $ae->error;   
  my $runfolder = join q[/], $tmp, '424445-20251105_1219'; 
  my $compare_dir = "${runfolder}_output";  

  my $parser = npg_qc::ultimagen::run_stats->new(
    id_run => 33,
    runfolder_path => $runfolder,
    qc_output_dir => $out
  );

  lives_ok { $parser->parse() } 'parsed stats for 424445-20251105_1219';
  
  my @file_names = qw/33_1.tag_metrics.json/;
  push @file_names, map { sprintf '33_1#%i.qX_yield.json', $_ }
                    (10 .. 13, 15, 16, 9999);

  for my $name ( @file_names ) {

    my $generated  = join q[/], $out, $name;
    ok (-f $generated,"$generated file generated");
    my $result = from_json slurp $generated;

    my $expected = join q[/], $compare_dir, $name;
    my $expected_result = from_json slurp $expected;
    
    for my $h (($result, $expected_result)) {
      for my $key (qw/ __CLASS__ composition path info/) {
        delete $h->{$key};
      }
    }
    is_deeply ($result, $expected_result, "data in $name as expected");
  }
};


1;

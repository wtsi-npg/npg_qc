use strict;
use warnings;
use Test::More tests => 3;
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

subtest 'get input read number' => sub {
   plan tests => 5;

   my $data = [
    { 'read group' => 'Z0016',
      'format' => 'trim native adapter and filter lengths',
      'segment label' => 0,
      'num input reads' => 126910234 },
    { 'read group' => 'Z0016',
      'format' => 'trim native adapter and filter lengths',
      'segment label' => 1,
      'num input reads' => 126910234 },
    { 'read group' => 'Z0016',
      'format' => 'trim native ramp multi flavor adapter and filter lengths',
      'segment label' => 0,
      'num input reads' => 167185236 },
    { 'read group' => 'Z0016',
      'format' => 'trim native ramp multi flavor adapter and filter lengths',
      'segment label' => 0,
      'num input reads' => 167185236 }
  ];
  
  is (npg_qc::ultimagen::run_stats::get_num_input_reads($data), 167185236,
    'Correct value for UG200');
  
  pop @{$data};
  my $value = pop @{$data};
  is (npg_qc::ultimagen::run_stats::get_num_input_reads($data), 126910234,
    'Correct value for UG100');

  $data->[0]->{'read group'} = 'Z0018';
  throws_ok { npg_qc::ultimagen::run_stats::get_num_input_reads($data) }
    qr/Inconsistent read group values: Z0018, Z0016/,
    'error for multiple read group names';
  $data->[0]->{'read group'} = 'Z0016';

  $data->[0]->{'num input reads'} = 3;
  throws_ok { npg_qc::ultimagen::run_stats::get_num_input_reads($data) }
    qr/Inconsistent input reads numbers for read group Z0016/,
    'error for different read numbers';

  $data = [
    { 'read group' => 'Z0016',
      'format' => 'no trimming',
      'segment label' => 0,
      'num input reads' => 910234 }
  ];
  is (npg_qc::ultimagen::run_stats::get_num_input_reads($data), 910234,
    'Correct value for an unspecified format');
};

1;

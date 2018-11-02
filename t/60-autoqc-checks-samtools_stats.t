use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;
use File::Temp qw/tempdir/;

use_ok('npg_qc::autoqc::checks::samtools_stats');

my $dir = tempdir( CLEANUP => 1 );

subtest 'lane level with qc_in, ext and suffix default values' => sub { 
  plan tests => 5;

  my $check = npg_qc::autoqc::checks::samtools_stats->new(rpt_list=>'27178:1', qc_in => 't/data/autoqc/samtools_stats', qc_out => $dir );
  isa_ok ($check, 'npg_qc::autoqc::checks::samtools_stats');

  is_deeply ($check->input_files, ['t/data/autoqc/samtools_stats/27178_1_F0x000.stats'], 'input files checked - expected one found');

  lives_ok {$check->result} 'can create result object';

  lives_ok { $check->execute } 'execution ok when input file present';

  is ($check->result->filter, 'F0x000', 'found F0x000 filter value in result');
};

subtest 'plex level with qc_in, ext default value, suffix specified' => sub { 
  plan tests => 5;

  my $check = npg_qc::autoqc::checks::samtools_stats->new(rpt_list=>'27178:1:1', qc_in => 't/data/autoqc/samtools_stats', qc_out => $dir, suffix => 'F0x900', );
  isa_ok ($check, 'npg_qc::autoqc::checks::samtools_stats');

  is_deeply ($check->input_files, ['t/data/autoqc/samtools_stats/27178_1#1_F0x900.stats'], 'input files checked - expected one found');

  lives_ok {$check->result} 'can create result object';

  lives_ok { $check->execute } 'execution ok when input file present';

  is ($check->result->filter, 'F0x900', 'found F0x900 filter value in result');
};

subtest 'plex level with qc_in, suffix default value, ext specified' => sub { 
  plan tests => 4;

  my $check = npg_qc::autoqc::checks::samtools_stats->new(rpt_list=>'27178:1', qc_in => 't/data/autoqc/samtools_stats', qc_out => $dir, ext => 'altstats', );
  isa_ok ($check, 'npg_qc::autoqc::checks::samtools_stats');

  is_deeply ($check->input_files, ['t/data/autoqc/samtools_stats/27178_1_F0x000.altstats'], 'input files checked - expected one found');

  lives_ok {$check->result} 'can create result object';

  # if/when the samtools_stats result is made more tolerant of input file extension changes, this can change to lives_ok
  throws_ok { $check->execute }
    qr/Failed to get filter from 27178_1_F0x000.altstats/,
    'error from execute when using alternative extension for input';
};

1;

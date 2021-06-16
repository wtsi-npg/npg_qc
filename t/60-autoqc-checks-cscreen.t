use strict;
use warnings;
use File::Temp qw/tempdir/;
use Test::More tests => 5;
use Test::Exception;
use Cwd;
use Fatal qw(open close symlink);

use_ok ('npg_qc::autoqc::checks::cscreen');

my $tdir = tempdir( CLEANUP => 1 );
local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
  q[t/data/autoqc/verify_bam_id/samplesheet_27483.csv];

my $asketch_path_rel  = 't/data/autoqc/cscreen/adapters.32.100000.msh';
my $asketch_path_abs  = join q[/], getcwd(), $asketch_path_rel;

subtest 'create check object' => sub {
  plan tests => 3;

  my $cs = npg_qc::autoqc::checks::cscreen->new(
    rpt_list   => '27483:1:4',
    qc_out     => $tdir,
    repository => 't/data/autoqc/cscreen');
  isa_ok ($cs, 'npg_qc::autoqc::checks::cscreen');
  isa_ok ($cs->result, 'npg_qc::autoqc::results::cscreen',
    'correct result object class');
  is ($cs->file_type, 'cram', 'default file type is cram');
};

subtest 'mash sketch path' => sub {
  plan tests => 8;

  my $cs = npg_qc::autoqc::checks::cscreen->new(
    rpt_list    => '27483:1:4',
    repository  => 't/data/autoqc/cscreen',
    sketch_path => 't/data/autoqc/cscreen/some.msh'
  );
  throws_ok { $cs->sketch_path }
    qr/'t\/data\/autoqc\/cscreen\/some.msh' is not found/,
    'error if a file does not exist';
 
  $cs = npg_qc::autoqc::checks::cscreen->new(
    rpt_list    => '27483:1:4',
    sketch_path => 't/data/autoqc/cscreen',
    repository  => 't/data/autoqc/cscreen'    
  );
  throws_ok { $cs->sketch_path }
    qr/'t\/data\/autoqc\/cscreen' is not a file/,
    'error when directory is given as a sketch path';

  $cs = npg_qc::autoqc::checks::cscreen->new(
    rpt_list    => '27483:1:4',
    sketch_path => $asketch_path_rel,
    repository  => 't/data/autoqc/cscreen'    
  );
  is ($cs->sketch_path, $asketch_path_abs,
    'relative path is converted to an absolute path');
  
  $cs = npg_qc::autoqc::checks::cscreen->new(
    rpt_list    => '27483:1:4',
    sketch_path => $asketch_path_abs,
    repository  => 't/data/autoqc/cscreen'  
  );
  is ($cs->sketch_path, $asketch_path_abs, 'absolute path as given'); 
  
  my $tsketch = "$tdir/tsketch.mash";
  open my $fh, q[>], $tsketch;
  print $fh 'test mash sketch'; 
  close $fh;
  symlink $tsketch, "$tdir/link.mash";

  $cs = npg_qc::autoqc::checks::cscreen->new(
    rpt_list    => '27483:1:4',
    sketch_path => "$tdir/link.mash",
    repository  => 't/data/autoqc/cscreen'
  );
  is ($cs->sketch_path, $tsketch, 'symlink to an abs path is resolved');

  symlink 'tsketch.mash', "$tdir/link1.mash";
  $cs = npg_qc::autoqc::checks::cscreen->new(
    rpt_list    => '27483:1:4',
    sketch_path => "$tdir/link1.mash",
    repository  => 't/data/autoqc/cscreen' 
  );
  is ($cs->sketch_path, $tsketch,
    'symlink is converted to an absolute path');

  mkdir "$tdir/1";
  symlink '../tsketch.mash', "$tdir/1/link.mash"; 
  $cs = npg_qc::autoqc::checks::cscreen->new(
    rpt_list    => '27483:1:4',
    sketch_path => "$tdir/1/link.mash",
    repository  => 't/data/autoqc/cscreen'
  );
  is ($cs->sketch_path, $tsketch, 'symlink to a relative path is resolved');

  unlink $tsketch;
  $cs = npg_qc::autoqc::checks::cscreen->new(
    rpt_list    => '27483:1:4',
    sketch_path => "$tdir/link.mash",
    repository  => 't/data/autoqc/cscreen'
  );
  throws_ok { $cs->sketch_path } qr/is not found/,
    'error for a broken symlink';
};

subtest 'run command' => sub {
  plan tests => 5;

  # The tests in this section require samtools and mash to be
  # on the PATH.

  # Test with an input file that does not exists 
  my $cs = npg_qc::autoqc::checks::cscreen->new(
    rpt_list    => '27483:1:4',
    sketch_path => 't/data/autoqc/cscreen/adapters.32.100000.msh',
    repository  => 't/data/autoqc/cscreen',
    input_files => ['t/data/autoqc/cscreen/notest.bam']
  );
  throws_ok { $cs->_screen() } qr//, 'error executing command';

  # Test with an input file with data, which produces some matches.
  $cs = npg_qc::autoqc::checks::cscreen->new(
    rpt_list    => '27483:1:4',
    sketch_path => 't/data/autoqc/cscreen/adapters.32.100000.msh',
    repository  => 't/data/autoqc/cscreen',
    input_files => ['t/data/autoqc/cscreen/test.bam']
  );
  my $data = [];
  lives_ok { $cs->_screen() } 'good input, some matches - runs OK';
  use Data::Dumper;
  diag Dumper($data);

  # Test with an input file with data, which does not produce any matches.
  $cs = npg_qc::autoqc::checks::cscreen->new(
    rpt_list    => '27483:1:4',
    sketch_path => 't/data/autoqc/cscreen/adapters.32.100000.msh',
    repository  => 't/data/autoqc/cscreen',
    input_files => ['t/data/autoqc/cscreen/test_no_matches.bam']
  );
  lives_ok { $cs->_screen() } 'good input, no matches - runs OK';

  # Test with a valid input file with no reads.
  $cs = npg_qc::autoqc::checks::cscreen->new(
    rpt_list    => '27483:1:4',
    sketch_path => 't/data/autoqc/cscreen/adapters.32.100000.msh',
    repository  => 't/data/autoqc/cscreen',
    input_files => ['t/data/autoqc/cscreen/test_empty.bam']
  );
  throws_ok { $cs->_screen() } qr//,
    'error - mash cannot deal with empty input';
  
  # Force an error in samtools, test with an input file in the format
  # samtools does not understand.
  $cs = npg_qc::autoqc::checks::cscreen->new(
    rpt_list    => '27483:1:4',
    sketch_path => 't/data/autoqc/cscreen/adapters.32.100000.msh',
    repository  => 't/data/autoqc/cscreen',
    input_files => ['t/data/autoqc/cscreen/adapters.32.100000.msh']
  );
  throws_ok { $cs->_screen() } qr//,
    'error in the pipe is propagated';
};

subtest 'execute teh check' => sub { 
  plan tests => 1;
  
  my $cs = npg_qc::autoqc::checks::cscreen->new(
    rpt_list        => '27483:1:4',
    sketch_path     => 't/data/autoqc/cscreen/adapters.32.100000.msh',
    repository      => 't/data/autoqc/cscreen',
    input_files     => ['t/data/autoqc/cscreen/test_empty.bam'],
    num_input_reads => 0
  );
  lives_ok { $cs->execute() } 'shortcut - runs OK';
};

1;

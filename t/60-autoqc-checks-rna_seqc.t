use strict;
use warnings;
use Cwd;
use Test::More tests => 4;
use Test::Exception;
use File::Temp qw/ tempdir /;

use_ok ('npg_qc::autoqc::checks::rna_seqc');

my $dir = tempdir( CLEANUP => 1 );
`touch $dir/RNA-SeQC_v1.1.8.jar`;

my $repos = cwd . '/t/data/autoqc';

{
  local $ENV{CLASSPATH} = $dir;

  my $rnaseqc = npg_qc::autoqc::checks::rna_seqc->new(
    id_run => 2,
    path => q[mypath],
    position => 1,
    repository => $repos,
    qc_out => q[t/data]);

  isa_ok ($rnaseqc, 'npg_qc::autoqc::checks::rna_seqc');

  lives_ok { $rnaseqc->result; } 'result object created';

  local $ENV{CLASSPATH} = q[];

  throws_ok {npg_qc::autoqc::checks::rna_seqc->new(id_run => 2, path => q[mypath], position => 1, qc_out => q[t/data])}
         qr/Can\'t find \'RNA-SeQC_v1.1.8\.jar\' because CLASSPATH is not set/,
         q[Fails to create object when RNA-SeQC_v1.1.8.jar not found];
}

1;

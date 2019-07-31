use strict;
use warnings;
use File::Temp qw/ tempdir /;
use Test::More tests => 9;
use Test::Exception;

use_ok('npg_qc::autoqc::checks::adapter');

my $test_parent = 't/data/autoqc';
my $dir = tempdir(CLEANUP => 1);

my $bt = join q[/], $dir, q[blat];
open my $fh,  q[>], $bt;
print $fh qq[cat\n];
close $fh;

my $f2f = join q[/], $dir, q[npg_fastq2fasta];
open $fh,  q[>], $f2f;
print $fh qq[cat $test_parent/9999_1.blat\n];
close $fh;

my $bamtofastq = join q[/], $dir, q[bamtofastq];
`touch $bamtofastq`;
`chmod +x $f2f $bt $bamtofastq`;

local $ENV{PATH} = join q[:], $dir, $ENV{PATH};

{
  throws_ok {
    npg_qc::autoqc::checks::adapter->new( 
                    position => 3,
                    qc_in   => 't/data/autoqc/090721_IL29_2549/data',
                    id_run   => 2549,
                    adapter_fasta => '/no/such/file',
                  )
  } qr{Attribute \(adapter_fasta\) does not pass the type constraint}ms,
    'Croak with unreadable adapter list';

  my $test;
  lives_ok {
    $test = npg_qc::autoqc::checks::adapter->new( position => 3,
                    qc_in    => 't/data/autoqc/090721_IL29_2549/data',
                    id_run   => 2549,
                  )
  } 'Create the check object';

  isa_ok( $test, 'npg_qc::autoqc::checks::adapter' );
}

{
  my $test;
  lives_ok {
    $test = npg_qc::autoqc::checks::adapter
             ->new( position => 3,
                    qc_in    => 't/data/autoqc/090721_IL29_2549/data',
                    id_run   => 2549,
                    adapter_fasta => 't/data/autoqc/adapter.fasta',
                  )
  } 'Create the check object';

  is( $test->file_type(), 'cram', 'file type is cram');
  is( $test->adapter_fasta(), 't/data/autoqc/adapter.fasta',
    'default adapter fasta listing adapters' );
  is( $test->_blat_command, qq[$bt t/data/autoqc/adapter.fasta stdin stdout -tileSize=9 -maxGap=0 -out=blast8], 'blat command line');

  my $empty = join q[/], $dir, q[empty];
  `touch $empty`;
  open my $fh, q[<], $empty;
  my $result = $test->_process_search_output($fh);
  close $fh;

  my @adapters = qw(DpnII-Gex-Adapter1-1 DpnII-Gex-Adapter1-2 DpnII-Gex-Adapter2-1 DpnII-Gex-Adapter2-2 DpnII-Gex-PCR-Primer1 DpnII-Gex-PCR-Primer2 DpnII-Gex-SequencingPrimer NlaIII-Gex-Adapter1-1 NlaIII-Gex-Adapter1-2 NlaIII-Gex-Adapter2-1 NlaIII-Gex-Adapter2-2 NlaIII-Gex-PCR-Primer1 NlaIII-Gex-PCR-Primer2 NlaIII-Gex-SequencingPrimer PE-PCR-Primers1-1 PE-PCR-Primers1-2 PE-adapters1-1 PE-adapters1-2 PE-sequencingPrimer1 PE-sequencingPrimer2 adaptor1 adaptor2 adaptor3 adaptor4 genomicDNA-adapter1 genomicDNA-adapter2 genomicDNA-primer1 genomicDNA-sequencingPrimer genomicDNA=primer2 smallRNA-3'adapter smallRNA-5'adapter smallRNA-PCS-primer1 smallRNA-PCS-primer2 smallRNA-RT-primer smallRNA-sequencingPrimer);
  my $expected = { contam_hash => {}, adapter_starts => {}, contam_read_count => 0,
    forward => { contam_hash => {map {$_ => 0} @adapters}, adapter_starts => {}, contam_read_count => 0,},
    reverse => { contam_hash => {map {$_ => 0} @adapters}, adapter_starts => {}, contam_read_count => 0,},
  };
  is_deeply ($result, $expected, 'empty result for no blat output');  
}

1;

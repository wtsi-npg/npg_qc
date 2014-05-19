#########
# Author:        jo3
# Maintainer:    $Author$
# Created:       30 July 2009
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

use strict;
use warnings;
use File::Temp qw/ tempdir /;
use Test::More tests => 23;
use Test::Deep;
use Test::Exception;


my %blat_hash = (     'PE-sequencingPrimer1'        =>   0,
                      'smallRNA-3\'adapter'         =>   0,
                      'NlaIII-Gex-PCR-Primer1'      =>   0,
                      'DpnII-Gex-Adapter2-1'        =>   0,
                      'DpnII-Gex-Adapter1-1'        =>   0,
                      'DpnII-Gex-SequencingPrimer'  =>   0,
                      'PE-sequencingPrimer2'        => 440,
                      'adaptor3'                    =>   0,
                      'smallRNA-5\'adapter'         =>   0,
                      'genomicDNA=primer2'          =>   0,
                      'NlaIII-Gex-Adapter2-1'       =>   0,
                      'PE-adapters1-2'              =>   0,
                      'genomicDNA-primer1'          =>   0,
                      'NlaIII-Gex-Adapter1-1'       =>   0,
                      'DpnII-Gex-PCR-Primer2'       =>   0,
                      'smallRNA-PCS-primer1'        =>   0,
                      'smallRNA-RT-primer'          =>   0,
                      'NlaIII-Gex-Adapter2-2'       =>   0,
                      'adaptor4'                    => 426,
                      'NlaIII-Gex-Adapter1-2'       =>   0,
                      'NlaIII-Gex-PCR-Primer2'      =>   0,
                      'adaptor2'                    =>   0,
                      'DpnII-Gex-Adapter1-2'        =>   0,
                      'genomicDNA-adapter2'         =>   0,
                      'genomicDNA-sequencingPrimer' =>   0,
                      'PE-PCR-Primers1-1'           =>   0,
                      'PE-PCR-Primers1-2'           => 426,
                      'PE-adapters1-1'              => 302,
                      'smallRNA-sequencingPrimer'   =>   0,
                      'NlaIII-Gex-SequencingPrimer' =>   0,
                      'adaptor1'                    =>   0,
                      'DpnII-Gex-PCR-Primer1'       =>   0,
                      'smallRNA-PCS-primer2'        =>   0,
                      'genomicDNA-adapter1'         =>   0,
                      'DpnII-Gex-Adapter2-2'        =>   0,
    );

use_ok('npg_qc::autoqc::checks::adapter');
# if this test fails, probably Readonly::Scalar::XS is not installed

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
`chmod +x $f2f $bt`;

my $jar = join q[/], $dir, 'SamToFastq.jar';
`touch $jar`;

local $ENV{PATH} = join q[:], $dir, $ENV{PATH};

{
  throws_ok {
    npg_qc::autoqc::checks::adapter->new( 
                    position => 3,
                    path     => 't/data/autoqc/090721_IL29_2549/data',
                    id_run   => 2549,
                    sam2fastq_jar => $jar,
                    adapter_fasta => '/no/such/file',
                  )
  } qr{Attribute \(adapter_fasta\) does not pass the type constraint}ms,
    'Croak with unreadable adapter list';

  my $test;
  lives_ok {
    $test = npg_qc::autoqc::checks::adapter->new( position => 3,
                    path     => 't/data/autoqc/090721_IL29_2549/data',
                    sam2fastq_jar => $jar,
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
                    path     => 't/data/autoqc/090721_IL29_2549/data',
                    id_run   => 2549,
                    sam2fastq_jar => $jar,
                    adapter_fasta => 't/data/autoqc/adapter.fasta',
                  )
  } 'Create the check object';

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
  cmp_deeply ($result, $expected, 'empty result for no blat output');  
}

{
  my $f1 = join q[/], $dir, q[9999_2_1.fastq];
  `touch $f1`;
  my $f2 = join q[/], $dir, q[9999_2_2.fastq];
  `touch $f2`;

  my $test = npg_qc::autoqc::checks::adapter
             ->new( position => 2,
                    path     => $dir,
                    id_run   => 9999,
                    sam2fastq_jar => $jar,
                    adapter_fasta => 't/data/autoqc/adapter.fasta',
                  );
  
  $test->execute();
  cmp_deeply( $test->result->forward_blat_hash, {},
    'forward blat hash in the result is empty for an empty fastq' );
  cmp_deeply( $test->result->reverse_blat_hash, {},
    'reverse blat hash in the result is empty for an empty fastq' );
}

{
  my $test = npg_qc::autoqc::checks::adapter->new(
                 position      => 1,
                 path          => $test_parent,
                 id_run        => 9999,
                 adapter_fasta => 't/data/autoqc/adapter.fasta',
                 sam2fastq_jar => $jar,
                 aligner_path   => $bt,
                      );
  lives_ok { $test->execute() } 'No failures in mocked run';

  is( $test->result->forward_read_filename, '9999_1.fastq',
        'forward read name set correctly in the result object' );
  ok( !defined $test->result->reverse_read_filename(),
        'reverse read name is not defined in the result object' );

  is( $test->result->forward_fasta_read_count, 10_000,'read count' );
  is( $test->result->forward_contaminated_read_count, 467, 'contaminated read count' );
  is_deeply( $test->result->forward_blat_hash, \%blat_hash, 'adapter report'  );

  is($test->result->image_url('forward'), q[http://chart.apis.google.com/chart?chbh=4,1,1&chco=4D89F9&chd=t:0,0,0,0&chds=0,1&chs=260x200&cht=bvg&chtt=Adapter+start+count+(log10+scale)+vs|cycle+for+9999_1.fastq&chxr=0,0,4,0|1,0,1,0&chxt=x,y], 'image url');
  is($test->result->image_url('reverse'), q[], 'empty image url');
}

{
  my $f1 = join q[/], $dir, q[9999_3_1.fastq];
  `touch $f1`; 
  my $f2 = join q[/], $dir, q[9999_3_2.fastq];
  `cp $test_parent/9999_1.fastq $f2`;

  my $test = npg_qc::autoqc::checks::adapter->new(
                    position => 3,
                    path     => $dir,
                    id_run   => 9999,
                    aligner_path   => $bt,
                    sam2fastq_jar => $jar,
                    adapter_fasta => 't/data/autoqc/adapter.fasta',
                  );  
  lives_ok {$test->execute()} 'execute lives';
  cmp_deeply( $test->result->forward_blat_hash, {},
    'forward blat hash in the result is empty for an empty fastq' );
  is_deeply( $test->result->reverse_blat_hash, \%blat_hash,
    'Correct adapter report for the reverse read when the forward read was empty' );
}

{
  open $fh,  q[>], $f2f;
  print $fh qq[ls dada\n];
  close $fh;
  `chmod 755 $f2f`;

  my $test = npg_qc::autoqc::checks::adapter->new(
                 position      => 1,
                 path          => $test_parent,
                 id_run        => 9999,
                 adapter_fasta => 't/data/autoqc/adapter.fasta',
                 sam2fastq_jar => $jar,
                 aligner_path   => $bt,
                      );
  throws_ok { $test->execute() } qr/Error in pipe/, 'Failure of the aligner';
}

{
  open my $fh,  q[>], $bt;
  print $fh qq[ls dodo\n];
  close $fh;

  open $fh,  q[>], $f2f;
  print $fh qq[ls t\n];
  close $fh;
  `chmod 755 $bt $f2f`;

  my $test = npg_qc::autoqc::checks::adapter->new(
                 position      => 1,
                 path          => $test_parent,
                 id_run        => 9999,
                 adapter_fasta => 't/data/autoqc/adapter.fasta',
                 sam2fastq_jar => $jar,
                 aligner_path   => $bt,
                      );
  throws_ok { $test->execute() } qr/Error in pipe/, 'Failure of the aligner';
}


1;

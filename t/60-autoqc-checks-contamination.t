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
use Cwd qw(cwd abs_path);
use File::Temp qw/ tempdir /;
use Test::More tests => 17;
use Test::Deep;
use Test::Exception;

our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/msx; $r; };

use_ok('npg_qc::autoqc::checks::contamination');

my $ref_repos = cwd . '/t/data/autoqc';
my $fastq_path = 't/data/autoqc';
my $dir = tempdir(CLEANUP => 1);

my $expected_genome_factor = { 
             Homo_sapiens               => '12.46',
             Mus_musculus               => '13.46',
             Danio_rerio                => '19.26',
             Clostridium_difficile      =>  '1.00',
             Escherichia_coli           =>  '1.00',
             Mycobacterium_tuberculosis =>  '1.00',
             Plasmodium_falciparum      =>  '7.07',
             PhiX                       =>  '1.00',
             Streptococcus_equi         =>  '1.00',
             Leishmania_major           => '12.25',
             Human_herpesvirus_4        =>  '1.00',
             Staphylococcus_aureus      =>  '1.00',
             Salmonella_enterica        =>  '1.00',
             Neisseria_meningitidis     =>  '1.00',
             Salmonella_enterica        => '1.00',
             Neisseria_meningitidis     => '1.00',
         };


my $bt = join q[/], $dir, q[bowtie];
open my $fh,  q[>], $bt;
print $fh qq[cat t/data/autoqc/alignment_refmatch.sam\n];
close $fh;
`chmod +x $bt`;

{

  my $test;
  local $ENV{PATH} = join ':', $dir, $ENV{PATH};
  lives_ok {
    $test = npg_qc::autoqc::checks::contamination
             ->new( position => 3,
                    path     => $fastq_path,
                    id_run   => 1937,
                    tmp_path => $dir,
                    repository => $ref_repos,
                  )
   } 'Create the check object';

  isa_ok( $test, 'npg_qc::autoqc::checks::contamination' );
  is( $test->aligner_path(), $bt, 'Use default aligner on path' );
  is( $test->aligner_options(), '--quiet --sam', 'Use default options' );
  lives_ok { $test->reference_details() } 'Gather required details about the compound reference';
  is( $test->readme(), $ref_repos . q[/references/NPD_Chimera/default/README], 'Get path to README' );
  is( $test->read1_fastq(), "$fastq_path/1937_3_1.fastq", 'Path is correct' );
  is_deeply ($test->parse_readme(), $expected_genome_factor,'Correct genome correction factors' );

  my $contam_hash;
  open my $fh, q[<], "$fastq_path/qc/1937_3.map"; 
  lives_ok { $contam_hash = $test->parse_alignment($fh) } 'Parse the alignment output';
  close $fh;

  is( $test->result->aligner_version(), 'Bowtie 0.11.3','Report aligner and version' );
  is_deeply( $contam_hash, { Homo_sapiens => 1,}, 'Count contaminants' );
}


{
    my $test = npg_qc::autoqc::checks::contamination->new(
                path           => $fastq_path,
                aligner_path   => join(q[/], q[does_not_exist], q[bowtie]),
                id_run         => 1937,
                position       =>    3,
                repository     => $ref_repos,
    );
    throws_ok {$test->execute} qr/Cannot fork \"does_not_exist\/bowtie/, 'error when cannot start an aligner';
}

{
    my $bt = join q[/], tempdir(CLEANUP => 1), q[bowtie];

    my $test = npg_qc::autoqc::checks::contamination->new(
                path           => $fastq_path,
                aligner_path   => $bt,
                id_run         => 1937,
                position       =>    3,
                repository     => $ref_repos,
    );

    open my $fh,  q[>], $bt;
    print $fh qq[ls dodo\n];
    close $fh;
    `chmod +x $bt`;

    throws_ok {$test->execute} qr/(exited with status 2)|(Cannot close bad pipe)/, 'error when aligner dies';
}


{
  my $bt = join q[/], $dir, q[bowtie];

  my $test = npg_qc::autoqc::checks::contamination
             ->new( position => 3,
                    path     => $fastq_path,
                    id_run   => 1937,
                    tmp_path => $dir,
                    repository => $ref_repos,
                    aligner_path   => $bt,
                  );

  open my $fh1,  q[>], $bt;
  print $fh1 qq[cat $fastq_path/qc/1937_3.map\n];
  close $fh1;
  `chmod 755 $bt`;

  my $expected_contam = { Homo_sapiens  => 1,
             Mus_musculus               => 0,
             Danio_rerio                => 0,
             Clostridium_difficile      => 0,
             Escherichia_coli           => 0,
             Mycobacterium_tuberculosis => 0,
             Plasmodium_falciparum      => 0,
             PhiX                       => 0,
             Streptococcus_equi         => 0,
             Leishmania_major           => 0,
             Human_herpesvirus_4        => 0,
             Staphylococcus_aureus      => 0,
             Salmonella_enterica        => 0,
             Neisseria_meningitidis     => 0, };


  lives_ok {$test->execute} 'execute lives';
  is_deeply( $test->result->contaminant_count(), $expected_contam, 'Correct contam count saved' );
  is_deeply( $test->result->genome_factor(), $expected_genome_factor, 'Correct genome_factor saved' );
}


1;

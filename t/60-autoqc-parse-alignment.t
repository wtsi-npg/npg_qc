#########
# Author:        Marina Gourtovaia
# Maintainer:    $Author$
# Created:       29 July 2009
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

use strict;
use warnings;
use Test::More tests => 13;
use Test::Exception;
use Test::Deep;
use Cwd qw(cwd);
use File::Spec::Functions qw(catfile);

use npg_qc::autoqc::results::insert_size;

use_ok('npg_qc::autoqc::parse::alignment');

my $s1 = catfile(cwd, q[t/data/autoqc/alignment.sam]);
my $num_aligned = 33;

my $result = npg_qc::autoqc::results::insert_size->new(id_run => 2, position => 1, path => q[t],);
$result->bin_width(1);
$result->min_isize(110);
$result->mean(148);
$result->std(16);
$result->quartile1(135);
$result->median(151);
$result->quartile3(154);
$result->bins([1,0,1,0,0,2,0,0,0,0,1,0,0,0,0,1,1,0,0,0,0,1,0,0,0,1,0,0,0,0,2,0,1,1,0,0,0,1,0,0,2,1,1,5,2,0,0,1,2,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,2]);
$result->num_well_aligned_reads($num_aligned);
$result->num_well_aligned_reads_opp_dir(undef);

{
  my $qc = npg_qc::autoqc::parse::alignment->new(files2parse => [$s1]);
  isa_ok($qc, 'npg_qc::autoqc::parse::alignment', 'is test with min constructor');
  throws_ok {npg_qc::autoqc::parse::alignment->new(files2parse => [q[non-existing]])}
        qr/Attribute \(files2parse\) does not pass the type constraint/, 'error when the first input file does not exist';
   throws_ok {npg_qc::autoqc::parse::alignment->new(files2parse => [$s1, q[non-existing]])}
        qr/Attribute \(files2parse\) does not pass the type constraint/, 'error when the second input file does not exist';
}

{
  my $qc = npg_qc::autoqc::parse::alignment->new(files2parse => [$s1]);
  is(scalar @{$qc->isizes_from_sam($s1)}, $num_aligned, 'num aligned reads returned');
  my $r = npg_qc::autoqc::results::insert_size->new(id_run => 2, position => 1, path => q[t],);
  is($qc->generate_insert_sizes($r), $num_aligned, 'num aligned reads returned');
  cmp_deeply ($r, $result, 'result object after parsing');
}

{
  my $qc = npg_qc::autoqc::parse::alignment->new(files2parse => [$s1, $s1]);
  my $r = npg_qc::autoqc::results::insert_size->new(id_run => 2, position => 1, path => q[t],);
  is($qc->generate_insert_sizes($r), $num_aligned, 'num aligned reads returned');
  $result->num_well_aligned_reads_opp_dir($num_aligned);
  cmp_deeply ($r, $result, 'result object after parsing');
}

SKIP: {
  skip('Bio::DB::Sam is not available', 4) 
            if !eval "require Bio::DB::Sam";
  my $b1 = $s1;
  $b1 =~ s/sam/bam/smx;
  my $qc = npg_qc::autoqc::parse::alignment->new(files2parse => [$b1]);
  is(scalar @{$qc->isizes_from_bam($b1)}, $num_aligned, 'num aligned reads returned - parse bam');
  is($qc->generate_insert_sizes(), $num_aligned, 'num aligned reads returned - parse bam');
  my $r = npg_qc::autoqc::results::insert_size->new(id_run => 2, position => 1, path => q[t],);
  is($qc->generate_insert_sizes($r), $num_aligned, 'num aligned reads returned - bam');
  cmp_deeply ($r, $result, 'result object after parsing - bam');
}

1;





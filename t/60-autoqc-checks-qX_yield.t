#########
# Author:        mg8
# Maintainer:    $Author$
# Created:       30 July 2009
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

use strict;
use warnings;
use Test::More tests => 13;
use Test::Deep;
use Test::Exception;
use Carp;
use English qw(-no_match_vars);

use npg_qc::autoqc::results::qX_yield;

our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/mx; $r; };

local $ENV{'NPG_WEBSERVICE_CACHE_DIR'} = q[t/data/autoqc];

use_ok('npg_qc::autoqc::checks::qX_yield');

{
    my $check = npg_qc::autoqc::checks::qX_yield->new(path => 't/data/autoqc/090721_IL29_2549/data', position =>1, id_run => 2549);
    isa_ok($check, 'npg_qc::autoqc::checks::qX_yield');
}


{
    my $qc = npg_qc::autoqc::checks::qX_yield->new(position => 2, path => 'nonexisting', id_run => 2549);
    throws_ok {$qc->execute()} qr/directory\ nonexisting\ does\ not\ exist/, 'execute: error on nonexisting path';
}


{
   my $check = npg_qc::autoqc::checks::qX_yield->new(
                                                      path      => 't/data/autoqc/090721_IL29_2549/data',
                                                      position  => 1,
                                                      id_run    => 2549
                                                     );
   $check->execute();
 
   my $e = npg_qc::autoqc::checks::qX_yield->new(
                                                 path      => 't/data/autoqc/090721_IL29_2549/data',
                                                 position  => 1,
                                                 id_run => 2549,
                                                 input_files => ['t/data/autoqc/090721_IL29_2549/data/2549_1_1.fastqcheck', 't/data/autoqc/090721_IL29_2549/data/2549_1_2.fastqcheck'],
                                                );
   $e->id_run;
   $e->result->pass(0);
   $e->result->threshold_quality(20);
   $e->result->threshold_yield1(1065789);
   $e->result->threshold_yield2(1065789);
   $e->result->yield1(469992);
   $e->result->yield2(469992);
   $e->result->filename1(q[2549_1_1.fastqcheck]);
   $e->result->filename2(q[2549_1_2.fastqcheck]);

   cmp_deeply($check->result, $e->result, 'result object for a paired run');
}

{
  local $ENV{'NPG_WEBSERVICE_CACHE_DIR'} = q[t/data/autoqc/qX_yield];

   my $check = npg_qc::autoqc::checks::qX_yield->new(
                                                      path      => 't/data/autoqc/090721_IL29_2549/data',
                                                      position  => 1,
                                                      id_run    => 2549
                                                     );
   $check->execute();
 
   my $e = npg_qc::autoqc::checks::qX_yield->new(
                                                 path      => 't/data/autoqc/090721_IL29_2549/data',
                                                 position  => 1,
                                                 id_run => 2549,
                                                 input_files => ['t/data/autoqc/090721_IL29_2549/data/2549_1_1.fastqcheck', 't/data/autoqc/090721_IL29_2549/data/2549_1_2.fastqcheck'],
                                                );
   $e->id_run;
   $e->result->pass(0);
   $e->result->threshold_quality(20);
   $e->result->threshold_yield1(3600000);
   $e->result->threshold_yield2(3600000);
   $e->result->yield1(469992);
   $e->result->yield2(469992);
   $e->result->filename1(q[2549_1_1.fastqcheck]);
   $e->result->filename2(q[2549_1_2.fastqcheck]);

   cmp_deeply($check->result, $e->result, 'result object for a paired run (as before, but HiSeq run)');
}

{
   my $check = npg_qc::autoqc::checks::qX_yield->new(
                                                      path      => 't/data/autoqc/090721_IL29_2549/data',
                                                      position  => 5,
                                                      id_run => 2549
                                                     );
   $check->execute();
 
   my $e = npg_qc::autoqc::checks::qX_yield->new(
                                                 path      => 't/data/autoqc/090721_IL29_2549/data',
                                                 position  => 5,
                                                 id_run => 2549,
                                                 input_files => ['t/data/autoqc/090721_IL29_2549/data/2549_5_1.fastqcheck', 't/data/autoqc/090721_IL29_2549/data/2549_5_2.fastqcheck'],
                                                );
   $e->id_run;
   $e->result->pass(0);
   $e->result->threshold_quality(20);
   $e->result->threshold_yield1(730263);
   $e->result->threshold_yield2(1065789);
   $e->result->yield1(42);
   $e->result->yield2(469992);
   $e->result->filename1(q[2549_5_1.fastqcheck]);
   $e->result->filename2(q[2549_5_2.fastqcheck]);

   cmp_deeply($check->result, $e->result, 'results for a paired run when one of the runs fails');
}


{
    my $check = npg_qc::autoqc::checks::qX_yield->new(
                                                      path      => 't/data/autoqc/090721_IL29_2549/data',
                                                      position  => 2,
                                                      id_run => 2549
                                                     );
   $check->execute();


   my $e = npg_qc::autoqc::checks::qX_yield->new(
                                                 path      => 't/data/autoqc/090721_IL29_2549/data',
                                                 position  => 2,
                                                 id_run => 2549,
                                                 input_files => ['t/data/autoqc/090721_IL29_2549/data/2549_2_1.fastqcheck'],
                                                );
   $e->id_run;

   $e->result->pass(0);
   $e->result->threshold_quality(20);
   $e->result->threshold_yield1(730263);
   $e->result->yield1(421225);
   $e->result->filename1(q[2549_2_1.fastqcheck]);

   cmp_deeply($check->result, $e->result, 'result object for a single end run');
}


{
   my $check = npg_qc::autoqc::checks::qX_yield->new({
                                                      path      => 't/data/autoqc/090721_IL29_2549/data',
                                                      position  => 4,
                                                      id_run => 2549
                                                     });
   $check->execute();

   my $e = npg_qc::autoqc::checks::qX_yield->new(
                                                 path      => 't/data/autoqc/090721_IL29_2549/data',
                                                 position  => 4,
                                                 id_run => 2549,
                                                 input_files => ['t/data/autoqc/090721_IL29_2549/data/2549_4_1.fastqcheck'],
                                                );
   $e->id_run;
   $e->result->pass(0);
   $e->result->threshold_quality(20);
   $e->result->threshold_yield1(730263);
   $e->result->yield1(42);
   $e->result->filename1(q[2549_4_1.fastqcheck]);

   cmp_deeply($check->result, $e->result, 'result object for a single end run for a check that does not pass');
}


{
   my $check = npg_qc::autoqc::checks::qX_yield->new({
                                                      path      => 't/data/autoqc/090721_IL29_2549/data',
                                                      position  => 6,
                                                      id_run => 2549
                                                     });

   $check->execute();

   my $e = npg_qc::autoqc::checks::qX_yield->new(
                                                 path      => 't/data/autoqc/090721_IL29_2549/data',
                                                 position  => 6,
                                                 id_run => 2549,
                                                 input_files => ['t/data/autoqc/090721_IL29_2549/data/2549_6_1.fastqcheck', 't/data/autoqc/090721_IL29_2549/data/2549_6_2.fastqcheck'],
                                                );
   $e->id_run;
   $e->result->pass(0);
   $e->result->threshold_quality(20);
   $e->result->threshold_yield1(1065789);
   $e->result->threshold_yield2(789474);
   $e->result->yield1(469992);
   $e->result->yield2(469992);
   $e->result->filename1(q[2549_6_1.fastqcheck]);
   $e->result->filename2(q[2549_6_2.fastqcheck]);

   cmp_deeply($check->result, $e->result, 'results for a paired run with diff num of cycles per run');
}


{
   my $check = npg_qc::autoqc::checks::qX_yield->new({
                                                      path      => 't/data/autoqc/090721_IL29_2549/data',
                                                      position  => 7,
                                                      id_run => 2549
                                                     });
   $check->execute();

   my $e = npg_qc::autoqc::checks::qX_yield->new(
                                                 path      => 't/data/autoqc/090721_IL29_2549/data',
                                                 position  => 7,
                                                 id_run => 2549,
                                                 input_files => ['t/data/autoqc/090721_IL29_2549/data/2549_7_1.fastqcheck'],
                                                );
   $e->id_run;
   $e->result->pass(0);
   $e->result->threshold_quality(20);
   $e->result->yield1(0);
   $e->result->filename1(q[2549_7_1.fastqcheck]);

   cmp_deeply ($check->result, $e->result, 'result for one empty fastq');
}


{
   my $check = npg_qc::autoqc::checks::qX_yield->new(
                                                      path      => 't/data/autoqc/090721_IL29_2549/data',
                                                      position  => 6,
                                                      id_run    => 2549,
                                                      tag_index => 1,
                                                     );

   $check->execute();

   my $e = npg_qc::autoqc::checks::qX_yield->new(
                                                 path      => 't/data/autoqc/090721_IL29_2549/data',
                                                 position  => 6,
                                                 id_run => 2549,
                                                 tag_index => 1,
                                                 input_files => ['t/data/autoqc/090721_IL29_2549/data/2549_6_1#1.fastqcheck', 't/data/autoqc/090721_IL29_2549/data/2549_6_2#1.fastqcheck'],
                                                );
   $e->id_run;
   $e->result->threshold_quality(20);
   $e->result->yield1(469992);
   $e->result->yield2(469992);
   $e->result->filename1(q[2549_6_1#1.fastqcheck]);
   $e->result->filename2(q[2549_6_2#1.fastqcheck]);

   cmp_deeply($check->result, $e->result, 'results for a paired run for tag No 1, no pass set');
}


{
   my $check = npg_qc::autoqc::checks::qX_yield->new(
                                                      position  => 4,
                                                      path      => 't/data/autoqc/090721_IL29_2549',
                                                      id_run    => 2549, 
                                                     );
   lives_ok {$check->execute} 'no error when input not found';

   my $e     = npg_qc::autoqc::checks::qX_yield->new(
                                                      position  => 4,
                                                      path      => 't/data/autoqc/090721_IL29_2549',
                                                      id_run    => 2549,
                                                      input_files => [],
                                                     );
   $e->result->comments(q[Neither t/data/autoqc/090721_IL29_2549/2549_4_1.fastqcheck no t/data/autoqc/090721_IL29_2549/2549_4.fastqcheck file found]);
   cmp_deeply($check->result, $e->result, 'results wheninput not found');
}




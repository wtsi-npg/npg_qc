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
use Test::More tests => 11;
use Test::Exception;
use Test::Deep;
use File::Temp qw/tempdir/;

use npg_qc::autoqc::checks::check;
use npg_qc::autoqc::checks::sequence_error;
use npg_qc::autoqc::results::result;

my $dir = tempdir( CLEANUP => 1);
my $repos = q[t/data/autoqc];


{
    my $check = npg_qc::autoqc::checks::check->new(
                                                      position  => 3,
                                                      path      => 't/data/autoqc/090721_IL29_2549/data',
                                                      id_run    =>  2549,
                                                 );
    delete $check->result->{info}->{Check_version};
    my $r =  npg_qc::autoqc::results::result->new (
                              position  => 3,
                              path      => 't/data/autoqc/090721_IL29_2549/data',
                              id_run    => 2549,
                              tag_index => undef,
                                                  );
    $r->set_info('Check', 'npg_qc::autoqc::checks::check');
                                  
    cmp_deeply($check->result, $r, 'result object created, default tag index');
}


{
    my $check = npg_qc::autoqc::checks::check->new(
                                                      position  => 3,
                                                      path      => 't/data/autoqc/090721_IL29_2549/data',
                                                      id_run    =>  2549,
                                                      tag_index => 5,
                                                 );
    delete $check->result->{info}->{Check_version};
    my $r =  npg_qc::autoqc::results::result->new (
                              position  => 3,
                              path      => 't/data/autoqc/090721_IL29_2549/data',
                              id_run    => 2549,
                              tag_index => 5,
                                                  );
    $r->set_info('Check', 'npg_qc::autoqc::checks::check');
                                  
    cmp_deeply($check->result, $r, 'result object created, tag index set');
}

{
  my $check = npg_qc::autoqc::checks::sequence_error->new({
                                                      position  => 1,
                                                      path      => 't/data/autoqc/090721_IL29_2549/data',
                                                      id_run    => 2549,
                                                      repository => $repos,
                                                     });
  is ($check->sequence_type, undef, 'sequence type unset');
  is ($check->result->sequence_type, undef, 'result sequence type unset');
}

{
  my $check = npg_qc::autoqc::checks::sequence_error->new({
                                                      position  => 1,
                                                      path      => 't/data/autoqc/090721_IL29_2549/data',
                                                      id_run    => 2549,
                                                      sequence_type => 'phix',
                                                      repository => $repos,
                                                     });
  is ($check->sequence_type, q[phix], 'sequence type is phix');
  is ($check->result->sequence_type, q[phix], 'result sequence type phix');
    
  my $forward  = q[t/data/autoqc/090721_IL29_2549/data/2549_1_1_phix.fastq];
  my $reverse  = q[t/data/autoqc/090721_IL29_2549/data/2549_1_2_phix.fastq];
  `touch $forward`;
  `touch $reverse`;
  is (join( q[ ], $check->get_input_files()), 't/data/autoqc/090721_IL29_2549/data/2549_1_1_phix.fastq t/data/autoqc/090721_IL29_2549/data/2549_1_2_phix.fastq', 'two fastqcheck input files found');
  cmp_deeply ($check->generate_filename_attr(), ['2549_1_1_phix.fastq', '2549_1_2_phix.fastq'], 'output filename structure');
  unlink $forward;
  unlink $reverse;
}

{
  my $check = npg_qc::autoqc::checks::sequence_error->new({
                                                      position  => 1,
                                                      path      => 't/data/autoqc/090721_IL29_2549/data',
                                                      id_run    => 2549,
                                                      repository => $repos,
                                                     });
  $check->result->write2file($dir, q[json]);
  ok (-e join(q[/], $dir, q[2549_1.sequence_error.json]), 'result file written');
}

{
  my $check = npg_qc::autoqc::checks::sequence_error->new({
                                                      position  => 1,
                                                      path      => 't/data/autoqc/090721_IL29_2549/data',
                                                      id_run    => 2549,
                                                      sequence_type => 'phix',
                                                      repository => $repos,
                                                     });
  $check->result->write2file($dir);
  ok (-e join(q[/], $dir, q[2549_1_phix.sequence_error.json]), 'phix type result file created');
}

{
  my $check = npg_qc::autoqc::checks::sequence_error->new({
                                                      position  => 1,
                                                      path      => 't/data/autoqc/090721_IL29_2549/data',
                                                      id_run    => 2549,
                                                      tag_index => 4,
                                                      sequence_type => 'phix',
                                                      repository => $repos,
                                                     });
  $check->result->write2file($dir);
  ok (-e join(q[/], $dir, q[2549_1#4_phix.sequence_error.json]), 'phix type result file created');
}

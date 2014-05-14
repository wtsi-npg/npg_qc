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
use Test::More tests => 70;
use Test::Exception;
use Test::Deep;
use File::Spec::Functions qw(catfile);
use t::autoqc_util;

our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/mx; $r; };


use_ok('npg_qc::autoqc::checks::check');

our $idrun = 2549;

{
    my $check = npg_qc::autoqc::checks::check->new(position => 2, path  => 't/data/autoqc/090721_IL29_2549/data', id_run => $idrun, file_type => 'bam');
    isa_ok($check, 'npg_qc::autoqc::checks::check');
    is($check->input_file_ext, 'bam', 'file type noted');
}

{
    throws_ok {npg_qc::autoqc::checks::check->new(path  => 't/data/autoqc/090721_IL29_2549/data', id_run => $idrun)}
           qr/Attribute \(position\) is required/, 'error on instantiating an object without a position attr';
    throws_ok {npg_qc::autoqc::checks::check->new(position => 17, path  => 't/data/autoqc/090721_IL29_2549/data', id_run => $idrun)}
           qr/Validation\ failed\ for\ \'NpgTrackingLaneNumber\'/, 'error on passing to the constructor invalid int as a position';
    throws_ok {npg_qc::autoqc::checks::check->new(position => 'dada', path  => 't/data/autoqc/090721_IL29_2549/data', id_run => $idrun)}
           qr/Validation\ failed\ for\ \'NpgTrackingLaneNumber\'/, 'error on passing to the constructor position as string';
    throws_ok {npg_qc::autoqc::checks::check->new(position => 1.2, path  => 't/data/autoqc/090721_IL29_2549/data', id_run => $idrun)}
           qr/Validation\ failed\ for\ \'NpgTrackingLaneNumber\'/, 'error on passing to the constructor position as a float';

    lives_ok {npg_qc::autoqc::checks::check->new(
                            position => 1,
                            path  => 't/data/autoqc/090721_IL29_2549/data',
                            id_run => $idrun,
                            tmp_path => 'nonexisting',
                                                 )}
           'no error on passing to the constructor non-existing temp directory if the  writes_tmp_files flag is not set';
    throws_ok {npg_qc::autoqc::checks::check->new(position => 2, id_run => $idrun)}
           qr/Attribute \(path\) is required/, 'error on instantiating an object without a path attr';
    lives_ok {npg_qc::autoqc::checks::check->new(position => 1, path  => 'nonexisting', id_run => $idrun)}
           'no error on passing to the constructor non-existing path';
    throws_ok {npg_qc::autoqc::checks::check->new(position => 2, path  => 'nonexisting')}
           qr/Attribute \(id_run\) is required/, 'error on instantiating an object without a run id';
    throws_ok {npg_qc::autoqc::checks::check->new(position => 1, path  => 'nonexisting', id_run => -1)}
           qr/Validation\ failed\ for\ \'NpgTrackingRunId\'/, 'error on passing to the constructor a negative run number';
    throws_ok {npg_qc::autoqc::checks::check->new(position => 1, path  => 'nonexisting', id_run => q[])}
           qr/Validation\ failed\ for\ \'NpgTrackingRunId\'/, 'error on passing to the constructor an empty string as a run number';
    lives_ok {npg_qc::autoqc::checks::check->new(position => 1, path  => 'nonexisting', id_run => 1)}
           'no error on passing to the constructor a positive run number';
    lives_ok {npg_qc::autoqc::checks::check->new(position => 1, path  => 'nonexisting', id_run => q[2])}
           'no error on passing to the constructor a string representing a positive run number';
}

{
    my $check = npg_qc::autoqc::checks::check->new(position => 2, path  => 't/data/autoqc/090721_IL29_2549/data', id_run => $idrun );
    is($check->tag_index, undef, 'tag index undefined');
    $check = npg_qc::autoqc::checks::check->new(position => 2, path  => 't/data/autoqc/090721_IL29_2549/data',
                                                id_run => $idrun, tag_index => 5 );
    is($check->tag_index, 5, 'tag index is set by the constructor');
    throws_ok { npg_qc::autoqc::checks::check->new(position => 2, path  => 't/data/autoqc/090721_IL29_2549/data',
                                                id_run => $idrun, tag_index => 1000000)}
           qr/Validation\ failed\ for/, 'error on passing to the constructor large tag index';
    throws_ok { npg_qc::autoqc::checks::check->new(position => 2, path  => 't/data/autoqc/090721_IL29_2549/data',
                                                id_run => $idrun, tag_index => -3)}
           qr/Validation\ failed\ for/, 'error on passing to the constructor negative tag index that is less than -1';
    throws_ok { npg_qc::autoqc::checks::check->new(position => 2, path  => 't/data/autoqc/090721_IL29_2549/data',
                                                id_run => $idrun, tag_index => 10.5)}
           qr/Validation\ failed\ for/, 'error on passing to the constructor tag index as a float';
    lives_ok { npg_qc::autoqc::checks::check->new(position => 2, path  => 't/data/autoqc/090721_IL29_2549/data', id_run => $idrun, tag_index => undef )} 'accepts undef for tag_index in the constructor';
}


{
    my $check = npg_qc::autoqc::checks::check->new(position => 2, path  => 't/data/autoqc/090721_IL29_2549/data', id_run => $idrun );
    throws_ok {$check->path('path')} qr/Cannot\ assign\ a\ value\ to\ a\ read-only/, 'check::path is read-only';
    throws_ok {$check->position(3)} qr/Cannot\ assign\ a\ value\ to\ a\ read-only/, 'check::position is read-only';
    throws_ok {$check->id_run(3)} qr/Cannot\ assign\ a\ value\ to\ a\ read-only/, 'check::id_run is read-only';
    lives_ok {$check->tag_index(3)} 'check::tag_index is writable';
}


{
    my $check = npg_qc::autoqc::checks::check->new(position => 2, path  => 't/data/autoqc/090721_IL29_2549/data', id_run => 2549);
    is($check->path,  't/data/autoqc/090721_IL29_2549/data', 'path getter ok');
    is($check->position,  2, 'position getter ok');
    is($check->id_run,  2549, 'id_run getter ok');
    is($check->can_run, 1, 'can_run getter ok');
    is($check->sequence_type, undef, 'sequence type unset');
}


{
    my $check = npg_qc::autoqc::checks::check->new(
                            position => 1,
                            path  => 't/data/autoqc/090721_IL29_2549/data',
                            id_run => $idrun,
                                                  );
    my $tmp_dir = $check->tmp_path;
    ok($tmp_dir =~ /^\/tmp\//smx, 'temp dir created in /tmp');
    ok(-e $tmp_dir, 'tmp directory created');
}


{
    my $check = npg_qc::autoqc::checks::check->new(
                            position => 1,
                            path  => 't/data/autoqc/090721_IL29_2549/data',
                            id_run => $idrun,
                            tmp_path => 't/data/autoqc',
                                                  );
    is($check->tmp_path, 't/data/autoqc', 'tmp dir is not created if the writes_tmp_files is not set');
}


{
  my $check = npg_qc::autoqc::checks::check->new(position => 1, path  => 'nonexisting', id_run    => 2549,);
  is ($check->tag_label, q[], 'empty string as a tag label');
  $check = npg_qc::autoqc::checks::check->new(position => 1, path  => 'nonexisting', id_run    => 2549, tag_index => 22);
  is ($check->tag_label, q[#22], 'tag label for tag_index 22');
}


{
    my $check = npg_qc::autoqc::checks::check->new({
                                                      position  => 1,
                                                      path      => 't/data/autoqc/090721_IL29_2549/data',
                                                      id_run    => 2549,
                                                 });

    is ($check->generate_filename(q[fastq])->[0], '2549_1.fastq', 'generate filename, no args');

    $check = npg_qc::autoqc::checks::check->new(
                                                      position  => 1,
                                                      path      => 't/data/autoqc/090721_IL29_2549/data',
                                                      id_run    => 2549,
                                                      input_file_ext => q[fastqcheck],
                                                );

    is ($check->generate_filename(q[fastqcheck], 2)->[0], '2549_1_2.fastqcheck', 'generate filename, full args, end 2');
    is ($check->generate_filename(q[fastqcheck], 1)->[0], '2549_1_1.fastqcheck', 'generate filename, full args, end 1');
    is ($check->generate_filename(q[fastqcheck], q[t])->[0], '2549_1_t.fastqcheck', 'generate filename, full args, end t');
    throws_ok {$check->generate_filename(q[fastqcheck], q[a])} qr/Unrecognised end string/, 'Unrecognised end string error';
    is ($check->generate_filename(q[fastqcheck])->[0], '2549_1.fastqcheck', 'generate filename, ext arg only');

    is (join( q[ ], $check->get_input_files()), 't/data/autoqc/090721_IL29_2549/data/2549_1_1.fastqcheck t/data/autoqc/090721_IL29_2549/data/2549_1_2.fastqcheck', 'two fastqcheck input files found');

    cmp_deeply ($check->generate_filename_attr(), ['2549_1_1.fastqcheck', '2549_1_2.fastqcheck'], 'output filename structure');
}

{
    my $check = npg_qc::autoqc::checks::check->new(
                                                      position  => 1,
                                                      path      => 't/data/autoqc/090721_IL29_2549/data',
                                                      id_run    => 2549,
                                                      tag_index => 33,
                                                 );

    is ($check->generate_filename(q[fastq])->[0],                '2549_1#33.fastq', 'generate filename, no args');
    is ($check->generate_filename(q[fastq], 1)->[0], '2549_1_1#33.fastq', 'generate filename, full args, end 1');

    $check = npg_qc::autoqc::checks::check->new(
                                                      position  => 1,
                                                      path      => 't/data/autoqc/090721_IL29_2549/data',
                                                      id_run    => 2549,
                                                      tag_index => 33,
                                                      input_file_ext => q[fastqcheck],
                                               );
    is ($check->generate_filename(q[fastqcheck], 2)->[0], '2549_1_2#33.fastqcheck', 'generate filename, full args, end 2');
    is ($check->generate_filename(q[fastqcheck])->[0], '2549_1#33.fastqcheck', 'generate filename, ext arg only');

    is (join( q[ ], $check->get_input_files()), 't/data/autoqc/090721_IL29_2549/data/2549_1_1#33.fastqcheck t/data/autoqc/090721_IL29_2549/data/2549_1_2#33.fastqcheck', 'two fastqcheck input files found');
}


{
    my $check = npg_qc::autoqc::checks::check->new({
                                                      position  => 1,
                                                      path      => 't/data/autoqc/090721_IL29_2549/data',
                                                      id_run    => 2549,
                                                      sequence_type => 'phix',
                                                 });
    is ($check->sequence_type, q[phix], 'sequence type is phix');
    
    is ($check->generate_filename(q[fastq])->[0], '2549_1_phix.fastq', 'generate filename, no args');
    is ($check->generate_filename(q[fastq], 2)->[0], '2549_1_2_phix.fastq', 'generate filename, full args, end 2');
    is ($check->generate_filename(q[fastq], 1)->[0], '2549_1_1_phix.fastq', 'generate filename, full args, end 1');
    is ($check->generate_filename(q[fastq], q[t])->[0], '2549_1_t_phix.fastq', 'generate filename, full args, end t');
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
    my $check = npg_qc::autoqc::checks::check->new(
                                                      position  => 1,
                                                      path      => 't/data/autoqc/090721_IL29_2549/data',
                                                      id_run    => 2549,
                                                      tag_index => 33,
                                                      sequence_type => 'phix',
                                                 );

    is ($check->generate_filename(q[fastq])->[0], '2549_1#33_phix.fastq', 'generate filename, no args');
    is ($check->generate_filename(q[fastq], 1)->[0], '2549_1_1#33_phix.fastq', 'generate filename, full args, end 1');
}


{

    my $check = npg_qc::autoqc::checks::check->new({
                                                      position  => 2,
                                                      path      => 't/data/autoqc/090721_IL29_2549/data',
                                                      id_run    => 2549,
                                                      input_file_ext => q[fastqcheck],
                                                 });
    is (join( q[ ], $check->get_input_files()), 't/data/autoqc/090721_IL29_2549/data/2549_2_1.fastqcheck', 'one fastqcheck input files found; with _1 to identify the end');
}


{
    my $check = npg_qc::autoqc::checks::check->new({
                                                      position  => 3,
                                                      path      => 't/data/autoqc/090721_IL29_2549/data',
                                                      id_run    => 2549,
                                                 });
    is (join( q[ ], $check->get_input_files()), 't/data/autoqc/090721_IL29_2549/data/2549_3.fastq', 'one fastqcheck input files found; no _1 to identify the end');

    $check = npg_qc::autoqc::checks::check->new({
                                                      position  => 2,
                                                      path      => 't/data/autoqc/090721_IL29_2549/data',
                                                      id_run    => 2549,
                                                      input_file_ext => q[bam],
                                                 });
    is (join( q[ ], $check->get_input_files()), 't/data/autoqc/090721_IL29_2549/data/2549_2.bam', 'bam file for a lane found');

    $check =    npg_qc::autoqc::checks::check->new(
                                                      path      => 't/data/autoqc/090721_IL29_2549/data',
                                                      position  => 6,
                                                      id_run    => 2549,
                                                      tag_index => 1,
                                                      input_file_ext => q[bam],
                                                  );
    is (join( q[ ], $check->get_input_files()), 't/data/autoqc/090721_IL29_2549/data/2549_6#1.bam', 'bam file for a plex found');
}


{
    my $check = npg_qc::autoqc::checks::check->new(
                                                      position  => 4,
                                                      path      => 't/data/autoqc/090721_IL29_2549/data',
                                                      id_run    => 2549,
                                                  );

    is(scalar $check->get_input_files(), 0, 'no input files found');
    is(scalar @{$check->input_files}, 0, 'no input files found');
    my $result;
    lives_ok { $result = $check->execute } 'no error when no input files found';
    is ($result, 0, 'execute returns zero when input not found');
    is ($check->result->comments, 'Neither t/data/autoqc/090721_IL29_2549/data/2549_4_1.fastq no t/data/autoqc/090721_IL29_2549/data/2549_4.fastq file found', 'comment when no input files found');
}


{
    my $check = npg_qc::autoqc::checks::check->new(position => 1, path => q[], id_run    => 2549);
    throws_ok {$check->execute()} qr/No\ input\ files\ directory/, 'execute: error if the path is not defined';
}


{
    my $check = npg_qc::autoqc::checks::check->new(position => 1, path  => 'nonexisting', id_run    => 2549,);
    throws_ok {$check->execute()} qr/directory\ nonexisting\ does\ not\ exist/, 'execute: error on nonexisting path';
}

{
  my $check = npg_qc::autoqc::checks::check->new(position => 1, path  => 'nonexisting', id_run    => 2549,);
  like($check->result->get_info('Check'), qr{npg_qc::autoqc::checks::check}, 'check name and version number in the info');
  like($check->result->get_info('Check_version'), qr/^\d+$/, 'check version exists and is a number');
}

1;

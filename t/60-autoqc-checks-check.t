use strict;
use warnings;
use Test::More tests => 11;
use Test::Exception;
use Test::Deep;
use File::Spec::Functions qw(catfile);
use File::Temp qw/tempdir/;
use t::autoqc_util;

use_ok('npg_qc::autoqc::checks::check');
use_ok('npg_qc::autoqc::results::result');

my $idrun = 2549;
my $path = 't/data/autoqc/090721_IL29_2549/data';
my $tdir = tempdir( CLEANUP => 1 );

subtest 'object creation' => sub {
    plan tests => 2;
    my $check = npg_qc::autoqc::checks::check->new(
      position  => 2,
      qc_in     => $path,
      id_run    => $idrun,
      file_type => 'bam');
    isa_ok($check, 'npg_qc::autoqc::checks::check');
    is($check->file_type, 'bam', 'file type noted');
};

subtest 'validation of attributes' => sub {
    plan tests => 20;

    throws_ok {npg_qc::autoqc::checks::check->new(path => $path, id_run => $idrun)}
        qr/Attribute \(position\) is required/,
        'error on instantiating an object without a position attr';
    throws_ok {npg_qc::autoqc::checks::check->new(
        position => 17, path => $path, id_run => $idrun)}
        qr/Validation\ failed\ for\ \'NpgTrackingLaneNumber\'/,
        'error on passing to the constructor invalid int as a position';
    throws_ok {npg_qc::autoqc::checks::check->new(
        position => 'dada', path => $path, id_run => $idrun)}
        qr/Validation\ failed\ for\ \'NpgTrackingLaneNumber\'/,
        'error on passing to the constructor position as string';
    throws_ok {npg_qc::autoqc::checks::check->new(
        position => 1.2, path => $path, id_run => $idrun)}
        qr/Validation\ failed\ for\ \'NpgTrackingLaneNumber\'/,
        'error on passing to the constructor position as a float';

    lives_ok {npg_qc::autoqc::checks::check->new(
                            position => 1,
                            qc_in    => $path,
                            id_run   => $idrun,
                            tmp_path => 'nonexisting')}
        'no error for non-existing temp directory if the  writes_tmp_files flag is not set';

    lives_ok {npg_qc::autoqc::checks::check->new(position => 2, id_run => $idrun)}
        'no error on instantiating an object without a path/qc_in attr';
    throws_ok {npg_qc::autoqc::checks::check->new(
        position => 1, path => 'nonexisting', id_run => $idrun)}
        qr/does not exist or is not readable/,
        'error on passing to the constructor non-existing path';
    throws_ok {npg_qc::autoqc::checks::check->new(position => 2, path => 'nonexisting')}
        qr/Attribute \(id_run\) is required/,
        'error on instantiating an object without a run id';
    throws_ok {npg_qc::autoqc::checks::check->new(
        position => 1, path => 'nonexisting', id_run => -1)}
        qr/Validation\ failed\ for\ \'NpgTrackingRunId\'/,
        'error on passing to the constructor a negative run number';
    throws_ok {npg_qc::autoqc::checks::check->new(
        position => 1, path => 'nonexisting', id_run => q[])}
        qr/Validation\ failed\ for\ \'NpgTrackingRunId\'/,
        'error on passing to the constructor an empty string as a run number';
    lives_ok {npg_qc::autoqc::checks::check->new(
        position => 1, path => 't', id_run => 1)}
        'no error on passing to the constructor a positive run number';
    lives_ok {npg_qc::autoqc::checks::check->new(
        position => 1, path => 't', id_run => q[2])}
        'no error on passing to the constructor a string representing a positive run number';

    throws_ok { npg_qc::autoqc::checks::check->new(position => 2, path => $path,
        id_run => $idrun, tag_index => 1000000)}
        qr/Validation\ failed\ for/,
        'error on passing to the constructor large tag index';
    throws_ok { npg_qc::autoqc::checks::check->new(
        position => 2, path => $path, id_run => $idrun, tag_index => -3)}
        qr/Validation\ failed\ for/,
        'error on passing to the constructor negative tag index that is less than -1';
    throws_ok { npg_qc::autoqc::checks::check->new(
         position => 2, path => $path, id_run => $idrun, tag_index => 10.5)}
        qr/Validation\ failed\ for/,
        'error on passing to the constructor tag index as a float';
    throws_ok { npg_qc::autoqc::checks::check->new(
        position => 2, path => $path, id_run => $idrun, tag_index => undef )}
        qr/Validation\ failed\ for\ \'NpgTrackingTagIndex\'/,
        'does not accept undef for tag_index in the constructor';

    my $check = npg_qc::autoqc::checks::check->new(
        position => 2, path => $path, id_run => $idrun );
    throws_ok {$check->path('path')}
        qr/Cannot\ assign\ a\ value\ to\ a\ read-only/, 'check::path is read-only';
    lives_ok {$check->position(3)} 'check::position is read-write';
    throws_ok {$check->id_run(3)}
        qr/Cannot\ assign\ a\ value\ to\ a\ read-only/, 'check::id_run is read-only';
    lives_ok {$check->tag_index(3)} 'check::tag_index is writable';
};

subtest 'accessors tests' => sub {
    plan tests => 20;

    my $check = npg_qc::autoqc::checks::check->new(
        position => 2, path => $path, id_run => $idrun );
    is($check->tag_index, undef, 'tag index undefined');
    isa_ok($check->result, 'npg_qc::autoqc::results::result');
    is($check->result->id_run, $idrun, 'run id propagated');
    is($check->result->position, 2, 'position propagated');
    is($check->result->path, 't/data/autoqc/090721_IL29_2549/data', 'path propagated');
    is($check->result->tag_index, undef, 'tag index undefined');
    ok(!$check->result->has_tag_index, 'tag index is not set');

    $check = npg_qc::autoqc::checks::check->new( position => 3, path => $path, id_run =>  2549);
    delete $check->result->{info}->{Check_version};
    my $r =  npg_qc::autoqc::results::result->new(position=> 3, path => $path, id_run => 2549);
    $r->set_info('Check', 'npg_qc::autoqc::checks::check');          
    cmp_deeply($check->result, $r, 'result object created, default tag index');

    $check = npg_qc::autoqc::checks::check->new(
        position => 2, path  => $path, id_run => $idrun, tag_index => 5 );
    is($check->tag_index, 5, 'tag index is set by the constructor');
    isa_ok($check->result, 'npg_qc::autoqc::results::result');
    is($check->result->id_run, $idrun, 'run id propagated');
    is($check->result->position, 2, 'position propagated');
    is($check->result->tag_index, 5, 'tag index propagated');
    ok($check->result->has_tag_index, 'tag index is set');

    $check = npg_qc::autoqc::checks::check->new(position => 2, path => $path, id_run => 2549);
    is($check->path, $path, 'path getter ok');
    is($check->position,  2, 'position getter ok');
    is($check->id_run,  2549, 'id_run getter ok');
    is($check->can_run, 1, 'can_run getter ok');

    $check = npg_qc::autoqc::checks::check->new(
        position => 1, path => 't', id_run => 2549,);
    is ($check->tag_label, q[], 'empty string as a tag label');
    $check = npg_qc::autoqc::checks::check->new(
        position => 1, path => 't', id_run => 2549, tag_index => 22);
    is ($check->tag_label, q[#22], 'tag label for tag_index 22');
};

subtest 'input and output directories' => sub {
    plan tests => 3;

    my $check = npg_qc::autoqc::checks::check->new(
                            position => 1,
                            qc_in    => $tdir,
                            id_run   => $idrun);
    is($check->qc_out, $tdir, 'qc out is built');
    $check = npg_qc::autoqc::checks::check->new(
                            position => 1,
                            qc_out   => $tdir,
                            id_run   => $idrun);
    is($check->qc_in, '/dev/stdin', 'qc in defaults to standard in');
    $check = npg_qc::autoqc::checks::check->new(
                            position => 1,
                            id_run   => $idrun);
    throws_ok {$check->qc_out}
      qr/qc_out should be defined/,
      'output directory is required in input is not given';     
};

subtest 'temporary directory and path tests' => sub {
    plan tests => 3;

    my $check = npg_qc::autoqc::checks::check->new(
                            position => 1,
                            qc_in    => $path,
                            id_run   => $idrun);
    my $tmp_dir = $check->tmp_path;
    ok($tmp_dir =~ /^\/tmp\//smx, 'temp dir created in /tmp');
    ok(-e $tmp_dir, 'tmp directory created');

    $check = npg_qc::autoqc::checks::check->new(
                            position => 1,
                            qc_in    => $path,
                            id_run   => $idrun,
                            tmp_path => 't/data/autoqc');
    is($check->tmp_path, 't/data/autoqc', 'tmp dir as set');
};

subtest 'finding input' => sub {
    plan tests => 12;

    my $check = npg_qc::autoqc::checks::check->new(
                position  => 1,
                qc_in     => $path,
                id_run    => 2549,
                file_type => q[fastqcheck]);
    is (join( q[ ], $check->get_input_files()),
        "$path/2549_1_1.fastqcheck $path/2549_1_2.fastqcheck",
        'two fastqcheck input files found');
    cmp_deeply ($check->generate_filename_attr(), ['2549_1_1.fastqcheck', '2549_1_2.fastqcheck'],
        'output filename structure');

    $check = npg_qc::autoqc::checks::check->new(
                position  => 1,
                path      => $path,
                id_run    => 2549,
                tag_index => 33,
                file_type => q[fastqcheck]);
    is (join( q[ ], $check->get_input_files()),
        "$path/2549_1_1#33.fastqcheck $path/2549_1_2#33.fastqcheck",
        'two fastqcheck input files found');

    $check = npg_qc::autoqc::checks::check->new(
                position  => 2,
                path      => $path,
                id_run    => 2549,
                file_type => q[fastqcheck]);
    is (join( q[ ], $check->get_input_files()), "$path/2549_2_1.fastqcheck",
        'one fastqcheck input files found; with _1 to identify the end');

    $check = npg_qc::autoqc::checks::check->new(
                position  => 3,
                path      => $path,
                id_run    => 2549);
    is (join( q[ ], $check->get_input_files()), "$path/2549_3.fastq",
        'one fastqcheck input files found; no _1 to identify the end');

    $check = npg_qc::autoqc::checks::check->new(
                position  => 2,
                path      => $path,
                id_run    => 2549,
                file_type => q[bam]);
    is (join( q[ ], $check->get_input_files()), "$path/2549_2.bam", 'bam file for a lane found');

    $check =    npg_qc::autoqc::checks::check->new(
                path      => $path,
                position  => 6,
                id_run    => 2549,
                tag_index => 1,
                file_type => q[bam]);
    is (join( q[ ], $check->get_input_files()), "$path/2549_6#1.bam",
        'bam file for a plex found');

    $check = npg_qc::autoqc::checks::check->new(
                position  => 4,
                path      => $path,
                id_run    => 2549);
    is(scalar $check->get_input_files(), 0, 'no input files found');
    is(scalar @{$check->input_files}, 0, 'no input files found');
    my $result;
    lives_ok { $result = $check->execute } 'no error when no input files found';
    is ($result, 0, 'execute returns zero when input not found');
    is ($check->result->comments,
        "Neither $path/2549_4_1.fastq nor $path/2549_4.fastq file found",
        'comment when no input files found');
};

subtest 'saving info about the check' => sub {
    plan tests => 2;

    my $check = npg_qc::autoqc::checks::check->new(
        position => 1, path => 't', id_run => 2549,);
    like($check->result->get_info('Check'), qr{npg_qc::autoqc::checks::check},
        'check name and version number in the info');
    ok($check->result->get_info('Check_version'), 'check version exists and is a number');
};

subtest 'filename generation' => sub {
    plan tests => 13;

    my $p = 'npg_qc::autoqc::checks::check';
    my $m = {id_run => 5, position => 1};
    is($p->create_filename($m), '5_1', '5_1');
    is($p->create_filename($m, 1), '5_1_1', '5_1_1');
    is($p->create_filename($m, 't'), '5_1_t', '5_1_t');
    is($p->create_filename($m, 2), '5_1_2', '5_1_2');
    $m->{'tag_index'} = '3';
    is($p->create_filename($m), '5_1#3', '5_1 tag 3');
    is($p->create_filename($m,1), '5_1_1#3', '5_1_1 tag 3');
    is($p->create_filename($m,2), '5_1_2#3', '5_1_2 tag 3');
    $m->{'tag_index'} = 0;
    is($p->create_filename($m), '5_1#0', '5_1 tag 0');
    is($p->create_filename($m,1), '5_1_1#0', '5_1_1 tag 0');
    is($p->create_filename($m,2), '5_1_2#0', '5_1_2 tag 0');

    my $check = npg_qc::autoqc::checks::check->new(position => 1, path => 't', id_run => 2549,);
    is($check->create_filename($check), '2549_1', q[file name for 2549_1]);
    $check = npg_qc::autoqc::checks::check->new(
        position => 1, path => 't', id_run => 2549, tag_index => 0);
    is($check->create_filename($check), '2549_1#0', q[file name for 2549_1 tag 0]);
    $check = npg_qc::autoqc::checks::check->new(
        position => 1, path => 't', id_run => 2549, tag_index => 5);
    is($check->create_filename($check), '2549_1#5', q[file name for 2549_1 tag 5]);
};

subtest 'running the check' => sub {
    plan tests => 6;

    my $check = npg_qc::autoqc::checks::check->new(
                id_run    => 2549,
                position  => 1,
                file_type => q[fastqcheck],
                qc_in     => $path,
                qc_out    => $tdir);
    is($check->can_run(), 1, 'can run');
    $check->run();
    isa_ok($check->result(), 'npg_qc::autoqc::results::result');
    my $jpath = "$tdir/2549_1.result.json";
    ok(-e $jpath, 'output json file exists');
    my $result = npg_qc::autoqc::results::result->load($jpath);
    isa_ok($result, 'npg_qc::autoqc::results::result');
    is($result->id_run, 2549, 'run id');
    is($result->position, 1, 'position');
};

1;

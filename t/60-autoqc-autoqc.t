use strict;
use warnings;
use Test::More tests => 54;
use Test::Deep;
use Test::Exception;
use File::Path;
use File::Spec;
use File::Spec::Functions qw(catfile);
use Cwd;
use File::Temp qw/tempdir/;
local $ENV{'HOME'} = q[t/data];

use_ok ('npg_qc::autoqc::autoqc');

$ENV{NPG_WEBSERVICE_CACHE_DIR} = q[t/data/autoqc];
my $cdir = cwd();
local $ENV{'PATH'} = join q[:], qq[$cdir/blib/script] , $ENV{'PATH'};

my $simple_check = q[qX_yield];
my $ref = q[t/data/autoqc];

{
  my $qc = npg_qc::autoqc::autoqc->new(check => $simple_check, archive_path => q[t], id_run => 4, qc_path => q[t/data], position => 1);
  isa_ok($qc, 'npg_qc::autoqc::autoqc');
}

{
  my $id_run = 2222;
  my $qc_subpath = q[t/data];
  my $archive_subpath = q[t];

  throws_ok {
     npg_qc::autoqc::autoqc->new(archive_path => $archive_subpath, id_run => $id_run, qc_path => $qc_subpath, position => 1)
  } qr/is required/, 'error when not setting the check name through the constructor';

  my $qc = npg_qc::autoqc::autoqc->new(check => q[split_stats], archive_path => $archive_subpath, id_run => $id_run, qc_path => $qc_subpath, position => 1);
  throws_ok { $qc->can_run() } qr/Can't locate/, 'split-stats check: unable to invoke a method that has to create a check object';
}


{
  my $id_run = 2222;
  my $qc_subpath = q[t/data];
  my $archive_subpath = q[t];

  my $qc = npg_qc::autoqc::autoqc->new(check => $simple_check, archive_path => $archive_subpath, id_run => $id_run, qc_path => $qc_subpath, position => 1);

  throws_ok { $qc->check('insert_size') } qr/Cannot assign a value to a read-only accessor/, 'error when re-setting check name';
  throws_ok { $qc->position(3) } qr/Cannot assign a value to a read-only accessor/, 'error when re-setting position';
}


{
    my $id_run = 2222;
    my $qc_subpath = q[t/data];
    my $archive_subpath = q[t];

    throws_ok {npg_qc::autoqc::autoqc->new(check => $simple_check, archive_path => $archive_subpath, id_run => $id_run, qc_path => $qc_subpath)}
              qr/is required/, 'error when position is not supplied in the constructor';
}


{
    my $id_run = 2222;
    my $archive_subpath = q[t/data/autoqc];

    throws_ok {npg_qc::autoqc::autoqc->new(
   check => $simple_check, archive_path => $archive_subpath, id_run => $id_run, position => 1, tag_index => -2)->run}
              qr/Validation\ failed\ for/, 'error when illegal tag index is used';
    my $qc = npg_qc::autoqc::autoqc->new(check => $simple_check, archive_path => $archive_subpath, id_run => $id_run, position => 1, tag_index => 2);
    is ($qc->tag_index, 2, 'tag index is set OK');
    is ($qc->qc_in, q[t/data/autoqc/lane1], 'input dir for split files');
    is ($qc->qc_out, q[t/data/autoqc/lane1/qc], 'output dir for split files');
}


{
    my $id_run = 2222;
    my $qc_subpath = q[t/data];
    my $archive_subpath = q[t];

    my $qc = npg_qc::autoqc::autoqc->new(check => $simple_check, archive_path => $archive_subpath, id_run => $id_run, qc_path => $qc_subpath, position => 1);
    is($qc->id_run, $id_run, 'id_run as set');
    is($qc->qc_path, $qc_subpath, 'qc subdirectory as set');
    is($qc->archive_path, $archive_subpath, 'archive directory as set');

    is($qc->qc_in, $archive_subpath, 'qc_in set correctly');
    is($qc->qc_out, $qc_subpath, 'qc_out set correctly');
}


{
    my $id_run = 2222;
    my $path = catfile(cwd, q[t/data/autoqc], q[123456_IL2_2222/Data/Intensities/Bustard-2009-10-01/PB_cal/archive]);
    my $odir = catfile($path, q[qc]);
    if(!-e $odir) { File::Path::mkpath($odir); }
    my $qc = npg_qc::autoqc::autoqc->new(check => $simple_check, archive_path => $path, position => 1);
    is($qc->id_run, $id_run, 'id_run from an archive subpath');
    is($qc->qc_path, $odir, 'qc subdirectory from an archive subpath');
    is($qc->runfolder_path, catfile(cwd, q[t/data/autoqc/123456_IL2_2222]), 'runfolder directory from an archive subpath');
     File::Path::rmtree($odir);
}


{
    my $id_run = 2222;
    my $path = catfile(cwd, q[t/data/autoqc], q[123456_IL2_2222/Data/Intensities/Bustard-2009-10-01/PB_cal/archive]);

    my $qc = npg_qc::autoqc::autoqc->new(check => $simple_check, archive_path => $path, position => 1, qc_path => q[t]);
    is($qc->id_run, $id_run, 'id_run from an archive subpath when qc_path is valid');
    is($qc->qc_path, q[t], 'qc path as given');
    is($qc->qc_out, q[t], 'qc_out from qc_path');
    is($qc->runfolder_path, catfile(cwd, q[t/data/autoqc/123456_IL2_2222]), 'runfolder directory from an archive subpath when qc_path is invalid ');

    $qc = npg_qc::autoqc::autoqc->new(check => $simple_check, archive_path => $path,
                                      position => 1, qc_path => q[t], qc_out => q[t/data]);
    is($qc->qc_out, q[t/data], 'qc_out as given');
    is($qc->qc_in, $path, 'qc_in from archive path');

    $qc = npg_qc::autoqc::autoqc->new(check => $simple_check, archive_path => $path,
                                      position => 1, qc_path => q[t], qc_out => q[t/data], qc_in => q[t/data/autoqc],);
    is($qc->qc_out, q[t/data], 'qc_out as given');
    is($qc->qc_in,  q[t/data/autoqc], 'qc_in from archive path');

    $qc = npg_qc::autoqc::autoqc->new(check => $simple_check, archive_path => $path, qc_path => q[t],
                                      position => 1, qc_in => q[t/data/autoqc],);
    is($qc->qc_out, q[t/data/autoqc], 'qc_out from qc_in');
    is($qc->qc_in,  q[t/data/autoqc], 'qc_in from archive path');
}

{
    throws_ok {npg_qc::autoqc::autoqc->new(check => $simple_check, id_run => 22, position => 1, qc_in => q[m]) } qr/Input qc directory m does not exist/, 'error when qc_in does not exist' ;
    throws_ok {npg_qc::autoqc::autoqc->new(check => $simple_check, id_run => 23, position => 1, qc_in => q[t], qc_out => q[m],) } qr/Output qc directory m does not exist/, 'error when qc_out does not exist' ;
    my $qc = npg_qc::autoqc::autoqc->new(check => $simple_check, id_run => 22, position => 1, qc_in => q[t], qc_out => q[t/data],);
    is ($qc->qc_in, q[t], 'qc_in set as supplied');
    is ($qc->qc_out, q[t/data], 'qc_out set as supplied');
    $qc = npg_qc::autoqc::autoqc->new(check => $simple_check, id_run => 22, position => 1, qc_in => q[t],);
    is ($qc->qc_in, q[t], 'qc_in set as supplied');
    is ($qc->qc_out, $qc->qc_in, 'qc_out set to qc_in when not supplied');
}


{
    my $id_run = 2222;
    my $qc_subpath = q[t/data];
    my $archive_subpath = q[t];

    my $qc = npg_qc::autoqc::autoqc->new(archive_path => $archive_subpath, id_run => $id_run, qc_path => $qc_subpath, position => 1, check=>'insert_size' );
    is ($qc->position, 1, 'position set by the constructor');
    is ($qc->check, 'insert_size', 'test name set by the constructor');
}


{
    my $id_run = 2222;
    my $qc_subpath = q[t];
    my $archive_subpath = q[t];

    my $qc = npg_qc::autoqc::autoqc->new(
          archive_path => $archive_subpath,
          id_run =>       2222,
          qc_path =>      $qc_subpath,
          position =>     1,
          check =>        q[qX_yield]
    );
    is($qc->can_run(), 1, 'can_run returns 1 for the qX_Yield check');

    $qc = npg_qc::autoqc::autoqc->new(
          archive_path => $archive_subpath,
          id_run =>       1937,
          qc_path =>      $qc_subpath,
          position =>     1,
          check =>        q[insert_size],
          repository => $ref,
    );
    is($qc->can_run(), 1, 'can_run returns 1 for the insert size check for a paired run');

    $qc = npg_qc::autoqc::autoqc->new(
          archive_path => $archive_subpath,
          id_run =>       3612,
          qc_path =>      $qc_subpath,
          position =>     1,
          check =>        q[insert_size],
          repository => $ref,
    );
    is($qc->can_run(), 0, 'can_run returns 0 for the insert size check for a single run');
}

{
    my $id_run = 2222;
    my $qc_subpath = q[t];
    my $archive_subpath = q[t];

    my $qc = npg_qc::autoqc::autoqc->new(
          archive_path => $archive_subpath,
          id_run =>       2222,
          qc_path =>      $qc_subpath,
          position =>     1,
          check =>        q[insert_size],
          strain =>       q[dodo],
          species =>      q[frog],
          reference_genome  => q[some genome],
          repository => $ref,
    );

    my $check = $qc->_create_test_object();
    is($check->strain, q[dodo], 'strain set for the check object');
    is($check->species, q[frog], 'species set for the check object');
    is($check->reference_genome, q[some genome], 'species set for the check object');
    ok(!defined $check->tag_index, 'tag index not defined');
}

{
    my $id_run = 2222;
    my $path = tempdir( CLEANUP => 1 );
    my $lane_path = $path . q[/lane1];
    mkdir $lane_path;

    my $qc = npg_qc::autoqc::autoqc->new(
          archive_path => $path,
          id_run =>       2222,
          qc_out =>       $path,
          position =>     1,
          tag_index =>    0,
          check =>        q[insert_size],
          repository => $ref,
    );

    my $check = $qc->_create_test_object();
    ok(defined $check->tag_index, 'tag index defined');
    is($check->tag_index, 0, 'tag index 0');
    is($check->file_type, 'fastq', 'default fastq file type propagated');

    $qc = npg_qc::autoqc::autoqc->new(
          archive_path => $path,
          id_run =>       2222,
          qc_out =>       $path,
          position =>     1,
          tag_index =>    5,
          check =>        q[insert_size],
          repository => $ref,
          file_type =>    'bam',
    );

    $check = $qc->_create_test_object();
    ok(defined $check->tag_index, 'tag index defined');
    is($check->tag_index, 5, 'tag index 5');
    is($check->file_type, 'bam', 'bam file type propagated');
}

{
    my $id_run = 2222;
    my $path = tempdir( CLEANUP => 1 );
    my $lane_path = $path . q[/lane1];
    mkdir $lane_path;

    my $qc = npg_qc::autoqc::autoqc->new(
          id_run =>       2549,
          qc_out =>       $path,
          qc_in => 't/data/autoqc/090721_IL29_2549/data',
          position =>     6,
          tag_index =>    2,
          check =>        q[verify_bam_id],
    );

    my $check = $qc->_create_test_object();
    ok(defined $check->tag_index, 'tag index defined');
    is($check->tag_index, 2, 'tag index 2');
    is($check->file_type, 'bam', 'filetype is bam');

    is($check->bam_file, 't/data/autoqc/090721_IL29_2549/data/2549_6#2.bam', 'bam file correct');
}

1;

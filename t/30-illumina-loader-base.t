use strict;
use warnings;
use Test::More tests => 10;
use Test::Exception;
use File::Temp qw(tempdir);
use File::Path qw/ make_path /;
use Moose::Meta::Class;
use npg_testing::db;

use_ok(q{npg_qc::illumina::loader::base});

local $ENV{'dev'} = 'test';
my $schema = Moose::Meta::Class->create_anon_class(
  roles => [qw/npg_testing::db/])
  ->new_object({ config_file => q[t/data/config.ini],})
  ->deploy_test_db(q[npg_qc::Schema],q[t/data/fixtures]);

{
  #test for paird run
  my $loader;

  my $runfolder_path = qq{t/data/nfs/sf44/IL6/outgoing/100125_IL6_4308};

  my $basedir = tempdir( CLEANUP => 1 );
  my $fs_run_folder = qq[$basedir/IL6/outgoing];
  make_path($fs_run_folder);
  system('cp', '-rp', $runfolder_path, $fs_run_folder);
  $fs_run_folder = qq[$fs_run_folder/100125_IL6_4308];
  my $fh;
  my $runinfofile = qq[$fs_run_folder/RunInfo.xml];
  open($fh, '>', $runinfofile) or die "Could not open file '$runinfofile' $!";
  print $fh <<"ENDXML";
<?xml version="1.0"?>
<RunInfo xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" Version="3">
<Run>
  <Reads>
  <Read Number="1" NumCycles="75" IsIndexedRead="N" />
  <Read Number="2" NumCycles="8" IsIndexedRead="N" />
  <Read Number="3" NumCycles="8" IsIndexedRead="N" />
  <Read Number="4" NumCycles="75" IsIndexedRead="N" />
  </Reads>
  <FlowcellLayout LaneCount="8" SurfaceCount="2" SwathCount="1" TileCount="60">
  </FlowcellLayout>
</Run>
</RunInfo>
ENDXML
  close $fh;

  lives_ok { $loader = npg_qc::illumina::loader::base->new(
    runfolder_path => $fs_run_folder,
    schema         => $schema)
  } q{loader object creation ok};

  isa_ok($loader, q{npg_qc::illumina::loader::base}, q{$loader});

  is($loader->id_run(), '4308', 'correct id_run');
  ok($loader->is_paired_read(), 'run 4308 is paired read run');
  ok(!$loader->is_indexed(), 'run 4308 is not indexed run');
  my $id_run_tile = $loader->get_id_run_tile(8, 2, 330);
  is($id_run_tile, 21, 'correct id_run_tile for run 4308 lane 8 end 2 tile 330');
  is($loader->transfer_read_number(1), 1, "read number 1 still 1");
  is($loader->transfer_read_number(2), 2, "read number 2 still 2");
  is($loader->get_id_analysis(1), 3, 'correct id_analysis');
}

1;

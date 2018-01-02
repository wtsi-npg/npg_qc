use strict;
use warnings;
use Test::More tests => 20;
use Test::Exception;
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

  lives_ok { $loader = npg_qc::illumina::loader::base->new(
    runfolder_path => $runfolder_path, schema => $schema)
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

{
  #test for paird indexing run
  my $loader;
  
  my $runfolder_path = qq{t/data/nfs/sf44/IL3/analysis/100117_IL3_4270};
  lives_ok { $loader = npg_qc::illumina::loader::base->new(
    runfolder_path => $runfolder_path, schema => $schema)
  } q{loader object creation ok};
  is($loader->id_run(), '4270', 'correct id_run');
  ok($loader->is_paired_read(), 'run 4270 is paired read run');
  ok($loader->is_indexed(), 'run 4270 is not indexed run');

  my $id_run_tile = $loader->get_id_run_tile(8, 2, 330);
  is($id_run_tile, 22, 'correct id_run_tile for run 4270 lane 8 end 2 tile 330');

  $id_run_tile = $loader->get_id_run_tile(8, 't', 330);
  is($id_run_tile, 23, 'correct id_run_tile for run 4270 lane 8 end t tile 330');
  
  is($loader->transfer_read_number(1), 1, "read number 1 still 1");
  is($loader->transfer_read_number(2), 't', "read number 2 change to t");
  is($loader->transfer_read_number(3), 2, "read number 3 to 2");
  
  is($loader->get_id_analysis(1), 4, 'correct id_analysis');
}

1;

use strict;
use warnings;
use Test::More tests => 34;
use Test::Exception;
use Test::Deep;
use Moose::Meta::Class;
use npg_testing::db;

BEGIN {
  use_ok(q{npg_qc::illumina::loader::Recipe});
}

local $ENV{'dev'} = 'test';
my $schema = Moose::Meta::Class->create_anon_class(
  roles => [qw/npg_testing::db/])
  ->new_object({ config_file => q[data/npg_qc_web/config.ini],})
  ->deploy_test_db(q[npg_qc::Schema],q[t/data/fixtures]); 

{
  #test for paired run
  my $loader;
  my $runfolder_path = qq{t/data/nfs/sf44/IL6/outgoing/100125_IL6_4308};
  lives_ok { $loader = npg_qc::illumina::loader::Recipe->new({
    runfolder_path => $runfolder_path, schema => $schema
  }); } q{loader object creation ok};

  isa_ok($loader, q{npg_qc::illumina::loader::Recipe}, q{$loader});
  
  is($loader->tile_count(), 120, 'tile count for 4308');
  is($loader->lane_count(), 8, 'lane count for 4308');
  is($loader->tilelayout_columns(), 2, 'lane col count for 4308');
  is($loader->cycle_count(), 152, 'cycle count for 4308');
  cmp_deeply( [$loader->read1_cycle_range()], [1, 76], 'read1 cycle range for 4308');
  cmp_deeply( [$loader->read2_cycle_range()], [77, 152], 'read2 cycle range for 4308');
  
  is($loader->file_name(), 't/data/nfs/sf44/IL6/outgoing/100125_IL6_4308/Recipe_GA2-PEM_2x37Cycle_v7.7.xml', 'correct receip file');
  lives_ok { $loader->run(); } q{4308 runs ok};
}

{
  #test for paired indexing run
  my $loader;
  my $runfolder_path = q{t/data/nfs/sf44/IL14/outgoing/100930_IL14_05349};
  lives_ok { $loader = npg_qc::illumina::loader::Recipe->new({
    runfolder_path => $runfolder_path, schema => $schema
  }); } q{loader object creation ok};
  is($loader->tile_count(), 120, 'tile count for 5349');
  is($loader->lane_count(), 8, 'lane count for 5349');
  is($loader->tilelayout_columns(), 2, 'lane col count for 5349');
  is($loader->cycle_count(), 116, 'cycle count for 5349');
  cmp_deeply( [$loader->read1_cycle_range()], [1, 54], 'read1 cycle range for 5349');
  cmp_deeply( [$loader->indexing_cycle_range()], [55, 62], 'index read cycle range for 5349');
  cmp_deeply( [$loader->read2_cycle_range()], [63, 116], 'read2 cycle range for 5349');
  
  is($loader->file_name(), 't/data/nfs/sf44/IL14/outgoing/100930_IL14_05349/Recipe_Sanger_GA2-PEM2X_MP_54+8+54Cycle_v8.3.xml', 'correct receip file');
  lives_ok { $loader->run(); } q{5349 runs ok};
}

{
  #test hiseq run
  my $loader;
  my $runfolder_path = q{t/data/nfs/sf44/ILorHSany_sf25/incoming/100925_HS8_05330_B_205NNABXX};
  lives_ok { $loader = npg_qc::illumina::loader::Recipe->new({
    runfolder_path => $runfolder_path, schema => $schema
  }); } q{loader object creation ok};
  is($loader->tile_count(), 32, 'tile count for 5330');
  is($loader->lane_count(), 8, 'lane count for 5330');
  throws_ok {$loader->tilelayout_columns()} qr{No such file or directory}, 'lane col count for 5330'; 
  is($loader->cycle_count(), 200, 'cycle count for 5330');
  cmp_deeply( [$loader->read1_cycle_range()], [1, 100], 'read1 cycle range for 5330');
  cmp_deeply( [$loader->read2_cycle_range()], [101, 200], 'read2 cycle range for 5330');  

  ok (!$loader->file_name(), 'No Recipe xml file available for hiseq run');
  lives_ok { $loader->run(); } q{5330 runs ok};
}

{
  my $recipe_monitor;
  lives_ok { $recipe_monitor = npg_qc::illumina::loader::Recipe->new({
                            pattern_prefix  => 't/data/nfs/sf44/IL*',
                            glob_pattern    => q{*/*4308/Recipe*.xml},
                            schema => $schema,
  }); } q{loader object creation ok};
  is(scalar keys %{$recipe_monitor->runlist_db()}, 8, 'correct number of runs in db');
  my $runlist_todo = {4308 => 't/data/nfs/sf44/IL6/outgoing/100125_IL6_4308'};
  $recipe_monitor->runfolder_list_todo($runlist_todo);
  is(scalar keys %{$recipe_monitor->runfolder_list_todo()}, 1, 'correct number of runs to do');
  lives_ok { $recipe_monitor->run_all(); } q{recipe loading ok};
}

1;

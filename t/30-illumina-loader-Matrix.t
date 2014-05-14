use strict;
use warnings;
use Test::More tests => 9;
use Test::Exception;
use npg_testing::db;

BEGIN {
  use_ok(q{npg_qc::illumina::loader::Matrix});
}

$ENV{dev} = 'test';
my $schema = npg_testing::db::deploy_test_db(q[npg_qc::Schema],q[t/data/fixtures]);

{
  #test for paird run
  my $loader;
  
  my $runfolder_path = qq{t/data/nfs/sf44/IL6/outgoing/100125_IL6_4308};

  lives_ok { $loader = npg_qc::illumina::loader::Matrix->new({
     runfolder_path => $runfolder_path, schema => $schema
  }); } q{loader object creation ok};
  isa_ok($loader, q{npg_qc::illumina::loader::Matrix}, q{$loader});
  lives_ok { $loader->run(); } q{4308 matrix runs ok};
}

{
  #test for paird run
  my $loader;

  my $archive_path = q{t/data/nfs/sf44/ILorHSany_sf25/incoming/100925_HS8_05330_B_205NNABXX/Data/Intensities/PB_basecalls_20101014-161249/no_cal/archive};

  lives_ok { $loader = npg_qc::illumina::loader::Matrix->new({
     archive_path => $archive_path, schema => $schema
  }); } q{loader object creation ok};

  print $loader->config_xml_file(), "\n";
  
  my $matrix_cylce_per_read = $loader->_matrix_cylce_per_read();
  my $expected = {1 => 1, 2 => 101, 3 => 109};
  is_deeply($expected, $matrix_cylce_per_read, 'correct cycle number by read');
  
  is($loader->_second_cycle_number_by_read(1), 2, 'correct second cycle number for read 1');
  is($loader->_second_cycle_number_by_read(2), 102, 'correct second cycle number for read 2');

  lives_ok { $loader->run(); } q{5330 matrix runs ok};
}

1;

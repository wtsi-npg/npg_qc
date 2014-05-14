use strict;
use warnings;
use Test::More tests => 6;
use Test::Exception;
use npg_testing::db;

BEGIN {
  use_ok(q{npg_qc::illumina::loader::Offset});
}

$ENV{dev} = 'test';
my $schema = npg_testing::db::deploy_test_db(q[npg_qc::Schema],q[t/data/fixtures]);

{
  #test for paird run
  my $loader;
  
  my $runfolder_path = qq{t/data/nfs/sf44/IL6/outgoing/100125_IL6_4308};

  lives_ok { $loader = npg_qc::illumina::loader::Offset->new({
    runfolder_path => $runfolder_path, schema => $schema
  }); } q{loader object creation ok};

  isa_ok($loader, q{npg_qc::illumina::loader::Offset}, q{$loader});

  lives_ok { $loader->run(); } q{4308 offset runs ok};
}

{
  my $loader;

  my $archive_path = q{t/data/nfs/sf44/ILorHSany_sf25/incoming/100925_HS8_05330_B_205NNABXX/Data/Intensities/PB_basecalls_20101014-161249/no_cal/archive};

  lives_ok { $loader = npg_qc::illumina::loader::Offset->new({
    archive_path => $archive_path, schema => $schema
  }); } q{loader object creation ok};

  lives_ok { $loader->run(); } q{5330 offset runs ok};
}
1;

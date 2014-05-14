use strict;
use warnings;
use Test::More tests => 11;
use Test::Exception;
use npg_testing::db;


BEGIN {
  use_ok(q{npg_qc::illumina::loader::Bustard_Summary});
}

$ENV{dev} = 'test';
my $schema = npg_testing::db::deploy_test_db(q[npg_qc::Schema],q[t/data/fixtures]);
{
  my $loader;
  my $runfolder_path = qq{t/data/nfs/sf44/IL6/outgoing/100125_IL6_4308};
  lives_ok { $loader = npg_qc::illumina::loader::Bustard_Summary->new(
    runfolder_path => $runfolder_path, schema => $schema
  ); } q{loader object creation ok};
  isa_ok($loader, q{npg_qc::illumina::loader::Bustard_Summary}, q{$loader});
  is($loader->xml_file(), q{t/data/nfs/sf44/IL6/outgoing/100125_IL6_4308/Data/Intensities/Bustard1.6.0a14_29-01-2010_RTA/BustardSummary.xml}, 'correct xml file name');
  lives_ok { $loader->run(); } q{4308 runs ok};
}

{
  my $loader;
  my $runfolder_path = qq{t/data/nfs/sf44/IL3/analysis/100117_IL3_4270};  
  lives_ok { $loader = npg_qc::illumina::loader::Bustard_Summary->new(
    runfolder_path => $runfolder_path, schema => $schema
  ); } q{loader object creation ok};
  is($loader->xml_file(), q{t/data/nfs/sf44/IL3/analysis/100117_IL3_4270/Data/Intensities/Bustard1.6.0a14_24-01-2010_RTA/BustardSummary.xml}, 'correct xml file name');
  lives_ok { $loader->run(); } q{4270 runs ok};
}

{
  my $loader;
  my $runfolder_path = qq{t/data/nfs/sf44/ILorHSany_sf25/incoming/100925_HS8_05330_B_205NNABXX};
  lives_ok { $loader = npg_qc::illumina::loader::Bustard_Summary->new(
                            runfolder_path => $runfolder_path,
                            schema => $schema,
                            bustard_path => $runfolder_path . q{/Data/Intensities/PB_basecalls_20101014-161249},
                            recalibrated_path => $runfolder_path . q{/Data/Intensities/PB_basecalls_20101014-161249/no_cal},
  ); } q{loader object creation ok};
  is($loader->xml_file(), $runfolder_path . q{/Data/Intensities/PB_basecalls_20101014-161249/BustardSummary.xml}, 'correct xml file name');
  lives_ok { $loader->run(); } q{5330 runs ok};
}

1;

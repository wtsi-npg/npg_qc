use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;
use npg_testing::db;

BEGIN {
  use_ok(q{npg_qc::illumina::loader::Signal_Mean});
}

$ENV{dev} = 'test';
my $schema = npg_testing::db::deploy_test_db(q[npg_qc::Schema],q[t/data/fixtures]);

{
  #test for paird run
  my $loader;
  
  my $runfolder_path = qq{t/data/nfs/sf44/IL6/outgoing/100125_IL6_4308};

  lives_ok { $loader = npg_qc::illumina::loader::Signal_Mean->new({
    runfolder_path => $runfolder_path, schema => $schema
  }); } q{loader object creation ok};

  isa_ok($loader, q{npg_qc::illumina::loader::Signal_Mean}, q{$loader});

  lives_ok { $loader->run(); } q{4308 runs ok};
}

1;

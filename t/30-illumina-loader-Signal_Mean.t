use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;
use Moose::Meta::Class;
use npg_testing::db;

BEGIN {
  use_ok(q{npg_qc::illumina::loader::Signal_Mean});
}

local $ENV{'dev'} = 'test';
my $schema = Moose::Meta::Class->create_anon_class(
  roles => [qw/npg_testing::db/])
  ->new_object({ config_file =>  q[t/data/config.ini],})
  ->deploy_test_db(q[npg_qc::Schema],q[t/data/fixtures]); 

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

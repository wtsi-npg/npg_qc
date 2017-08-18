use strict;
use warnings;
use Test::More  tests => 2;
use Moose::Meta::Class;
use npg_testing::db;

use_ok('npg_qc::illumina::loader::Run_Caching');
local $ENV{'dev'} = 'test';
my $schema = Moose::Meta::Class->create_anon_class(
  roles => [qw/npg_testing::db/])
  ->new_object({ config_file => q[t/data/config.ini],})
  ->deploy_test_db(q[npg_qc::Schema]);

{
  my $rc = npg_qc::illumina::loader::Run_Caching->new({schema => $schema});
  isa_ok($rc, 'npg_qc::illumina::loader::Run_Caching', '$rc model');
}

1;

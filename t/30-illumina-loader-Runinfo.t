use strict;
use warnings;
use Test::More tests => 8;
use Test::Exception;
use Moose::Meta::Class;
use npg_testing::db;

BEGIN {
  use_ok(q{npg_qc::illumina::loader::Runinfo});
}

local $ENV{'dev'} = 'test';
my $db_helper = Moose::Meta::Class->create_anon_class(
  roles => [qw/npg_testing::db/])
  ->new_object({ config_file => q[data/npg_qc_web/config.ini],});
my $schema = $db_helper->deploy_test_db(q[npg_qc::Schema],q[t/data/fixtures]);
my $schema_tracking = $db_helper->deploy_test_db(q[npg_tracking::Schema]);
{
  #test for paired run
  my $loader;
  my $runfolder_path = qq{t/data/nfs/sf44/IL6/outgoing/100125_IL6_4308};
  lives_ok { $loader = npg_qc::illumina::loader::Runinfo->new(
                    runfolder_path => $runfolder_path,
                    schema => $schema) } q{loader object creation ok};
  isa_ok($loader, q{npg_qc::illumina::loader::Runinfo}, q{$loader});
  is($loader->file_name(), "${runfolder_path}/RunInfo.xml", 'correct run info file');
  lives_ok { $loader->run(); } q{4308 runs ok};
}

{
  my $runinfo_monitor;
  lives_ok { $runinfo_monitor = npg_qc::illumina::loader::Runinfo->new(
                            pattern_prefix  => 't/data/nfs/sf44/IL*/',
                            schema => $schema,
                            schema_npg_tracking => $schema_tracking)
           } q{with pattern_prefix arg object creation ok};
  is(scalar keys %{$runinfo_monitor->runlist_db()}, 1, 'correct number of runs in db');
  $runinfo_monitor->runfolder_list_todo({4308 => 't/data/nfs/sf44/IL6/outgoing/100125_IL6_4308'});
  lives_ok { $runinfo_monitor->run_all(); } q{runlog loading ok};
}

1;

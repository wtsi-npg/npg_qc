use strict;
use warnings;
use Test::More tests => 10;
use Test::Exception;
use Moose::Meta::Class;
use npg_testing::db;

BEGIN {
  use_ok(q{npg_qc::illumina::loader});
}

$ENV{'dev'} = 'test';
my $config_file = q[t/data/config.ini];
my $schema = Moose::Meta::Class->create_anon_class(
  roles => [qw/npg_testing::db/])
  ->new_object({ config_file => $config_file,})
  ->deploy_test_db(q[npg_qc::Schema], q[t/data/fixtures]);
$schema->_set_config_file($config_file); # we need to propagate the location of the db config file
                                         # to Clearpress models, see _build_npg_qc_util
                                         # in npg_qc::illumina::loader::Run_Caching

{
  my $loader;
  lives_ok { $loader = npg_qc::illumina::loader->new(); } q{loader object creation ok};
  isa_ok($loader, q{npg_qc::illumina::loader}, q{$loader});
}

TODO: {
  local $TODO = q[Waiting for other changes to be finished befor fixing tests];
  local $ENV{NPG_WEBSERVICE_CACHE_DIR} = q{t/data/requests/cgi-bin/prodsoft/npg};

  #test for paired run
  my $loader;
  my $runfolder_path = qq{t/data/nfs/sf44/IL6/outgoing/100125_IL6_4308};
  lives_ok { $loader = npg_qc::illumina::loader->new(
    runfolder_path => $runfolder_path, schema => $schema
  ); } q{loader object creation ok};
  isa_ok($loader, q{npg_qc::illumina::loader}, q{$loader});
  lives_ok { $loader->run(); } q{4308 runs ok};
}

{
  my $loader = npg_qc::illumina::loader->new(id_run => 10, is_paired_read => 0, schema => $schema);
  ok ($loader->lane_summary_saved, 'lane summary saved for non-paired run');
  $loader = npg_qc::illumina::loader->new(id_run => 10, is_paired_read => 1, schema => $schema);
  ok (!$loader->lane_summary_saved, 'lane summary not saved for the same data if run is paired');

  $schema->resultset('CacheQuery')->update_or_create({
           ssha_sql => 'something',
           id_run   => 10,
           end      => 2,
           type     => 'lane_summary',
           is_current => 1,
           results => '$rows_ref = ;',
                                                    });

  $loader = npg_qc::illumina::loader->new(id_run => 11, is_paired_read => 0, schema => $schema);
  ok (!$loader->lane_summary_saved, 'lane summary not saved if no data available for a single end run');
  $loader = npg_qc::illumina::loader->new(id_run => 11, is_paired_read => 1, schema => $schema);
  ok (!$loader->lane_summary_saved, 'lane summary not saved if no data available for a paired run');
}

1;

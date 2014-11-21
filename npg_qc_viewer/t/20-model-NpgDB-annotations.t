use strict;
use warnings;
use Test::More tests => 11;
use Test::Exception;
use File::Temp qw(tempfile);
use t::util;

BEGIN { use_ok 'npg_qc_viewer::Model::NpgDB' }

my $util = t::util->new();
my $schema_package = q[npg_tracking::Schema];
my $fixtures_path = q[t/data/fixtures/npg];
my ($fh,$tmpdbfilename) = tempfile(UNLINK => 1);
my $schema;

lives_ok{ $schema = $util->create_test_db($schema_package, $fixtures_path, $tmpdbfilename) }
                              'test db created and populated';

my $m;
lives_ok {
  $m = npg_qc_viewer::Model::NpgDB->new( connect_info => {
                               dsn      => ('dbi:SQLite:'.$tmpdbfilename),
                               user     => q(),
                               password => q()
                                                               })
} 'create new model object';

isa_ok($m, 'npg_qc_viewer::Model::NpgDB');

{
  is($m->run_annotations(4025)->count, 3, '3 run annotations for run 4025');
  is($m->run_annotations(6400)->count, 9, '9 run annotations for run 6400');
}

{
  is($m->runlane_annotations(4025)->count, 0, 'no runlane annotations for run 4025');
  my $a = $m->runlane_annotations(6400);
  is($a->count, 7, '7 runlane annotations for run 6400');
  is($a->next->run_lane->position, 2, 'first annotation for lane 2');
  is($a->next->run_lane->position, 6, 'second annotation for lane 6');
  is($a->next->run_lane->position, 6, 'third annotation for lane 6');
}

1;



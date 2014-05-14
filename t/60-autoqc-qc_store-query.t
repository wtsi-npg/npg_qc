use strict;
use warnings;
use Test::More tests => 16;
use Test::Exception;
use Moose::Meta::Class;

use npg_qc::autoqc::qc_store::options qw/$ALL $LANES $PLEXES/;

BEGIN { use_ok 'npg_qc::autoqc::qc_store::query'; }

{
  my $q = npg_qc::autoqc::qc_store::query->new(id_run => 1);
  isa_ok($q, 'npg_qc::autoqc::qc_store::query');
  is($q->option, $LANES, 'lanes option is default');
  is(scalar(@{$q->positions}), 0, 'empty positions array is default');
  ok($q->db_qcresults_lookup, 'look up results in the db by default');
  ok(!$q->propagate_npg_tracking_schema, 'do not use supplied tracking schema by default');
  is($q->to_string, 'npg_qc::autoqc::qc_store::query object: run 1, positions ALL, loading option LANES, npg_tracking_schema UNDEFINED, propagate_npg_tracking_schema 0, db_qcresults_lookup 1', 'object as string');
}

{
  my $q;
  lives_ok {$q = npg_qc::autoqc::qc_store::query->new(id_run => 1, option => $ALL)} 'creating an object with allowed option lives';
  is($q->to_string, 'npg_qc::autoqc::qc_store::query object: run 1, positions ALL, loading option ALL, npg_tracking_schema UNDEFINED, propagate_npg_tracking_schema 0, db_qcresults_lookup 1', 'object as string');
  throws_ok {npg_qc::autoqc::qc_store::query->new(id_run => 1, option => 8)} qr/Unknown option for loading qc results: 8/, 'creating an object with incorrect option throws an error';

  lives_ok {$q = npg_qc::autoqc::qc_store::query->new(id_run => 1, option => $ALL, positions => [1,2])} 'creating an object with allowed positions lives';
  is($q->to_string, 'npg_qc::autoqc::qc_store::query object: run 1, positions 1 2, loading option ALL, npg_tracking_schema UNDEFINED, propagate_npg_tracking_schema 0, db_qcresults_lookup 1', 'object as string');
  throws_ok {npg_qc::autoqc::qc_store::query->new(id_run => 1, option => $ALL, positions => [0, 9])} qr/Attribute \(positions\) does not pass the type constraint/, 'creating an object with incorrect positions throws an error';
}

{
  my $util = Moose::Meta::Class->create_anon_class(roles => ['npg_testing::db'])->new_object();
  my $schema;
  lives_ok{ $schema = $util->create_test_db(q[npg_tracking::Schema]) } 'npg tracking test db created';

  my $q;
  lives_ok {$q = npg_qc::autoqc::qc_store::query->new(id_run => 1, option => $PLEXES, positions => [1,2], npg_tracking_schema => $schema)} 'creating an object with npg schema lives';
  like($q->to_string, qr/npg_qc::autoqc::qc_store::query object: run 1, positions 1 2, loading option PLEXES, npg_tracking_schema npg_tracking::Schema=HASH\(.*\), propagate_npg_tracking_schema 0, db_qcresults_lookup 1/, 'object as string');
}

1;
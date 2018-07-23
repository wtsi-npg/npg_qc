use strict;
use warnings;
use Test::More tests => 12;
use Test::Exception;
use Moose::Meta::Class;

use npg_qc::autoqc::qc_store::options qw/$ALL $LANES $PLEXES/;

use_ok 'npg_qc::autoqc::qc_store::query';
my $schema = Moose::Meta::Class->create_anon_class(roles => ['npg_testing::db'])
             ->new_object()->create_test_db(q[npg_tracking::Schema]);

{
  my $q = npg_qc::autoqc::qc_store::query->new(id_run => 1, npg_tracking_schema => $schema);
  isa_ok($q, 'npg_qc::autoqc::qc_store::query');
  is($q->option, $LANES, 'lanes option is default');
  is(scalar(@{$q->positions}), 0, 'empty positions array is default');
  ok($q->db_qcresults_lookup, 'look up results in the db by default');
  is($q->to_string,
    'npg_qc::autoqc::qc_store::query object: run 1, positions ALL, loading option LANES, db_qcresults_lookup 1',
    'object as string');
}

{
  my $q;
  lives_ok {$q = npg_qc::autoqc::qc_store::query->new(id_run => 1, option => $ALL, npg_tracking_schema => $schema)}
    'creating an object with allowed option lives';
  is($q->to_string,
    'npg_qc::autoqc::qc_store::query object: run 1, positions ALL, loading option ALL, db_qcresults_lookup 1',
    'object as string');
  throws_ok {npg_qc::autoqc::qc_store::query->new(id_run => 1, option => 8, npg_tracking_schema => $schema)}
    qr/Unknown option for loading qc results: 8/,
    'creating an object with incorrect option throws an error';
  lives_ok {$q = npg_qc::autoqc::qc_store::query->new(id_run => 1, option => $ALL, positions => [1,2], npg_tracking_schema => $schema)}
    'creating an object with allowed positions lives';
  is($q->to_string,
    'npg_qc::autoqc::qc_store::query object: run 1, positions 1 2, loading option ALL, db_qcresults_lookup 1',
    'object as string');
  throws_ok {npg_qc::autoqc::qc_store::query->new(id_run => 1, option => $ALL, positions => [0, 9],npg_tracking_schema => $schema)}
    qr/Attribute \(positions\) does not pass the type constraint/,
    'creating an object with incorrect positions throws an error';
}

1;
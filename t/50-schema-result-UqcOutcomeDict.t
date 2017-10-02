use strict;
use warnings;
use Test::More tests => 13;
use Moose::Meta::Class;
use npg_testing::db;

use_ok('npg_qc::Schema::Result::UqcOutcomeDict');

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema], 't/data/fixtures', ':memory:');

my $table = 'UqcOutcomeDict';
my $descriptions = ['Accepted', 'Rejected','Undecided'];
my $decisions = ['Accepted', 'Rejected'];
my @rows = $schema->resultset($table)->search({short_desc => {'-in', $decisions}})->all();
is (scalar @rows, 2, 'two decided outcomes');
ok (!$rows[0]->is_final_outcome, 'final outcome check returns false');
ok ($rows[0]->is_accepted, 'accepted outcome check returns true');
ok (!$rows[0]->is_final_accepted, 'accepted & final outcome check returns false');
ok (!$rows[1]->is_final_outcome, 'final outcome check returns false');
ok (!$rows[1]->is_accepted, 'accepted outcome check returns false');
ok (!$rows[1]->is_final_accepted, 'accepted & final outcome check returns false');
@rows = $schema->resultset($table)->search({short_desc => {'-in', $descriptions}})->all();
is (scalar @rows, 3, 'three possible outcomes');
ok (!$rows[2]->is_final_outcome, 'final outcome check returns false');
ok (!$rows[2]->is_accepted, 'accepted outcome check returns false');
ok (!$rows[2]->is_final_accepted, 'accepted & final outcome check returns false');
is ($rows[2]->pk_value(), $rows[2]->id_uqc_outcome, 'primary key value');

1;

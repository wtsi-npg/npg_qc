use strict;
use warnings;
use Test::More tests => 21;
use Moose::Meta::Class;
use npg_testing::db;

use_ok('npg_qc::Schema::Result::MqcLibraryOutcomeDict');

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema], 't/data/fixtures', ':memory:');

my $table = 'MqcLibraryOutcomeDict';
my $final = ['Accepted final', 'Rejected final', 'Undecided final'];
my @rows = $schema->resultset($table)->search({short_desc => {'-in', $final}})->all();
is (scalar @rows, 3, 'three final outcomes');
ok ($rows[0]->is_final_outcome, 'final outcome check returns true');
ok ($rows[0]->is_accepted, 'accepted outcome check returns true');
ok ($rows[0]->is_final_accepted, 'accepted & final outcome check returns true');
ok ($rows[1]->is_final_outcome, 'final outcome check returns true');
ok (!$rows[1]->is_accepted, 'accepted outcome check returns false');
ok (!$rows[1]->is_final_accepted, 'accepted & final outcome check returns false');
ok ($rows[2]->is_final_outcome, 'final outcome check returns true');
ok ($rows[2]->is_undecided, 'undecided outcome check returns true');
ok (!$rows[2]->is_final_accepted, 'accepted & final outcome check returns false');
@rows = $schema->resultset($table)->search({short_desc => {'-not_in', $final}})->all();
is (scalar @rows, 3, 'three non-final outcomes');
ok (!$rows[0]->is_final_outcome, 'final outcome check returns false');
ok ($rows[0]->is_accepted, 'accepted outcome check returns true');
ok (!$rows[0]->is_final_accepted, 'accepted & final outcome check returns false');
ok (!$rows[1]->is_final_outcome, 'final outcome check returns false');
ok (!$rows[1]->is_accepted, 'accepted outcome check returns false');
ok (!$rows[1]->is_final_accepted, 'accepted & final outcome check returns false');
ok (!$rows[2]->is_final_outcome, 'final outcome check returns false');
ok (!$rows[2]->is_accepted, 'accepted outcome check returns false');
ok (!$rows[2]->is_final_accepted, 'accepted & final outcome check returns false');

1;


use strict;
use warnings;
use Test::More tests => 28;
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
is ($rows[0]->matching_final_short_desc(), 'Accepted final', 'matching final');
ok ($rows[1]->is_final_outcome, 'final outcome check returns true');
ok (!$rows[1]->is_accepted, 'accepted outcome check returns false');
ok (!$rows[1]->is_final_accepted, 'accepted & final outcome check returns false');
is ($rows[1]->matching_final_short_desc(), 'Rejected final', 'matching final');
ok ($rows[2]->is_final_outcome, 'final outcome check returns true');
ok ($rows[2]->is_undecided, 'undecided outcome check returns true');
ok (!$rows[2]->is_final_accepted, 'accepted & final outcome check returns false');
is ($rows[2]->matching_final_short_desc(), 'Undecided final', 'matching final');
@rows = $schema->resultset($table)->search({short_desc => {'-not_in', $final}})->all();
is (scalar @rows, 3, 'three non-final outcomes');
ok (!$rows[0]->is_final_outcome, 'final outcome check returns false');
ok ($rows[0]->is_accepted, 'accepted outcome check returns true');
ok (!$rows[0]->is_final_accepted, 'accepted & final outcome check returns false');
is ($rows[0]->matching_final_short_desc(), 'Accepted final', 'matching final');
ok (!$rows[1]->is_final_outcome, 'final outcome check returns false');
ok (!$rows[1]->is_accepted, 'accepted outcome check returns false');
ok (!$rows[1]->is_final_accepted, 'accepted & final outcome check returns false');
is ($rows[1]->matching_final_short_desc(), 'Rejected final', 'matching final');
ok (!$rows[2]->is_final_outcome, 'final outcome check returns false');
ok (!$rows[2]->is_accepted, 'accepted outcome check returns false');
ok (!$rows[2]->is_final_accepted, 'accepted & final outcome check returns false');
is ($rows[2]->matching_final_short_desc(), 'Undecided final', 'matching final');
is ($rows[2]->pk_value(), $rows[2]->id_mqc_library_outcome, 'primary key value');

1;


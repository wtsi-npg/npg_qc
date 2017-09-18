use strict;
use warnings;
use Test::More tests => 8;
use Moose::Meta::Class;
use npg_testing::db;

use_ok('npg_qc::Schema::Result::UqcOutcomeDict');

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema], 't/data/fixtures', ':memory:');

my $table = 'UqcOutcomeDict';
my $decisions = ['Accepted', 'Rejected'];
my @rows = $schema->resultset($table)->search({short_desc => {'-in', $decisions}})->all();
is (scalar @rows, 2, 'two decided outcomes');
ok (!$rows[0]->is_final_outcome, 'final outcome check returns false');
ok ($rows[0]->is_accepted, 'accepted outcome check returns true');
ok (!$rows[0]->is_final_accepted, 'accepted & final outcome check returns false');
ok (!$rows[1]->is_final_outcome, 'final outcome check returns false');
ok (!$rows[1]->is_accepted, 'accepted outcome check returns false');
ok (!$rows[1]->is_final_accepted, 'accepted & final outcome check returns false');
1;
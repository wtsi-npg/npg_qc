use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;
use Moose::Meta::Class;
use JSON;

use npg_testing::db;
use t::autoqc_util;

use_ok('npg_qc::Schema::Result::Interop');

my $schema = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_testing::db/])
          ->new_object({})->create_test_db(q[npg_qc::Schema]);

my $values = {
  metrics => {aligned_mean => 2317485, occupied_mean => 23269}
};

$values->{'id_seq_composition'} =
  t::autoqc_util::find_or_save_composition($schema,
    {id_run => 9225, position => 1});
my $rs = $schema->resultset('Interop');

my $row = $rs->new_result($values);
isa_ok($row, 'npg_qc::Schema::Result::Interop');
$row->insert();

$row = $rs->search({})->next;
is ($row->aligned_mean, 2317485, 'correct aligned_mean value retrieved');
is ($row->occupied_mean, 23269, 'correct occupied_mean value retrieved');

1;

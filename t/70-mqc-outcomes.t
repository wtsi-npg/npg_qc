use strict;
use warnings;
use Test::More tests => 2;
use Test::Exception;
use Moose::Meta::Class;
use npg_testing::db;

use_ok('npg_qc::mqc::outcomes');

sub _create_schema {
  return Moose::Meta::Class->create_anon_class(
    roles => [qw/npg_testing::db/])->new_object()->create_test_db(
    q[npg_qc::Schema], q[t/data/reporter/npg_qc]);
}

my $npg_qc_schema = _create_schema();

subtest 'constructor tests' => sub {
  plan tests => 3;

  throws_ok { npg_qc::mqc::outcomes->new() }
    qr/Attribute \(qc_schema\) is required/,
    'qc schema should be provided';

  my $o;
  lives_ok { $o = npg_qc::mqc::outcomes->new(
                 qc_schema  => $npg_qc_schema )}
    'qc schema given - object created';
  isa_ok($o, 'npg_qc::mqc::outcomes');
};

1;


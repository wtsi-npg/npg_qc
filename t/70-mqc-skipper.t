use strict;
use warnings;
use Test::More tests => 2;
use Test::Exception;
use Moose::Meta::Class;
use Log::Log4perl qw(:levels);
use npg_testing::db;

use_ok('npg_qc::mqc::skipper');

sub _create_qc_schema {
  return Moose::Meta::Class->create_anon_class(
    roles => [qw/npg_testing::db/])->new_object()->create_test_db(
    q[npg_qc::Schema], q[t/data/fixtures]);
}

sub _create_mlwh_schema {
  return Moose::Meta::Class->create_anon_class(
    roles => [qw/npg_testing::db/]
  )->new_object()->create_test_db(q[WTSI::DNAP::Warehouse::Schema]);
}

sub _create_tracking_schema {
  return Moose::Meta::Class->create_anon_class(
    roles => [qw/npg_testing::db/]
  )->new_object()->create_test_db(
    q[npg_tracking::Schema], q[t/data/fixtures/npg_tracking]
  );
}

my $qc_schema       = _create_qc_schema();
my $mlwh_schema     = _create_mlwh_schema();
my $tracking_schema = _create_tracking_schema();

my $layout = '%d %-5p %c - %m%n';
Log::Log4perl->easy_init({layout => $layout,
                          level  => $WARN,
                          utf8   => 1});
my $logger = Log::Log4perl->get_logger();

subtest 'create object' => sub {
  plan tests => 1;

  my $skipper = npg_qc::mqc::skipper->new(
    qc_schema           => $qc_schema,
    mlwh_schema         => $mlwh_schema,
    npg_tracking_schema => $tracking_schema,
    id_runs             => [1, 2],
    qc_fails_threshold  => 90,
    logger              => $logger      
  );
  isa_ok($skipper, 'npg_qc::mqc::skipper');
};

1;


use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;
use Test::Warn;
use Moose::Meta::Class;
use npg_testing::db;
use REST::Client;
use JSON;

sub _create_schema {
  return Moose::Meta::Class->create_anon_class(
    roles => [qw/npg_testing::db/])->new_object()->create_test_db(
    q[npg_qc::Schema], q[t/data/report/genotype_call/npg_qc]);
}

sub _create_mlwh_schema {
  return Moose::Meta::Class->create_anon_class(
    roles => [qw/npg_testing::db/]
  )->new_object()->create_test_db(
    q[WTSI::DNAP::Warehouse::Schema], q[t/data/report/genotype_call/mlwarehouse]
  );
}

use_ok('npg_qc::report::genotype_call');

my $npg_qc_schema = _create_schema();
my $mlwh_schema   = _create_mlwh_schema();

subtest 'Initial' => sub {
  plan tests => 5;

  my $reporter = npg_qc::report::genotype_call->new(
     qc_schema   => $npg_qc_schema,
     mlwh_schema => $mlwh_schema,
  );
  isa_ok($reporter, 'npg_qc::report::genotype_call');

  like( $reporter->api_url(),
    qr/\/api\/v2\/qc_results/, 'url for sending');

  ok(!$reporter->has_gbs_plex(), 'gbs_plex not set as expected');

  my $plex = 'Minor_v1.0';
  my $reporter2 = npg_qc::report::genotype_call->new(
     qc_schema   => $npg_qc_schema,
     mlwh_schema => $mlwh_schema,
     gbs_plex    => $plex,
  );

  ok( $reporter2->has_gbs_plex(), 'gbs_plex set as expected');
  is( $reporter2->gbs_plex(), $plex, 'gbs_plex set correctly');

};


*REST::Client::POST = *main::post_nowhere;
sub post_nowhere {
  my $client = REST::Client->new();
  return $client;
}

*REST::Client::responseCode = *main::responseCodeGood;
sub responseCodeGood {
  return 201; ## created
}

sub _get_data {
  my ($schema, $id, $field) = @_;
 
  my $row = $schema->resultset('GenotypeCall')->search({'id_seq_composition' => $id})->next();
  if (!$row) {                                                              
      die 'cannot find db row';
  }
  return $row->$field;
}

sub _get_expected_data {
 my $expected = {
     data => {
         attributes => [
             {
                 key   => "primer_panel",
                 units => "panels",
                 uuid  => "5084d51a-00e7-11e8-8f97-3c4a9275d6c8",
                 value => "Pf_GRC1v1.0",
             },
             {
                 key   => "loci_tested",
                 units => "bases",
                 uuid  => "5084d51a-00e7-11e8-8f97-3c4a9275d6c8",
                 value => '1695',
             },
             {
                 key   => "loci_passed",
                 units => "bases",
                 uuid  => "5084d51a-00e7-11e8-8f97-3c4a9275d6c8",
                 value => '1502',
             },
             ],
     },
 }; 
}


subtest 'Successfully post 2 results' => sub {
  plan tests => 13;

  my $reporter = npg_qc::report::genotype_call->new(
     qc_schema   => $npg_qc_schema,
     mlwh_schema => $mlwh_schema,
     gbs_plex    => 'Pf_GRC1v1.0',
     verbose     => 1,
  );
  isa_ok($reporter, 'npg_qc::report::genotype_call');

  my $toreport = $reporter->_construct_data($reporter->_data4reporting()->[0]);
  is_deeply (decode_json($toreport), _get_expected_data(), 
    q[data to send constucted correctly with gbs_plex name set]);


  my $reporter2 = npg_qc::report::genotype_call->new(
     qc_schema   => $npg_qc_schema,
     mlwh_schema => $mlwh_schema,
     gbs_plex    => 'Minor_v1.0',
     verbose     => 1,
  );
  my $toreport2 = $reporter2->_data4reporting();
  ok (!$toreport2->[0], 
    q[no data to send constucted correctly with unused gbs_plex name set]);


  my $reporter3 = npg_qc::report::genotype_call->new(
     qc_schema   => $npg_qc_schema,
     mlwh_schema => $mlwh_schema,
     verbose     => 1,
  );

  my @ids = ('1','2');
  foreach my $id (@ids){
     ok (!_get_data($npg_qc_schema, $id, 'reported'), 'reporting time is not set');
     ok (!_get_data($npg_qc_schema, $id, 'reported_by'), 'reporting_by field is not set');
  }

  my $toreport3 = $reporter3->_construct_data($reporter3->_data4reporting()->[0]);
  is_deeply (decode_json($toreport3), _get_expected_data(),
    q[data to send constucted correctly with no gbs_plex name set]);

  lives_ok { $reporter3->load() } 'no error';

  foreach my $id (@ids){
     ok (_get_data($npg_qc_schema, $id, 'reported'), 'reporting time is set');
     ok (_get_data($npg_qc_schema, $id, 'reported_by'), 'reporting_by field is set');
  }

};


*REST::Client::responseCode = *main::responseCodeBad;
sub responseCodeBad {
  return 422; ## unprocessable_entity
}

subtest 'Testing failing to report' => sub {
  plan tests => 6;
  
  my $npg_qc_schema = _create_schema();
  my $mlwh_schema   = _create_mlwh_schema();

  my $reporter = npg_qc::report::genotype_call->new(
    qc_schema   => $npg_qc_schema,
    mlwh_schema => $mlwh_schema,
  );

  lives_ok { $reporter->load() } 'no error';
 
  my @ids = ('1','2');
  foreach my $id (@ids){
     ok (!_get_data($npg_qc_schema, $id, 'reported'), 'reporting time is not set');
     ok (!_get_data($npg_qc_schema, $id, 'reported_by'), 'reporting_by field is not set');
  }

  is($reporter->_error_count, @ids, 'check error count correct');

};


1;

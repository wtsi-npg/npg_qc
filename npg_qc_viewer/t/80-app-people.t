use strict;
use warnings;
use Test::More tests => 23;
use Test::Exception;
use DateTime;
use Test::WWW::Mechanize::Catalyst;
use HTTP::Request::Common;
use XML::LibXML;

use t::util;

my $util = t::util->new();
local $ENV{CATALYST_CONFIG} = $util->config_path;
local $ENV{TEST_DIR}        = $util->staging_path;

$XML::LibXML::Error::WARNINGS=2;

my $mech;


{
  my $schemas;
  lives_ok { $schemas = $util->test_env_setup()}  'test db created and populated';
  use_ok 'Test::WWW::Mechanize::Catalyst', 'npg_qc_viewer';
  $mech = Test::WWW::Mechanize::Catalyst->new;

  my $dt = DateTime->now(time_zone => 'floating');
  $dt->subtract(days => 10);

  my $transaction = sub {
    my $rs_in = $schemas->{wh}->resultset('NpgInformation');
    foreach my $p (qw/1 2 3 4 5 6 7 8/) {
      $rs_in->update_or_create({id_run => 4025, batch_id=>4965, position => $p, run_complete => $dt,});
      $rs_in->update_or_create({id_run => 4950, batch_id=>7122, position => $p, run_complete => $dt,});
    }
  };
  lives_ok {$schemas->{wh}->txn_do($transaction);} 'date changes ok in the test database';
}

{
  my $url = q[http://localhost/checks/people];
  $mech->get_ok($url);
  $mech->title_is(q[Library creators and libraries sequenced within 2 weeks]);

  $url = q[http://localhost/checks/people?weeks=1];
  $mech->get_ok($url);
  $mech->title_is(q[Library creators and libraries sequenced within 1 week]);
}

{
    use_ok 'Catalyst::Test', 'npg_qc_viewer';
    my $url = q[http://localhost/checks/people];
    my $request = GET($url);
    my $responce;
    ok( $responce = request($request),  qq[request to $url] );
    ok( $responce->is_success, qq[request to $url is successful]);
    my $content = $responce->content();
    my $parser_options =      {recover => 0, 
                               no_network => 0, 
                               supress_errors => 0,
                               supress_warnings => 0,
                               pedantic_parser => 0,
                               load_ext_dtd    => 1,
                               complete_attributes => 0,
                               validation => 1,
                               line_numbers  => 1,
                              };
    my $xml_parser = XML::LibXML->new($parser_options);
    eval { $xml_parser->parse_html_string($content); };

    ok ( (!ref($@) || ($@->message() =~ /Content\ error\ in\ the\ external\ subset/)), 'XML parsed OK');

    if (ref($@) && $@->message() !~ /Content\ error\ in\ the\ external\ subset/ ) { 
      diag $@->context();
      diag q[error ] . $@->message();
      diag q[line ] . $@->line();
      diag q[column ] . $@->column();
    }
}


{
  my $url = q[http://localhost/checks/people?name=za2];
  $mech->get_ok($url);
  $mech->title_is(q[Libraries by za2, sequenced within the last 2 weeks]);
  $mech->content_contains('run 4025 lane 8');
  $mech->content_lacks('run 4025 lane 1');
  $mech->content_lacks('run 4950 lane 1');

  $url = q[http://localhost/checks/people?name=dvs&name=ob1&weeks=1];
  $mech->get_ok($url);
  $mech->title_is(q[Libraries by dvs, ob1, sequenced within the last week]);

  $url = q[http://localhost/checks/people?name=dvs&name=ob1&weeks=2];
  $mech->get_ok($url);
  $mech->title_is(q[Libraries by dvs, ob1, sequenced within the last 2 weeks]);
  $mech->content_contains('run 4025 lane 1');
  $mech->content_lacks('run 4025 lane 8');
  $mech->content_contains('run 4950 lane 1');
}




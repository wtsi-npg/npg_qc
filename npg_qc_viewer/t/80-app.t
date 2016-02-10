use strict;
use warnings;
use Test::More tests => 31;
use Test::Exception;
use HTTP::Request::Common;
use XML::LibXML;
use t::util;

BEGIN {
  local $ENV{'HOME'} = 't/data';
  use_ok('npg_qc_viewer::Util::FileFinder'); #we need to get listing of staging areas from a local conf file
}

# programmatically adding break points $DB::single = 1;
# run under the debugger perl -Ilib -d t/test.t
# set CATALYST_SERVER = 1 to test against a running server

my $util = t::util->new();
$util->modify_logged_user_method();

local $ENV{CATALYST_CONFIG} = $util->config_path;
local $ENV{TEST_DIR}        = $util->staging_path;

my $schemas;
{
  lives_ok { $schemas = $util->test_env_setup()}  'test db created and populated';
  use_ok 'Catalyst::Test', 'npg_qc_viewer';
  my $values = { id_run             => 4025,
                 position           => 1,
                 path               => '/some/path',
                 number_of_snps     => '1351960',
                 number_of_reads    => '7035086',
                 avg_depth          => '5.20',
                 freemix            => '0.00316',
                 freeLK0            => '2393541.68',
                 freeLK1            => '2392830.84',
                 pass               => '1',
                 tag_index          => '1' };
  $schemas->{'qc'}->resultset("VerifyBamId")->create($values);
}

{
  my $response = request(GET(q[/]));
  ok( $response->is_redirect, 'root page request redirected');
}

{
  $XML::LibXML::Error::WARNINGS=2;
  my $parser_options =        {recover => 0, 
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

  my @urls = ();
  push @urls, q[http://localhost/checks]; 
  push @urls, q[http://localhost/checks/about];
  my $lib = q[NT28560W];
  push @urls, qq[http://localhost/checks/libraries?id=$lib];
  my $sample_id = 9272;
  push @urls, qq[http://localhost/checks/samples/$sample_id];
  $sample_id = 9286;
  push @urls, qq[http://localhost/checks/samples/$sample_id];
  my $run_id = 3965;
  push @urls, qq[http://localhost/checks/runs/$run_id];
  $run_id = 4025;
  push @urls, qq[http://localhost/checks/runs/$run_id];
  push @urls, qq[http://localhost/checks/runs-from-staging/$run_id];
  push @urls, q[http://localhost/checks/path?path=t/data/results];
  
  for my $url (@urls) {
    my $response = request(GET($url));
    ok( $response->is_success, qq[request to $url is successful]);
    is( $response->content_type, q[text/html], 'HTML content type');
    my $content = $response->content();
    eval { $xml_parser->load_html(string => $content); };
    ok ( (!ref($@) || ($@->message() =~ /Content\ error\ in\ the\ external\ subset/)), 'XML parsed OK');
    if (ref($@) && $@->message() !~ /Content\ error\ in\ the\ external\ subset/ ) { 
      diag $@->context();
      diag q[error ] . $@->message();
      diag q[line ] . $@->line();
      diag q[column ] . $@->column();
    }
  }
}

1;


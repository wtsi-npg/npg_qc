use strict;
use warnings;
use Test::More tests => 44;
use Test::Exception;
use HTTP::Headers;
use HTTP::Request::Common;
use XML::LibXML;
use Carp;

use t::util;

# programmatically adding break points $DB::single = 1;
# run under the debugger perl -Ilib -d t/test.t
# set CATALYST_SERVER = 1 to test against a running surver

my $util = t::util->new();
local $ENV{CATALYST_CONFIG} = $util->config_path;
local $ENV{TEST_DIR}        = $util->staging_path;


{
  my $schemas;
  lives_ok { $schemas = $util->test_env_setup()}  'test db created and populated';
  use_ok 'Catalyst::Test', 'npg_qc_viewer';
  $schemas->{wh}->resultset('NpgPlexInformation')->search({id_run => 4950, 'tag_index' => {'!=' => 0,},})->update({sample_id=>118118,});
}

{
  my $request = GET(q[/]);
  my $responce;
  ok( $responce = request($request),  'basic request to the root page' );
  ok( $responce->is_redirect, 'root page request redirected');
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
  my $project_id = 378;
  push @urls, qq[http://localhost/checks/studies/$project_id];
  my $lib = q[Exp2_PD2126a_WGA+1];
  push @urls, qq[http://localhost/checks/libraries?name=$lib];
  my $sample_id = 9184;
  push @urls, qq[http://localhost/checks/samples/$sample_id];
  $sample_id = 9286;
  push @urls, qq[http://localhost/checks/samples/$sample_id];
  my $run_id = 3965;
  push @urls, qq[http://localhost/checks/runs/$run_id];
  $run_id = 4025;
  push @urls, qq[http://localhost/checks/runs/$run_id];
  push @urls, qq[http://localhost/checks/runs-from-staging/$run_id];
  push @urls, q[http://localhost/checks/path?path=t/data/results];

  foreach my $url (@urls) {

    my $request = GET($url);
    my $responce;
    ok( $responce = request($request),  qq[request to $url] );
    ok( $responce->is_success, qq[request to $url is successful]);
    is( $responce->content_type, q[text/html], 'HTML content type');
    my $content = $responce->content();
    eval { $xml_parser->parse_html_string($content); };

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


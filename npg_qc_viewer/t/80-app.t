use strict;
use warnings;
use Test::More tests => 50;
use Test::Exception;
use HTTP::Headers;
use HTTP::Request::Common;
use XML::LibXML;
use Carp;
use Test::Warn;
use List::MoreUtils qw ( each_array );

use t::util;

BEGIN {
  local $ENV{'HOME'} = 't/data';
  use_ok('npg_qc_viewer::Util::FileFinder'); #we need to get listing of staging areas from a local conf file
}

# programmatically adding break points $DB::single = 1;
# run under the debugger perl -Ilib -d t/test.t
# set CATALYST_SERVER = 1 to test against a running server

my $util = t::util->new();
local $ENV{CATALYST_CONFIG} = $util->config_path;
local $ENV{TEST_DIR}        = $util->staging_path;

my $schemas;
{
  lives_ok { $schemas = $util->test_env_setup()}  'test db created and populated';
  use_ok 'Catalyst::Test', 'npg_qc_viewer';
}

{
  my $request = GET(q[/]);
  my $response;
  ok( $response = request($request),  'basic request to the root page' );
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

  my $npgqc = $schemas->{qc};
  my $values = { id_verify               => 200000,
                 id_run             => 4025,
                 position           => 1,
                 path               => '/some/path',
                 number_of_snps     => '1351960',
                 number_of_reads    => '7035086',
                 avg_depth          => '5.20',
                 freemix            => '0.00316',
                 freeLK0            => '2393541.68',
                 freeLK1            => '2392830.84',
                 pass               => '1',
                 info               => '{\"Check\":\"npg_qc::autoqc::checks::verify_bam_id\",\"Verify_options\":\" --bam /paht/file.vcf.gz --self --ignoreRG --minQ 20 --minAF 0.05 --maxDepth 500 --precise --out /path/4025_1.bam\",\"Check_version\":\"59.2\",\"Verifier\":\"verifyBamID\"}',
                 tag_index          => '1' };
  my $row = $npgqc->resultset("VerifyBamId")->create($values);

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
  
  my $warn_id            = qr/Use of uninitialized value \$id in exists/;
  my $warn_command       = qr/Use of uninitialized value \$command in pattern match/;
  
  my @warnings = ();
  push @warnings, [$warn_id,];
  push @warnings, [$warn_id,];
  push @warnings, [$warn_id,];
  push @warnings, [$warn_id,];
  push @warnings, [$warn_id,];
  push @warnings, [$warn_id,];
  push @warnings, [$warn_id,];
  push @warnings, [$warn_id,];
  push @warnings, [$warn_command, $warn_command, $warn_command, $warn_command, $warn_id,];

  my $it = each_array( @urls, @warnings );
  while ( my ($url, $warning_set) = $it->() ) {
    my $request = GET($url);
    my $response;
    warnings_like{
      ok( $response = request($request),  qq[request to $url] )
    } $warning_set ,
       'Expected warning';
    
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


use strict;
use warnings;
use lib 't/lib';
use Test::More tests => 39;
use Test::Exception;
use File::Spec;

use t::util;

my $util = t::util->new(db_connect => 1);
local $ENV{CATALYST_CONFIG} = $util->config_path;
my $schemas = $util->test_env_setup();

use_ok 'Catalyst::Test', 'npg_qc_viewer';
use_ok 'npg_qc_viewer::Controller::Visuals';
use_ok 'npg_qc::autoqc::db_loader';

my $path = File::Spec->catfile('t', 'data', 'qualmap');

{
  my $url = '/visuals/qualmap_legend';
  my $response;
  lives_ok { $response = request($url) }  qq[$url request] ;
  ok( $response->is_success, qq[$url request succeeds] );
  is( $response->content_type, q[image/png], 'image/png content type');
}

{
  my @urls = ();
  push @urls,  '/visuals/qualmap';
  push @urls, q[/visuals/qualmap?db_lookup=0&paths_list=] . $path;
  push @urls,  '/visuals/qualmap?db_lookup=0&rpt_list=45:1';
  push @urls,  '/visuals/qualmap?db_lookup=0&rpt_list=45:1:3&read=reverse';
  push @urls,  '/visuals/qualmap?db_lookup=0&rpt_list=45:1%3B45:2&read=reverse'; # 45:1;45:2
  push @urls, q[/visuals/qualmap?db_lookup=0&paths_list=t&read=forward&rpt_list=4360:1];

  my $response;
  foreach my $url (@urls) {
    lives_ok { $response = request($url) } qq[$url request] ;
    ok( $response->is_error, q[response is an error] );
    is( $response->code, 500, q[error code is 500] );
    is( $response->content_type, q[text/html], 'text/html content type');
  }
}

{
  my @urls = ();
  my $file_path = join q[/], $path, '26607_1%2320_F0xB00.samtools_stats.json';
  push @urls, q[/visuals/qualmap?file_path=] . $file_path . q[&read=forward&rpt_list=26607:1:20];
  push @urls, q[/visuals/qualmap?file_path=] . $file_path . q[&read=forward&rpt_list=26607:1:20&db_lookup=0];

  my $response;
  foreach my $url (@urls) {
    lives_ok { $response = request($url) } qq[$url request] ;
    ok( $response->is_success, qq[$url request succeeds] );
    is( $response->content_type, q[image/png], 'image/png content type');
  }
}

{
  my $file_path = join q[/], $path, '26607_1#20_F0xB00.samtools_stats.json';
  npg_qc::autoqc::db_loader->new(json_file => [$file_path],
                                 schema    => $schemas->{'qc'},
                                 verbose   => 0)->load();
  my $url =  q[/visuals/qualmap?read=reverse&rpt_list=26607:1:20&db_lookup=1];
  my $response;
  lives_ok { $response = request($url) } qq[$url request] ;
  ok( $response->is_success, qq[$url request succeeds] );
  is( $response->content_type, q[image/png], 'image/png content type');
}

1;

use strict;
use warnings;
use Test::More tests => 22;
use Test::Exception;
use Cwd;
use File::Spec;

use t::util;

my $util = t::util->new(db_connect => 0);
local $ENV{CATALYST_CONFIG} = $util->config_path;

{
  use_ok 'Catalyst::Test', 'npg_qc_viewer';
  use_ok 'npg_qc_viewer::Controller::Visuals'
}

{
  my $url = '/visuals/fastqcheck_legend';
  my $responce;
  lives_ok { $responce = request($url) }  qq[$url request] ;
  ok( $responce->is_success, qq[$url request succeeds] );
  is( $responce->content_type, q[image/png], 'image/png content type');
}


{
  my @urls = ();
  push @urls,  '/visuals/fastqcheck';
  my $path = File::Spec->catfile(cwd, 't', 'data', 'sources4visuals', 'empty.fastqcheck');
  push @urls, q[/visuals/fastqcheck?path=] . $path;

  my $responce;
  foreach my $url (@urls) {
    lives_ok { $responce = request($url) } qq[$url request] ;
    ok( $responce->is_error, q[responce is an error] );
    is( $responce->code, 500, q[error code is 500] );
    is( $responce->content_type, q[text/html], 'text/html content type');
  }
}


{
  my $path = File::Spec->catfile(cwd, 't', 'data', 'sources4visuals', '4360_1_1.fastqcheck');

  my @urls = ();
  push @urls, q[/visuals/fastqcheck?path=] . $path;
  push @urls, q[/visuals/fastqcheck?path=] . $path . q[&read=forward];
  push @urls, q[/visuals/fastqcheck?path=] . $path . q[&read=forward&db_lookup=0];

  my $responce;
  foreach my $url (@urls) {
    lives_ok { $responce = request($url) } qq[$url request] ;
    ok( $responce->is_success, qq[$url request succeeds] );
    is( $responce->content_type, q[image/png], 'image/png content type');
  }
}

1;

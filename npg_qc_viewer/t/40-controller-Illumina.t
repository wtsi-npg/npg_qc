use strict;
use warnings;
use lib 't/lib';
use Test::More tests => 16;
use Test::Exception;

use t::util;

my $util = t::util->new(db_connect => 1);
local $ENV{CATALYST_CONFIG} = $util->config_path;
$util->test_env_setup();

use_ok 'Catalyst::Test', 'npg_qc_viewer';
use_ok 'npg_qc_viewer::Controller::Illumina';

{
  foreach my $url (qw(/illumina /illumina/runs)) {
    my $response;
    lives_ok { $response = request($url) }  qq[$url request] ;
    ok( $response->is_error, qq[error requesting $url] );
    is( $response->code, 404, 'error code is 404');
  }

  foreach my $url (qw(/illumina/runs/3055 /illumina/runs/30055)) {
    my $response;
    lives_ok { $response = request($url) }  qq[$url request] ;
    ok( $response->is_success, qq[$url request is OK] );
    is( $response->code, 200, 'status code is 200');
    is( $response->content_type, q[text/html], 'text/html content type');
  }
}

1;

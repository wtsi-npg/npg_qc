use strict;
use warnings;
use Test::More tests => 10;
use Test::Exception;
use Cwd;
use File::Spec;

use t::util;

my $util = t::util->new();
local $ENV{CATALYST_CONFIG} = $util->config_path;
local $ENV{TEST_DIR}        = $util->staging_path;

my $fname = 'new.fastqcheck';
{
  my $schemas;
  lives_ok { $schemas = $util->test_env_setup()}  'test dbs created and populated';

  open my $fh, '<', File::Spec->catfile(cwd, 't', 'data', 'sources4visuals', '4360_1_1.fastqcheck');
  local $/ = undef;
  my $text = <$fh>;
  close $fh;

  my $rs = $schemas->{qc}->resultset('Fastqcheck');
  $rs->create({section => 'forward', id_run => 4360, position => 1, file_name => $fname, file_content => $text,});
  is ($rs->search({file_name => $fname})->count, 1, 'one fastqcheck file saved');
}

{
  use_ok 'Catalyst::Test', 'npg_qc_viewer';
  use_ok 'npg_qc_viewer::Controller::Visuals';
}

{
  my $path = File::Spec->catfile(cwd, 't', 'data', '4360_1_1.fastqcheck');
  my $url  = q[/visuals/fastqcheck?path=] . $path . q[&db_lookup=1];
  my $responce;
  lives_ok { $responce = request($url) } qq[$url request] ;
  ok( $responce->is_error, q[responce is an error] );
  is( $responce->code, 500, q[error code is 500] );
}

1;



{
  my $url  = q[/visuals/fastqcheck?path=] . $fname . q[&db_lookup=1];
  my $responce;
  lives_ok { $responce = request($url) } qq[$url request] ;
  ok( $responce->is_success, qq[$url request succeeds] );
  is( $responce->content_type, q[image/png], 'image/png content type');
}

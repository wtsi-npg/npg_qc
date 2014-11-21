use strict;
use warnings;
use Test::More tests => 19;
use Test::Exception;

use Test::WWW::Mechanize::Catalyst;

use t::util;

my $util = t::util->new();
local $ENV{CATALYST_CONFIG} = $util->config_path;
local $ENV{TEST_DIR}        = $util->staging_path;

my $mech;


{
  my $schemas;
  lives_ok { $schemas = $util->test_env_setup()}  'test db created and populated';
  use_ok 'Test::WWW::Mechanize::Catalyst', 'npg_qc_viewer';
  $mech = Test::WWW::Mechanize::Catalyst->new;
  $schemas->{wh}->resultset('NpgPlexInformation')->search({id_run => 4950, 'tag_index' => {'!=' => 0,},})->update({sample_id=>118118,});
}


{
  my $url = q[http://localhost/checks/samples];
  $mech->get_ok($url);
  $mech->title_is(q[List of samples]);
  my @samples = qw( B1267_Exp4
                    B3006_Exp4
                    B3009_Exp4
                    Exp2_PD2126a_WGA
                    Exp2_PD2126b_WGA
                    NA18545pd2a
                    NA18563pd2a
                    NA18623pd2a
                    NA18633pda
                    OX008_dscDNA
                    AC0001C
                    HG00367-B
                  );

  foreach my $sample (@samples) {
      $mech->content_contains($sample);
  }

  @samples = qw(NA18615 NA18619 NA19436);
  foreach my $sample (@samples) {
      $mech->content_lacks( $sample );
  }
}



use strict;
use warnings;
use Test::More tests => 13;
use Test::Exception;
use Test::Warn;

use Test::WWW::Mechanize::Catalyst;

use t::util;

my $util = t::util->new();
local $ENV{CATALYST_CONFIG} = $util->config_path;
local $ENV{TEST_DIR}        = $util->staging_path;

my $mech;


{
  lives_ok { $util->test_env_setup()}  'test db created and populated';
  use_ok 'Test::WWW::Mechanize::Catalyst', 'npg_qc_viewer';
  $mech = Test::WWW::Mechanize::Catalyst->new;
}

{
  my $study_id = 188;
  my $url = qq[http://localhost/checks/studies/$study_id];
  warnings_like{$mech->get_ok($url)} [qr/Failed to get runfolder location/, 
                                      qr/Use of uninitialized value \$id in exists/], 
                                      'Expected warning for runfolder location';
  $mech->title_is(q[Study 'HumanEvolution2']);
  my @samples = qw( 
                    NA18545pd2a
                    NA18563pd2a
                    NA18623pd2a
                    NA18633pda
                  );


  foreach my $sample (@samples) {
      $mech->content_contains($sample);
  }

  my @provenances = (
q[NA18545pd2a 1 &lt;&lt; NA18545pd2a &lt;&lt; HumanEvolution2],
q[NA18623pd2a 1 &lt;&lt; NA18623pd2a &lt;&lt; HumanEvolution2],
q[NA18563pd2a 1 &lt;&lt; NA18563pd2a &lt;&lt; HumanEvolution2],
q[NA18633pda 1 &lt;&lt; NA18633pda &lt;&lt; HumanEvolution2]
                    );

  foreach my $provenance (@provenances) {
      $mech->content_contains($provenance);
  }
}


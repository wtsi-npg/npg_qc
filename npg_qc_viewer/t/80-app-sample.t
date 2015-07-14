use strict;
use warnings;
use Test::More tests => 3;
use Test::Exception;
use Test::Warn;
use List::MoreUtils qw ( each_array );

use Test::WWW::Mechanize::Catalyst;

local $ENV{'HOME'}='t/data';
use t::util;

my $util = t::util->new();
local $ENV{CATALYST_CONFIG} = $util->config_path;
local $ENV{TEST_DIR}        = $util->staging_path;

my $mech;

subtest 'Initial' => sub {
  plan tests => 2;
  lives_ok { $util->test_env_setup()}  'test db created and populated';
  use_ok 'Test::WWW::Mechanize::Catalyst', 'npg_qc_viewer';
  $mech = Test::WWW::Mechanize::Catalyst->new;
};

subtest 'Sample 9184' => sub {
  plan tests => 4;
  my $sample_id = 9184;
  my $url = qq[http://localhost/checks/samples/$sample_id];
  warnings_like{$mech->get_ok($url)} [qr/Use of uninitialized value \$id in exists/,], 
                                      'Expected warning for uninitialized id';
  $mech->title_is(q[Sample 'Exp2_PD2126a_WGA']);
  $mech->content_contains(q[Exp2_PD2126a_WGA 1 &lt;&lt; Exp2_PD2126a_WGA &lt;&lt; Renal Cancer Exome]);
};

subtest 'Full provenance in title for different samples of same run' => sub {
  plan tests => 16;
  my @samples = qw(9389
                   9388
                   9386
                   9387);
  
  my @sample_names = qw(NA18545pd2a
                        NA18563pd2a
                        NA18623pd2a
                        NA18633pda);

  my @provenances = (q[NA18545pd2a 1 &lt;&lt; NA18545pd2a &lt;&lt; HumanEvolution2],
                     q[NA18563pd2a 1 &lt;&lt; NA18563pd2a &lt;&lt; HumanEvolution2],
                     q[NA18623pd2a 1 &lt;&lt; NA18623pd2a &lt;&lt; HumanEvolution2],
                     q[NA18633pda 1 &lt;&lt; NA18633pda &lt;&lt; HumanEvolution2]);

  my $it = each_array( @samples, @sample_names, @provenances);
  while ( my ($sample_id, $sample_name, $provenance) = $it->() ) {
    my $url = qq[http://localhost/checks/samples/$sample_id];
    warnings_like{$mech->get_ok($url)} [qr/Use of uninitialized value \$id in exists/,], 
                                        'Expected warning for uninitialized id';
    $mech->title_is(qq[Sample '$sample_name']);
    $mech->content_contains($provenance);
  }
};

1;


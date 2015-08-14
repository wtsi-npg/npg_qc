use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;
use Test::Warn;
use List::MoreUtils qw ( each_array );

use Test::WWW::Mechanize::Catalyst;

BEGIN {
  local $ENV{'HOME'} = 't/data';
}
use t::util;

my $schemas;
my $util = t::util->new();
local $ENV{CATALYST_CONFIG} = $util->config_path;
local $ENV{TEST_DIR}        = $util->staging_path;

my $mech;

subtest 'Initial' => sub {
  plan tests => 2;
  lives_ok { $schemas = $util->test_env_setup()}  'test db created and populated';
  use_ok 'Test::WWW::Mechanize::Catalyst', 'npg_qc_viewer';
  $mech = Test::WWW::Mechanize::Catalyst->new;
};

subtest 'Sample without link to flowcell' => sub {
  plan tests => 3;
  my $mlwh   = $schemas->{mlwh};
  
  my $id_sample_lims = 2109;
  my $values = { id_sample_tmp    => 5064,
                 uuid_sample_lims => '4a1e3190-b9c2-11df-9e66-00144f01a414',
                 id_lims          => 'SQSCP',
                 last_updated     => '2012-08-03 10:07:02',
                 recorded_at      => '2012-08-03 10:07:02',
                 created          => '2012-08-03 10:07:02',
                 id_sample_lims   => $id_sample_lims,
                 name             => q[random_sample_name],
  };
  my $row = $mlwh->resultset("Sample")->create($values);
  
  my $url = qq[http://localhost/checks/samples/$id_sample_lims];
  warnings_like{$mech->get_ok($url)} [ qr/Use of uninitialized value \$id in exists/,], 
                                       'Expected warning for runfolder location';
  $mech->title_is(qq[NPG SeqQC v${npg_qc_viewer::VERSION}: Sample 'random_sample_name']);
};

subtest 'Sample 9272' => sub {
  plan tests => 4;
  my $sample_id = 9272; #id_run 4025
  my $version = $npg_qc_viewer::VERSION;
  my $url = qq[http://localhost/checks/samples/$sample_id];
  warnings_like{$mech->get_ok($url)} [ qr/Use of uninitialized value \$id in exists/, ], 
                                       'Expected warnings';
  $mech->title_is(qq[NPG SeqQC v${version}: Sample 'random_sample_name']);
  $mech->content_contains(q[NT28560W &lt;&lt; random_sample_name &lt;&lt; random_study_name]);
};

subtest 'Full provenance in title for different samples of same run' => sub {
  plan tests => 5;
  
  my $version = $npg_qc_viewer::VERSION;
  
  my @samples = qw( 11082 );
  
  my @sample_names = qw( random_sample_name );

  my @provenances = (q[NT19992S &lt;&lt; random_sample_name &lt;&lt; random_study_name], );

  my $it = each_array( @samples, @sample_names, @provenances);
  while ( my ($sample_id, $sample_name, $provenance) = $it->() ) {
    my $url = qq[http://localhost/checks/samples/$sample_id];
    warnings_like{$mech->get_ok($url)} [ { carped => qr/No paths to run folder found/ },
                                         qr/Use of uninitialized value \$id in exists/,], 
                                         'Expected warning for uninitialized id';
    $mech->title_is(qq[NPG SeqQC v${version}: Sample '$sample_name']);
    $mech->content_contains($provenance);
  }
};

1;


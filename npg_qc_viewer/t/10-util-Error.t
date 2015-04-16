use strict;
use warnings;
use Test::More tests => 14;
use Test::Exception;

use_ok 'npg_qc_viewer::Util::Error';

{
  my $m = 'Some error occured';
  throws_ok { npg_qc_viewer::Util::Error->compose_error() }
    qr/Message should be given/, 'error when no message is supplied';
  is(npg_qc_viewer::Util::Error->compose_error($m), $m, 'unaltered message');
  my $expected_m = qq[SeqQC error code 2233. $m];
  is(npg_qc_viewer::Util::Error->compose_error($m, 2233),
    $expected_m, 'message with an error code');

  throws_ok { npg_qc_viewer::Util::Error->parse_error() }
    qr/Message should be given/, 'error when no message is supplied';
  my ($error, $code) = npg_qc_viewer::Util::Error->parse_error($m);
  is($error, $m, 'error message as supplied');
  is($code, 500, 'error code 500');

  throws_ok { npg_qc_viewer::Util::Error->raise_error() }
    qr/Message should be given/, 'error when no message is supplied';
  throws_ok {npg_qc_viewer::Util::Error->raise_error($m)}
    qr/$m/, 'correct error is raised';
  throws_ok {npg_qc_viewer::Util::Error->raise_error($m, 2233)}
    qr/$expected_m/, 'correct error is raised';
  
  ($error, $code) = npg_qc_viewer::Util::Error->parse_error(qq[SeqQC error code 2233. $m]);
  is($error, $m, 'error message correct');
  is($code, 2233, 'error code correct');
  $m = qq[some error code 2233. $m];
  ($error, $code) = npg_qc_viewer::Util::Error->parse_error($m);
  is($error, $m, 'error message as supplied');
  is($code, 500, 'error code 500');
}

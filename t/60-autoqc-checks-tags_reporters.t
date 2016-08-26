use strict;
use warnings;
use Cwd;
use Test::More tests => 3;
use Test::Exception;

my $ref_repos = cwd . '/t/data/autoqc';

use_ok ('npg_qc::autoqc::checks::tags_reporters');

SKIP: { skip 'require bammaskflags', 2 unless `which bammaskflags`;

  my $r = npg_qc::autoqc::checks::tags_reporters->new(
    repository => $ref_repos, id_run => 2, qc_in => q[t], position => 1);
  isa_ok ($r, 'npg_qc::autoqc::checks::tags_reporters');

  lives_ok { $r->result; } 'No error creating result object';
}

1;

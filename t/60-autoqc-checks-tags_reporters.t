#########
# Author:        kl2
# Created:       6 September 2013
#

use strict;
use warnings;
use Cwd;
use File::Temp qw/ tempdir /;
use Test::More tests => 3;
use Test::Exception;

my $ref_repos = cwd . '/t/data/autoqc';

SKIP: { skip 'require bammaskflags', 3, unless `which bammaskflags`;

use_ok ('npg_qc::autoqc::checks::tags_reporters');

my $dir = tempdir(CLEANUP => 1);
local $ENV{PATH} = join q[:], $dir, $ENV{PATH};

{
    my $r = npg_qc::autoqc::checks::tags_reporters->new(repository => $ref_repos, id_run => 2, path => q[mypath], position => 1);
    isa_ok ($r, 'npg_qc::autoqc::checks::tags_reporters');
}

{
    my $r = npg_qc::autoqc::checks::tags_reporters->new(repository => $ref_repos, id_run => 2, path => q[mypath], position => 1);
    lives_ok { $r->result; } 'No error creating result object';
}
}

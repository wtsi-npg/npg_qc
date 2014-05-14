#########
# Author:        kl2
# Maintainer:    $Author$
# Created:       6 September 2013
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

use strict;
use warnings;
use Cwd;
use File::Temp qw/ tempdir /;
use Test::More tests => 3;
use Test::Exception;

my $ref_repos = cwd . '/t/data/autoqc';

use_ok ('npg_qc::autoqc::checks::upstream_tags');

my $dir = tempdir(CLEANUP => 1);
`touch $dir/BamIndexDecoder.jar`;
local $ENV{CLASSPATH} = $dir; 

{
    my $r = npg_qc::autoqc::checks::upstream_tags->new(repository => $ref_repos, id_run => 2, path => q[mypath], position => 1);
    isa_ok ($r, 'npg_qc::autoqc::checks::upstream_tags');
}

{
    
    my $r = npg_qc::autoqc::checks::upstream_tags->new(repository => $ref_repos, id_run => 2, path => q[mypath], position => 1);
    lives_ok { $r->result; } 'No error creating result object';
}


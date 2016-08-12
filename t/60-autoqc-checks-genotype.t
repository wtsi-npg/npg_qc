use strict;
use warnings;
use Cwd;
use File::Temp qw/ tempdir /;
use Test::More tests => 7;
use Test::Exception;

use_ok ('npg_qc::autoqc::checks::genotype');

my $ref_repos = cwd . '/t/data/autoqc';
my $dir = tempdir(CLEANUP => 1);
my $st = join q[/], $dir, q[samtools_irods];
`touch $st`;
`chmod +x $st`;
my $bt = join q[/], $dir, q[bcftools1];
`touch $bt`;
`chmod +x $bt`;
local $ENV{PATH} = join q[:], $dir, $ENV{PATH};

{
    
    my $r = npg_qc::autoqc::checks::genotype->new(
        repository => $ref_repos, id_run => 2, path => q[t], position => 1);
    isa_ok ($r, 'npg_qc::autoqc::checks::genotype');
    lives_ok { $r->result; } 'No error creating result object';
    lives_ok {$r->samtools } 'No error calling "samtools" accessor';
    is($r->samtools, $st, 'correct samtools path');
    lives_ok {$r->bcftools } 'No error calling "bcftools" accessor';
    is($r->bcftools, $bt, 'correct bcftools path');
}

1;


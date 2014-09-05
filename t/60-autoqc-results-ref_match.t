#########
# Author:        jo3
# Created:       30 July 2009
#

use strict;
use warnings;
use Test::More tests => 14;
use Test::Deep;
use Test::Exception;
use English qw(-no_match_vars);
use Carp;

use_ok('npg_qc::autoqc::results::ref_match');

my $r = npg_qc::autoqc::results::ref_match->new(
            id_run   => 12,
            position =>  3,
            path     => q[mypath]
);

isa_ok( $r, 'npg_qc::autoqc::results::ref_match' );
is( $r->check_name(), 'ref match', 'Check name' );
is( $r->class_name(), 'ref_match', 'Class name' );

$r->aligned_read_count(
    {
        Homo_sapiens          => 5_000,
        Danio_rerio           =>     0,
        Mus_musculus          =>   100,
        Clostridium_difficile =>   300,
    }
);

$r->reference_version(
    {
        Homo_sapiens          => 'NCBI37',
        Danio_rerio           => 'v9',
        Mus_musculus          => 'NCBIm37',
        Clostridium_difficile => 'Strain_630',
    }
);

$r->sample_read_count(10_000);

is_deeply(
    $r->percent_count(),
    {
        Homo_sapiens          => '50.0',
        Danio_rerio           =>  '0.0',
        Mus_musculus          =>  '1.0',
        Clostridium_difficile =>  '3.0',
    },
    'Calculate percentages'
);

is_deeply(
    $r->reference_version(),
    {
        Homo_sapiens          => 'NCBI37',
        Danio_rerio           => 'v9',
        Mus_musculus          => 'NCBIm37',
        Clostridium_difficile => 'Strain_630',
    },
    'Reference versions aren\'t messed with'

);

my $comment1 = 'ABC';
my $comment2 = 'DEF';
lives_ok { $r->add_comment($comment1); } 'Use role to add comment';
$r->add_comment($comment2);
is( $r->comments(), "$comment1 $comment2", 'Retrieve comment' );

cmp_deeply(
    $r->ranked_organisms(),
    [
        'Homo_sapiens',
        'Clostridium_difficile',
        'Mus_musculus',
        'Danio_rerio'
    ],
    'Rank matches by percentages'
);

my $emptyresult;
lives_ok {
    $emptyresult = npg_qc::autoqc::results::ref_match->load(
                        q{t/data/autoqc/5428_2.ref_match.json} );
}
q{load JSON with no results};

my $ordered;
lives_ok { $ordered = $emptyresult->ranked_organisms(); }
         q(ranked_organisms with empty data);

#dj3: okay to return full array as well I guess - don't take too seriously...
cmp_ok( @{$ordered}, q(==), 0, q(zero sized array of organisms) );

# Make sure we're not being lazy about defaults.
is( $emptyresult->sample_read_count(), 10_100, 'Number of reads sampled' );
is( $emptyresult->sample_read_length(),    32, 'The length of those reads' );

1;

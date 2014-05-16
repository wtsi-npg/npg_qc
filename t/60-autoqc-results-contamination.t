#########
# Author:        jo3
# Maintainer:    $Author$
# Created:       30 July 2009
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

use strict;
use warnings;
use Test::More tests => 12;
use Test::Deep;
use Test::Exception;
use English qw(-no_match_vars);
use Carp;

use_ok('npg_qc::autoqc::results::contamination');

my $r = npg_qc::autoqc::results::contamination->new( id_run   => 12,
                                                     position => 3,
                                                     path     => q[mypath] );

isa_ok ( $r, 'npg_qc::autoqc::results::contamination' );
is( $r->check_name(), 'contamination', 'Check name' );
is( $r->class_name(), 'contamination', 'Class name' );

$r->genome_factor( { Homo_sapiens          => '12.4',
                     Danio_rerio           => '19.2',
                     Mus_musculus          => '13.4',
                     Clostridium_difficile =>  '1.0', } );

$r->contaminant_count( { Homo_sapiens          => 5_000,
                         Danio_rerio           =>     0,
                         Mus_musculus          =>   100,
                         Clostridium_difficile =>   300, } );

$r->read_count(0);
ok(!$r->normalised_contamination(), 'normalized measure not defined if read_count is zero');

$r->read_count(100_000);

is_deeply( $r->normalised_contamination(),
           { Homo_sapiens          => '62.0',
             Danio_rerio           =>  '0.0',
             Mus_musculus          =>  '1.3',
             Clostridium_difficile =>  '0.3', },
           'Calculate normalized measures' );

my $comment1 = 'ABC';
my $comment2 = 'DEF';
lives_ok { $r->add_comment($comment1) } 'Use role to add comment';
$r->add_comment($comment2);
is( $r->comments(), "$comment1 $comment2", 'Retrieve comment' );

cmp_deeply( $r->ranked_organisms(),
            [ 'Homo_sapiens',
              'Mus_musculus',
              'Clostridium_difficile',
              'Danio_rerio' ],
            'Rank contaminants by normalized values' );

my $emptyresult;
lives_ok {
  $emptyresult = npg_qc::autoqc::results::contamination->load(q(t/data/autoqc/4056_1.contamination.json));
} q(load JSON with no results);
my $ordered;
lives_ok {
  $ordered = $emptyresult->ranked_organisms ;
} q(ranked_organisms with empty data);
cmp_ok(@{$ordered}, q(==), 0, q(zero sized array of organisms)); #dj3: okay to return full array as well I guess - don't take too seriously....

1;

#########
# Author:        mg8
# Maintainer:    $Author$
# Created:       30 July 2009
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

use strict;
use warnings;
use Test::More tests => 25;
use Test::Deep;
use Test::Exception;
use English qw(-no_match_vars);
use Carp;

our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/mx; $r; };

use_ok ('npg_qc::autoqc::results::insert_size');

{
    my $r = npg_qc::autoqc::results::insert_size->new(id_run => 12, position => 3, path => q[mypath]);
    isa_ok ($r, 'npg_qc::autoqc::results::insert_size');
}


{
    my $r = npg_qc::autoqc::results::insert_size->new(id_run => 12, position => 3, path => q[mypath]);
    is($r->check_name(), 'insert size', 'check name');
    is($r->class_name(), 'insert_size', 'class name');
}


{
    my $r = npg_qc::autoqc::results::insert_size->new(id_run => 12, position => 3, path => q[mypath]);
    is($r->criterion(), q[The value of the third quartile is larger than the lower boundary of the expected size], 'criteria');
}


{
    my $r = npg_qc::autoqc::results::insert_size->new(id_run => 12, position => 3, path => q[mypath]);
    my $comment1 = q[my comment];
    $r->add_comment($comment1);
    is($r->comments, $comment1, 'one comment added');
    my $comment2 = q[your comment];
    $r->add_comment($comment2);
    is($r->comments, $comment1 . q[ ] . $comment2, 'two comments added');
}


{
    my $r = npg_qc::autoqc::results::insert_size->new(id_run => 12, position => 3, path => q[mypath]);
    is($r->image_url(), q[], 'empty google url if bins not set');
}


{
    my $r = npg_qc::autoqc::results::insert_size->new(id_run => 12, position => 3, path => q[mypath]);
    $r->bins([17,22,32,69,87,87,109,143,175,152,173,200,174,189,195,212,191,190,194,187,232,174,180,203,190,166,162,169,182,149,129,131,150,122,118,120,113,122,97,87,124,105,86,84,62,65,68,64,61,56,45,44,39,36,33,38,43,33,24,25,39,22,29,26,23,22,19,12,24,13,14,21,11,14,11,10,7,9,7,8,6,9,6,7,4,7,5,5,2,2,3]);
    is($r->image_url(), q[], 'empty google url if bin width and min_isize not set');
}


{
    my $r = npg_qc::autoqc::results::insert_size->new(id_run => 12, position => 3, path => q[mypath]);

    my $ref_path = q[/nfs/repository/d0031/references/Human/default/all/bwa/Homo_sapiens.NCBI36.48.dna.all.fa];

    $r->bins([17,22,32,69,87,87,109,143,175,152,173,200,174,189,195,212,191,190,194,187,232,174,180,203,190,166,162,169,182,149,129,131,150,122,118,120,113,122,97,87,124,105,86,84,62,65,68,64,61,56,45,44,39,36,33,38,43,33,24,25,39,22,29,26,23,22,19,12,24,13,14,21,11,14,11,10,7,9,7,8,6,9,6,7,4,7,5,5,2,2,3]);
    $r->bin_width(4);
    $r->min_isize(37);
  
    $r->expected_mean(350);
    $r->filenames(['f1', 'f2']);
    $r->sample_size(10000);
    $r->reference($ref_path);

    my $url = q[http://chart.apis.google.com/chart?chbh=5,1,1&chco=4D89F9&chd=t:17,22,32,69,87,87,109,143,175,152,173,200,174,189,195,212,191,190,194,187,232,174,180,203,190,166,162,169,182,149,129,131,150,122,118,120,113,122,97,87,124,105,86,84,62,65,68,64,61,56,45,44,39,36,33,38,43,33,24,25,39,22,29,26,23,22,19,12,24,13,14,21,11,14,11,10,7,9,7,8,6,9,6,7,4,7,5,5,2,2,3&chds=0,232&chs=650x300&cht=bvg&chtt=Insert+sizes:+run+12,+position+3&chxr=0,37,397,45|1,0,232,46&chxt=x,y];

    is($r->image_url, $url, 'Google image URL');
    is($r->reference, $ref_path, 'reference path returned');
    is($r->sample_size, 10000, 'sample size returned');
    is($r->expected_size_range(), '350', 'expected range returned');
    is(join(q[ ], @{$r->filenames}), 'f1 f2', 'filenames returned');
}

{
    my $r = npg_qc::autoqc::results::insert_size->load(q[t/data/autoqc/insert_size/6062_8#1.insert_size.json]);
    $r->paired_reads_direction_in(0);
    my $url = q[http://chart.apis.google.com/chart?chbh=5,1,1&chco=FFCC66&chd=t:116,291,233,239,186,189,166,134,115,133,115,116,73,88,84,74,80,70,40,49,55,59,47,36,43,33,29,43,45,94,156,163,207,153,156,135,125,100,88,79,54,60,44,25,21,10,2,0,1,3,0,1,0,1,1,0,0,1,0,0,2,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1&chds=0,291&chs=650x300&cht=bvg&chtt=Insert+sizes:+run+6062,+position+8&chxr=0,96,9303,1150|1,0,291,58&chxt=x,y];
    is($r->image_url, $url, 'Google image URL');
    ok(!$r->num_well_aligned_reads_opp_dir, 'number reads aligned in opposite direction not defined');
}

{
    my $expected_mean_file = q[t/data/autoqc/insert_size_expected_mean.json];

    my $r = undef;
    lives_ok {$r = npg_qc::autoqc::results::insert_size->load($expected_mean_file);} 'loading from a json string with expected_mean defined should not die';

    is($r->expected_mean, 500, 'attr value for expected_mean');
    is($r->expected_size, undef, 'expected_size attr is not defined');
    is($r->expected_size_range(), 500, 'display value for expected mean');
}


{
    my $expected_size_file = q[t/data/autoqc/insert_size_expected_size.json];

    my $r = undef;
    lives_ok {$r = npg_qc::autoqc::results::insert_size->load($expected_size_file);} 'loading from a json string with expected_size defined should not die';
    is(join(q[ ], @{$r->expected_size}), '400 500', 'attr value for expected_size');
    is($r->expected_mean, undef, 'expected_mean attr is not defined');
    is($r->expected_size_range(), '400:500', 'display value for expected size');
}

{
    my $r = npg_qc::autoqc::results::insert_size->new(id_run => 12, 
                                                      position => 3, 
                                                      path => q[mypath],
                                                      expected_size => [34, 56, 78, 23, 83, 56, 12, 35, 22],
                                                     );
    is($r->expected_size_range(), '12:56', 'display value for expected size in case of multiple expect sizes');
}


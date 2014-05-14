#########
# Author:        Marina Gourtovaia
# Maintainer:    $Author$
# Created:       29 July 2009
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#


use strict;
use warnings;
use Test::More tests => 95;
use Test::Exception;
use Test::Warn;
use Test::Deep;
use File::Temp qw/tempdir/;

use npg_qc::autoqc::results::qX_yield;
use npg_qc::autoqc::results::insert_size;
use npg_qc::autoqc::results::split_stats;
use npg_qc::autoqc::results::adapter;

use npg_qc::autoqc::qc_store::options qw/$ALL $LANES $PLEXES/;

use_ok('npg_qc::autoqc::results::collection');

my $temp = tempdir( CLEANUP => 1);

{
    my $c = npg_qc::autoqc::results::collection->new();
    isa_ok($c, 'npg_qc::autoqc::results::collection');
}

{
    my $c = npg_qc::autoqc::results::collection->new();
    ok($c->is_empty, 'collection is empty');
    is($c->size, 0, 'empty collection has size 0');
    foreach my $pos ((1,5,7,2)) {
       $c->add(npg_qc::autoqc::results::qX_yield->new(position => $pos, id_run => 12, path => q[mypath]));
    }
    is($c->size(), 4, 'collection size');
    ok(!$c->is_empty(), 'collection is  not empty');

    $c->delete(1);
    is($c->get(1)->position, 7, 'element at index 1 removed');

    my @a = $c->all;
    cmp_ok(@a, q(==), 3, 'all list size');

    $c->clear();
    ok($c->is_empty, 'collection is empty after clearing it');
}


{
    my $c = npg_qc::autoqc::results::collection->new();
    lives_ok {$c->sort_collection(q[check_name])} 'sort OK for an empty collection';
    $c->add(npg_qc::autoqc::results::qX_yield->new(position => 8, id_run => 12, path => q[mypath]));
    lives_ok {$c->sort_collection(q[check_name])} 'sort OK for a collection with one result';
}


{
    my $c = npg_qc::autoqc::results::collection->new();
    foreach my $pos ((1,5,7,2,5,3,2)) {
       $c->add(npg_qc::autoqc::results::qX_yield->new(position => $pos, id_run => 12, path => q[mypath]));
    }
    $c->sort_collection();

    my $positions = q[];
    foreach my $r (@{$c->results}) {
        $positions .= $r->position;
    }
    is($positions, q[1223557], 'sort by position with the check name the same');
}


{
    my $c = npg_qc::autoqc::results::collection->new();
    foreach my $pos ((1,5,7,2,5,3,2)) {
       $c->add(npg_qc::autoqc::results::qX_yield->new(position => $pos, id_run => 12, path => q[mypath]));
    }
    $c->sort_collection(q[id_run]);

    my $positions = q[];
    foreach my $r (@{$c->results}) {
        $positions .= $r->position;
    }
    is($positions, q[1223557], 'sort by id_run gives the same results as sort by position when id_run is the same in all results');
}


{
    my $c = npg_qc::autoqc::results::collection->new();
    my @check_classes = qw(qX_yield insert_size insert_size qX_yield);
    foreach my $cl (@check_classes) {
        my $clpath = "npg_qc::autoqc::results::$cl";
        $c->add($clpath->new(position => 2, id_run => 12, path => q[mypath]));
    }
    $c->sort_collection(q[check_name]);

    my $names = q[];
    foreach my $r (@{$c->results}) {
        $names .= q[ ] . $r->check_name;
    }
    is($names, q[ insert size insert size qX yield qX yield], 'sort by check name with position the same');
}


{
    my $c = npg_qc::autoqc::results::collection->new();
    my @check_classes = qw(qX_yield insert_size insert_size qX_yield);
    foreach my $cl (@check_classes) {
        my $clpath = "npg_qc::autoqc::results::$cl";
        $c->add($clpath->new(position => 2, id_run => 12, path => q[mypath]));
    }
    $c->sort_collection(q[check_name]);

    my $names = q[];
    foreach my $r (@{$c->results}) {
        $names .= q[ ] . $r->check_name;
    }
    is($names, q[ insert size insert size qX yield qX yield], 'sort by name with position the same');
}


{
    my $c = npg_qc::autoqc::results::collection->new();
    $c->add(npg_qc::autoqc::results::qX_yield->new(position => 8, id_run => 12, path => q[mypath]));
    throws_ok {$c->sort_collection(q[some_name])} qr/Can only sort based on either id_run or position or check_name/, 'error when the sort criteria is invalid';
}


{
    my $c = npg_qc::autoqc::results::collection->new();
    $c->add(npg_qc::autoqc::results::qX_yield->new(   position => 8, id_run => 12, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::split_stats->new(position => 8, id_run => 12, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::adapter->new(    position => 8, id_run => 12, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::adapter->new(    position => 7, id_run => 12, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::qX_yield->new(   position => 8, id_run => 13, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::insert_size->new(position => 8, id_run => 13, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::insert_size->new(position => 6, id_run => 14, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::insert_size->new(position => 2, id_run => 14, path => q[mypath]));
    $c->sort_collection(q[id_run]);
    my $r = $c->get(0);
    ok($r->id_run == 12 && $r->position == 7 && $r->class_name eq q[adapter], 'result No 0 after sorting by id_run');
    $r = $c->get(1);
    ok($r->id_run == 12 && $r->position == 8 && $r->class_name eq q[adapter], 'result No 1 after sorting by id_run');
    $r = $c->get(2);
    ok($r->id_run == 12 && $r->position == 8 && $r->class_name eq q[qX_yield], 'result No 2 after sorting by id_run');
    $r = $c->get(3);
    ok($r->id_run == 12 && $r->position == 8 && $r->class_name eq q[split_stats], 'result No 3 after sorting by id_run');
    $r = $c->get(4);
    ok($r->id_run == 13 && $r->position == 8 && $r->class_name eq q[insert_size], 'result No 4 after sorting by id_run');
    $r = $c->get(5);
    ok($r->id_run == 13 && $r->position == 8 && $r->class_name eq q[qX_yield], 'result No 5 after sorting by id_run');
    $r = $c->get(6);
    ok($r->id_run == 14 && $r->position == 2 && $r->class_name eq q[insert_size], 'result No 6 after sorting by id_run');
    $r = $c->get(7);
    ok($r->id_run == 14 && $r->position == 6 && $r->class_name eq q[insert_size], 'result No 7 after sorting by id_run');
}


{
    my $c = npg_qc::autoqc::results::collection->new();
    $c->add(npg_qc::autoqc::results::qX_yield->new(   position => 7,  id_run => 12,                 path => q[mypath]));
    $c->add(npg_qc::autoqc::results::qX_yield->new(   position => 7,  id_run => 12, tag_index => 0, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::qX_yield->new(   position => 7,  id_run => 12, tag_index => 1, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::qX_yield->new(   position => 7,  id_run => 12, tag_index => 2, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::qX_yield->new(   position => 8,  id_run => 12,                 path => q[mypath]));
    $c->add(npg_qc::autoqc::results::qX_yield->new(   position => 8,  id_run => 12, tag_index => 0, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::insert_size->new(position => 8,  id_run => 12, tag_index => 0, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::qX_yield->new(   position => 8,  id_run => 12, tag_index => 2, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::insert_size->new(position => 8,  id_run => 12, tag_index => 2, path => q[mypath]));

    $c->sort_collection(q[id_run]);
    my $r = $c->get(0);
    ok($r->position == 7 && !defined $r->tag_index, 'result No 0 after sorting by id_run');
    $r = $c->get(1);
    ok($r->position == 7 && $r->tag_index == 0, 'next result');
    $r = $c->get(2);
    ok($r->position == 7 && $r->tag_index == 1, 'next result');
    $r = $c->get(3);
    ok($r->position == 7 && $r->tag_index == 2, 'next result');
    $r = $c->get(4);
    ok($r->position == 8 && !defined $r->tag_index, 'next result');
    $r = $c->get(5);
    ok($r->position == 8 && $r->class_name eq q[insert_size] && $r->tag_index == 0, 'next result');
    $r = $c->get(6);
    ok($r->position == 8 && $r->class_name eq q[qX_yield] && $r->tag_index == 0, 'next result');
    $r = $c->get(7);
    ok($r->position == 8 && $r->class_name eq q[insert_size] && $r->tag_index == 2, 'next result');
    $r = $c->get(8);
    ok($r->position == 8 && $r->class_name eq q[qX_yield] && $r->tag_index == 2, 'next result');
}


{
    my $c = npg_qc::autoqc::results::collection->new();
    $c->add(npg_qc::autoqc::results::qX_yield->new(position => 8, id_run => 12, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::insert_size->new(position => 2, id_run => 12, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::qX_yield->new(position => 6, id_run => 12, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::insert_size->new(position => 1, id_run => 12, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::insert_size->new(position => 8, id_run => 12, path => q[mypath]));

    $c->sort_collection(q[check_name]);

    my $names = q[];
    my $positions = q[];
    foreach my $r (@{$c->results}) {
        $names .= q[ ] . $r->check_name;
        $positions .= q[ ] . $r->position;
    }
    is($names, q[ insert size insert size insert size qX yield qX yield], 'names in sort by name (primary), position (secondary)');
    is($positions, q[ 1 2 8 6 8], 'positions in sort by name (primary), position (secondary)');

    $c->sort_collection(q[position]);

    $names = q[];
    $positions = q[];
    foreach my $r (@{$c->results}) {
        $names .= q[ ] . $r->check_name;
        $positions .= q[ ] . $r->position;
    }
    is($names, q[ insert size insert size qX yield insert size qX yield], 'names in sort by position (primary), name (secondary)');
    is($positions, q[ 1 2 6 8 8], 'positions in sort by position (primary), name (secondary)');
}


{
    my $c = npg_qc::autoqc::results::collection->new();
    $c->add(npg_qc::autoqc::results::qX_yield->new(position => 8, id_run => 12, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::insert_size->new(position => 2, id_run => 12, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::qX_yield->new(position => 6, id_run => 12, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::insert_size->new(position => 1, id_run => 12, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::insert_size->new(position => 8, id_run => 12, path => q[mypath]));

    is($c->search({position => 8, id_run => 12,})->size(), 2, 'two results are found by search');
    is($c->search({position => 8, id_run => 12, tag_index => undef, })->size(), 2, 'two results are found by search');
    is($c->search({position => 8, id_run => 12, check_name => q[qX yield],})->size(), 1, 'one result is found by search');
    is($c->search({position => 8, id_run => 12, class_name => q[qX_yield],})->size(), 1, 'one result is found by search');
    is($c->search({position => 8, id_run => 12, class_name => q[qX_yield], tag_index => undef})->size(), 1, 'one result is found by search');
    is($c->search({position => 8, id_run => 12, class_name => q[qX_yield], tag_index => 5})->size(), 0, 'no results are found by search');

    $c->add(npg_qc::autoqc::results::insert_size->new(position => 8, id_run => 12, tag_index => 5, path => q[mypath]));
    is($c->search({position => 8, id_run => 12, class_name => q[insert_size], tag_index => 5})->size(), 1, 'one result is found by search');
    is($c->search({position => 8, id_run => 12, class_name => q[qX_yield], tag_index => 5})->size(), 0, 'no results are found by search');

    $c->add(npg_qc::autoqc::results::qX_yield->new(position => 8, id_run => 12, tag_index => 5, path => q[mypath]));
    is($c->search({position => 8, id_run => 12, class_name => q[qX_yield], tag_index => 5})->size(), 1, 'one result is found by search');
    is($c->search({position => 8, id_run => 12, tag_index => undef, })->size(), 2, 'two results are found by search');
    is($c->search({position => 8, id_run => 12, tag_index => 5, })->size(), 2, 'two results are found by search');
}


{
    my $c = npg_qc::autoqc::results::collection->new();
    $c->add(npg_qc::autoqc::results::qX_yield->new(position => 8, id_run => 12, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::insert_size->new(position => 2, id_run => 12, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::qX_yield->new(position => 6, id_run => 12, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::insert_size->new(position => 1, id_run => 12, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::insert_size->new(position => 8, id_run => 12, path => q[mypath]));

    is($c->slice(q[position], 8)->size(), 2, 'two results are returned by slice by position');
    is($c->slice(q[check_name], q[insert size])->size(), 3, 'three results are returned by slice by check name');
    is($c->slice(q[class_name], q[qX_yield])->size(), 2, 'three results are returned by slice by check name');
}


{
    my @results = ();
    push @results, npg_qc::autoqc::results::qX_yield->new(position => 8, id_run => 12, path => q[mypath]);
    push @results, npg_qc::autoqc::results::qX_yield->new(position => 8, id_run => 13, path => q[mypath]);
    push @results, npg_qc::autoqc::results::qX_yield->new(position => 8, id_run => 14, path => q[mypath]);

    my $c = npg_qc::autoqc::results::collection->new();
    $c->add(npg_qc::autoqc::results::insert_size->new(position => 1, id_run => 12, path => q[mypath]));
    lives_ok {$c->add(\@results)} 'no error when adding a list ref to a collection';
    is ($c->size(), 4, 'total of 4 objects after adding an array ref');


    my $lanes = [1, 8];
    $c->filter_by_positions($lanes);
    is ($c->size(), 4, 'total of 4 objects after filtering existing position');

    $lanes = [2, 7];
    $c->filter_by_positions($lanes);
    is ($c->size(), 0, 'empty collection because non-existing position required by a filter');
}


{
    my $load_dir = q[t/data/autoqc/load];
    my $c = npg_qc::autoqc::results::collection->new();
    $c->add_from_dir($load_dir);
    is($c->size(), 3, 'three results added by de-serialization');
    warnings_like {$c->add_from_dir($load_dir)} [ qr/Cannot\ identify\ class\ for\ t\/data\/autoqc\/load\/some\.json/], 'warning when an object for a json file does nor exist';
}

{
    my $c = npg_qc::autoqc::results::collection->new();
    $c->add(npg_qc::autoqc::results::qX_yield->new(   position => 8, id_run => 12, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::split_stats->new(position => 8, id_run => 12, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::adapter->new(    position => 8, id_run => 12, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::adapter->new(    position => 7, id_run => 12, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::qX_yield->new(   position => 8, id_run => 13, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::insert_size->new(position => 8, id_run => 13, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::insert_size->new(position => 6, id_run => 14, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::insert_size->new(position => 2, id_run => 14, path => q[mypath]));

    my $expected = {};
    $expected->{q[12:8]} = {position => 8, id_run => 12,};
    $expected->{q[12:7]} = {position => 7, id_run => 12,};
    $expected->{q[13:8]} = {position => 8, id_run => 13,};
    $expected->{q[14:2]} = {position => 2, id_run => 14,};
    $expected->{q[14:6]} = {position => 6, id_run => 14,};

    cmp_deeply($c->run_lane_map(), $expected, 'run-lane map generated');

    my $rlc = $c->run_lane_collections;
    my $c1 = $rlc->{q[12:8]};
    is ($c1->size, 3, 'run-lane collection size');
    $c->clear;
    is (join(q[:], $c1->get(0)->id_run, $c1->get(0)->position), q[12:8], 'correct first object');
    $c1 = $rlc->{q[14:2]};
    is ($c1->size, 1, 'run-lane collection size');
    is (join(q[:], $c1->get(0)->id_run, $c1->get(0)->position), q[14:2], 'correct first object');
}

{
    my $c = npg_qc::autoqc::results::collection->new();
    $c->add(npg_qc::autoqc::results::qX_yield->new(   position => 8, id_run => 12, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::split_stats->new(position => 8, id_run => 12, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::adapter->new(    position => 8, id_run => 12, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::adapter->new(    position => 8, id_run => 12, tag_index => 0, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::qX_yield->new(   position => 8, id_run => 12, tag_index => 1, path => q[mypath]));
    $c->add(npg_qc::autoqc::results::insert_size->new(position => 8, id_run => 12, tag_index => 1, path => q[mypath]));

    my $rlc = $c->run_lane_collections;
    my $c1 = $rlc->{q[12:8]};
    $c->clear;
    is ($c->size, 0, 'original collection cleared');

    is ($c1->size, 3, 'run-lane collection size');
    is (join(q[:], $c1->get(0)->id_run, $c1->get(0)->position), q[12:8], 'correct first object');

    $c1 = $rlc->{q[12:8:0]};
    is ($c1->size, 1, 'run-lane collection size');
    is (join(q[:], $c1->get(0)->id_run, $c1->get(0)->position, $c1->get(0)->tag_index,), q[12:8:0], 'correct first object');

    $c1 = $rlc->{q[12:8:1]};
    is ($c1->size, 2, 'run-lane collection size');
    is (join(q[:], $c1->get(0)->id_run, $c1->get(0)->position, $c1->get(0)->tag_index,), q[12:8:1], 'correct first object');
    is (join(q[:], $c1->get(1)->id_run, $c1->get(1)->position, $c1->get(1)->tag_index,), q[12:8:1], 'correct first object');
}

{
    local $ENV{TEST_DIR} = q[t/data];
    my $c = npg_qc::autoqc::results::collection->new();
    my $id_run = 1234;
    $c->add_from_staging($id_run);
    is($c->size, 16, 'lane results loaded from staging area');

    $c->add_from_staging($id_run, [4]);
    is($c->size, 18, 'lane results added from staging area for lane 4');

    $c->add_from_staging($id_run, [5,6]);
    is($c->size, 22, 'lane results added from staging area for lanes 5 and 6');
}


{
    my $c = npg_qc::autoqc::results::collection->new();
    is (join(q[ ], (sort @{$c->_result_classes})), q[adapter alignment_filter_metrics bam_flagstats contamination gc_bias gc_fraction genotype insert_size pulldown_metrics qX_yield ref_match sequence_error spatial_filter split_stats tag_decode_stats tag_metrics tags_reporters upstream_tags verify_bam_id], 'list of result classes');
}

{
    my $c = npg_qc::autoqc::results::collection->new();
    $c->add(npg_qc::autoqc::results::split_stats->new(id_run=>1, position=>1, path=>q[t]));
    $c->add(npg_qc::autoqc::results::split_stats->new(id_run=>1, position=>1, path=>q[t]));
    $c->add(npg_qc::autoqc::results::split_stats->new(id_run=>1, position=>2, path=>q[t]));
    $c->add(npg_qc::autoqc::results::split_stats->new(id_run=>1, position=>2, path=>q[t]));
    $c->add(npg_qc::autoqc::results::split_stats->new(id_run=>1, position=>3, path=>q[t], ref_name=>q[phix]));
    $c->add(npg_qc::autoqc::results::qX_yield->new(id_run=>1, position=>1, tag_index=>1, path=>q[t]));
    $c->add(npg_qc::autoqc::results::qX_yield->new(id_run=>1, position=>1, tag_index=>1, path=>q[t]));
    $c->add(npg_qc::autoqc::results::qX_yield->new(id_run=>1, position=>1, tag_index=>3, path=>q[t]));
    $c->add(npg_qc::autoqc::results::qX_yield->new(id_run=>1, position=>1, tag_index=>4, path=>q[t]));
    $c->add(npg_qc::autoqc::results::adapter->new(id_run=>1, position=>1, tag_index=>1, path=>q[t]));
    $c->add(npg_qc::autoqc::results::bam_flagstats->new(id_run=>1, position=>3, path=>q[t]));
    $c->add(npg_qc::autoqc::results::bam_flagstats->new(id_run=>1, position=>3, path=>q[t], human_split => q[human]));

    my $check_names = $c->check_names;

    my @expected = ('adapter', 'qX yield', 'split stats', 'split stats phix', 'bam flagstats', 'bam flagstats human');
    is(join(q[:], @{$check_names->{list}}), join(q[:], @expected), 'check names list');
    my $expected_map = {'adapter' => 'adapter', 'qX yield' => 'qX_yield', 'split stats phix' => 'split_stats', 'split stats' => 'split_stats', 'bam flagstats'=>'bam_flagstats', 'bam flagstats human'=>'bam_flagstats',};
    cmp_deeply ($check_names->{map}, $expected_map, 'check names map');
}

{
    my $check_names = npg_qc::autoqc::results::collection->new()->check_names;
    ok (exists $check_names->{list}, 'empty collection check name list exists');
    ok (exists $check_names->{map}, 'empty collection check name map exists');
    is  (scalar @{$check_names->{list}}, 0, 'empty collection check name list is empty');
    is  (scalar keys %{$check_names->{map}}, 0, 'empty collection check name map is empty');
}


{
    local $ENV{TEST_DIR} = q[t/data];
    my $c = npg_qc::autoqc::results::collection->new();
    my $id_run = 1234;

    $c->add_from_staging($id_run, [], $PLEXES);
    is ($c->size, 0, 'asking to load plexes when there are none');

    lives_ok { $c->add_from_staging($id_run, [1,2], $ALL) }
                   'asking to load pooled lane when there are none lives';

    my $size = $c->size();
    $c->add_from_staging($id_run, [], $PLEXES);
    is ($c->size(), $size, 'collection size does not change after loading only plexes when there are none');
}

{
  my $other =  join(q[/], $temp, q[nfs]);
  mkdir $other;
  $other =  join(q[/], $other, q[sf44]);
  mkdir $other;

  `cp -R t/data/nfs/sf44/IL2  $other`;
  my $archive = join q[/], $other,
                q[IL2/analysis/123456_IL2_1234/Data/Intensities/Bustard_RTA/PB_cal/archive];
  mkdir join q[/], $archive, 'lane1';
  mkdir join q[/], $archive, 'lane2';
  mkdir join q[/], $archive, 'lane2', 'qc';
  mkdir join q[/], $archive, 'lane3';
  my $lqc = join q[/], $archive, 'lane3', 'qc';
  mkdir $lqc;
  my $file = join q[/], $archive, 'qc', '1234_3.insert_size.json';
  `cp $file $lqc`;
  mkdir join q[/], $archive, 'lane4';
  $lqc = join q[/], $archive, 'lane4', 'qc';
  mkdir $lqc;
  $file = join q[/], $archive, 'qc', '1234_4.insert_size.json';
  `cp $file $lqc`;

  local $ENV{TEST_DIR} = $temp;
  my $id_run = 1234;

  my $c = npg_qc::autoqc::results::collection->new();
  $c->add_from_staging($id_run);
  is ($c->size, 16, 'loading main qc results only');

  $c = npg_qc::autoqc::results::collection->new();
  $c->add_from_staging($id_run, undef, $PLEXES);
  is ($c->size, 2, 'loading autoqc for plexes only');

  $c = npg_qc::autoqc::results::collection->new();
  $c->add_from_staging($id_run, [1,4,6], $PLEXES);
  is ($c->size, 1, 'loading autoqc for plexes only for 3 lanes');

  $c = npg_qc::autoqc::results::collection->new();
  $c->add_from_staging($id_run, [1,6], $PLEXES);
  is ($c->size, 0, 'loading autoqc for plexes only for 2 lanes, one empty, one no-existing');

  $c = npg_qc::autoqc::results::collection->new();
  $c->add_from_staging($id_run, [1,6], $ALL);
  is ($c->size, 4, 'loading all autoqc including plexes  for 2 lanes, for plexes one empty, one no-existing');

  $c = npg_qc::autoqc::results::collection->new();
  $c->add_from_staging($id_run, [4], $ALL);
  is ($c->size, 3, 'loading all autoqc including plexes  for 1 lane');

  $c = npg_qc::autoqc::results::collection->new();
  $c->add_from_staging($id_run, [], $ALL);
  is ($c->size, 18, 'loading all autoqc');

  $c = npg_qc::autoqc::results::collection->new();
  $c->add_from_staging(234, [1,4,6], $PLEXES);
  is ($c->size, 0, 'loading autoqc for plexes only for 3 lanes');

  $c = npg_qc::autoqc::results::collection->new();
  $c->add_from_staging(234);
  is ($c->size, 0, 'nothing loaded');

  $c->add_from_dir($lqc);
  is ($c->size, 1, 'loading from directory');
  $c->add_from_dir($lqc, [], 234);
  is ($c->size, 1, 'loading from directory');
  $c->add_from_dir($lqc, [], 234);
  is ($c->size, 1, 'loading from directory');
}

1;

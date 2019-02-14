use strict;
use warnings;
use Test::More tests => 65;
use Test::Exception;
use List::MoreUtils qw/none/; 
use File::Temp qw/tempdir/;

local $ENV{'HOME'} = q[t/data];
use npg_qc::autoqc::results::qX_yield;
use npg_qc::autoqc::results::insert_size;
use npg_qc::autoqc::results::split_stats;
use npg_qc::autoqc::results::adapter;
use npg_qc::autoqc::results::tag_metrics;
use npg_qc::autoqc::results::tag_decode_stats;
use npg_qc::autoqc::results::bam_flagstats;

use npg_qc::autoqc::qc_store::options qw/$ALL $LANES $PLEXES/;

use_ok('npg_qc::autoqc::results::collection');

my $temp = tempdir( CLEANUP => 1);

{
    my $c = npg_qc::autoqc::results::collection->new();
    isa_ok($c, 'npg_qc::autoqc::results::collection');

    my $expected = {
                    qX_yield         => 1,
                    insert_size      => 1,
                    sequence_error   => 1,
                    contamination    => 1,
                    adapter          => 1,
                    split_stats      => 1,
                    spatial_filter   => 1,
                    gc_fraction      => 1,
                    gc_bias          => 1,
                    genotype         => 1,
                    genotype_call    => 1,
                    tag_decode_stats => 1,
                    bam_flagstats    => 1,
                    ref_match        => 1,
                    tag_metrics      => 1,
                    pulldown_metrics => 1,
                    alignment_filter_metrics => 1,
                    upstream_tags    => 1,
                    tags_reporters   => 1,
                    verify_bam_id    => 1,
                    rna_seqc         => 1,
                    bcfstats         => 1,
                    samtools_stats   => 1,
                   };
    my $actual;
    my @checks = @{$c->checks_list};
    foreach my $check (@checks) {
      $actual->{$check} = 1;
    }
    is_deeply ($actual, $expected, 'checks listed');
    is(pop @checks, 'bam_flagstats', 'bam_flagstats at the end of the list');
}

{
    my $c = npg_qc::autoqc::results::collection->new();
    ok($c->is_empty, 'collection is empty');
    is($c->size, 0, 'empty collection has size 0');
    foreach my $pos ((1,5,7,2)) {
      is ($c->add(npg_qc::autoqc::results::qX_yield->new(position => $pos, id_run => 12)),
        1, 'result added'); 
    }
    is($c->size(), 4, 'collection size');
    ok(!$c->is_empty(), 'collection is  not empty');
    lives_and { is $c->add(), 0 } 'add with no argument - no error';
    is($c->size(), 4, 'collection size has not changed');
    lives_and { is $c->add(undef), 0 } 'add with undef argument - no error';
    is($c->size(), 4, 'collection size has not changed');
    $c->clear();
    ok($c->is_empty, 'collection is empty after clearing it');
}

{
    my $c = npg_qc::autoqc::results::collection->new();
    lives_ok {$c->sort_collection()} 'sort OK for an empty collection';
    $c->add(npg_qc::autoqc::results::qX_yield->new(position => 8, id_run => 12));
    lives_ok {$c->sort_collection()} 'sort OK for a collection with one result';

    $c = npg_qc::autoqc::results::collection->new();
    $c->add(npg_qc::autoqc::results::qX_yield->new(position => 8, id_run => 12));
    $c->add(npg_qc::autoqc::results::insert_size->new(position => 2, id_run => 12));
    $c->add(npg_qc::autoqc::results::qX_yield->new(position => 6, id_run => 12));
    $c->add(npg_qc::autoqc::results::insert_size->new(position => 1, id_run => 12));
    $c->add(npg_qc::autoqc::results::insert_size->new(position => 8, id_run => 12));

    $c->sort_collection();
    my $names = q[];
    foreach my $r (@{$c->results}) {
        $names .= q[ ] . $r->check_name;
    }
    is($names, q[ insert size insert size insert size qX yield qX yield], 'names in sort by name');
}

{
    my $c = npg_qc::autoqc::results::collection->new();
    $c->add(npg_qc::autoqc::results::qX_yield->new(position => 8, id_run => 12));
    $c->add(npg_qc::autoqc::results::insert_size->new(position => 2, id_run => 12));
    $c->add(npg_qc::autoqc::results::qX_yield->new(position => 6, id_run => 12));
    $c->add(npg_qc::autoqc::results::insert_size->new(position => 1, id_run => 12));
    $c->add(npg_qc::autoqc::results::insert_size->new(position => 8, id_run => 12));

    is($c->search({position => 8, id_run => 12,})->size(), 2, 'two results are found by search');
    is($c->search({position => 8, id_run => 12, tag_index => undef, })->size(), 2, 'two results are found by search');
    is($c->search({position => 8, id_run => 12, check_name => q[qX yield],})->size(), 1, 'one result is found by search');
    is($c->search({position => 8, id_run => 12, class_name => q[qX_yield],})->size(), 1, 'one result is found by search');
    is($c->search({position => 8, id_run => 12, class_name => q[qX_yield], tag_index => undef})->size(), 1, 'one result is found by search');
    is($c->search({position => 8, id_run => 12, class_name => q[qX_yield], tag_index => 5})->size(), 0, 'no results are found by search');

    $c->add(npg_qc::autoqc::results::insert_size->new(position => 8, id_run => 12, tag_index => 5));
    is($c->search({position => 8, id_run => 12, class_name => q[insert_size], tag_index => 5})->size(), 1, 'one result is found by search');
    is($c->search({position => 8, id_run => 12, class_name => q[qX_yield], tag_index => 5})->size(), 0, 'no results are found by search');

    $c->add(npg_qc::autoqc::results::qX_yield->new(position => 8, id_run => 12, tag_index => 5));
    is($c->search({position => 8, id_run => 12, class_name => q[qX_yield], tag_index => 5})->size(), 1, 'one result is found by search');
    is($c->search({position => 8, id_run => 12, tag_index => undef, })->size(), 2, 'two results are found by search');
    is($c->search({position => 8, id_run => 12, tag_index => 5, })->size(), 2, 'two results are found by search');
}

{
    my $c = npg_qc::autoqc::results::collection->new();
    $c->add(npg_qc::autoqc::results::qX_yield->new(position => 8, id_run => 12));
    $c->add(npg_qc::autoqc::results::insert_size->new(position => 2, id_run => 12));
    $c->add(npg_qc::autoqc::results::qX_yield->new(position => 6, id_run => 12));
    $c->add(npg_qc::autoqc::results::insert_size->new(position => 1, id_run => 12));
    $c->add(npg_qc::autoqc::results::insert_size->new(position => 8, id_run => 12));

    is($c->slice(q[position], 8)->size(), 2, 'two results are returned by slice by position');
    is($c->slice(q[check_name], q[insert size])->size(), 3, 'three results are returned by slice by check name');
    is($c->slice(q[class_name], q[qX_yield])->size(), 2, 'three results are returned by slice by check name');
}

{
    my @results = ();
    push @results, npg_qc::autoqc::results::qX_yield->new(position => 8, id_run => 12);
    push @results, npg_qc::autoqc::results::qX_yield->new(position => 8, id_run => 13);
    push @results, npg_qc::autoqc::results::qX_yield->new(position => 8, id_run => 14);

    my $c = npg_qc::autoqc::results::collection->new();
    $c->add(npg_qc::autoqc::results::insert_size->new(position => 1, id_run => 12));
    lives_ok { $c->add(\@results) } 'no error when adding an array ref to a collection';
    is ($c->size(), 4, 'total of 4 objects after adding an array ref');
}

{ ##### remove
  my $c = npg_qc::autoqc::results::collection->new();
  $c->add(npg_qc::autoqc::results::qX_yield->new(position => 8, id_run => 12));
  $c->add(npg_qc::autoqc::results::insert_size->new(position => 2, id_run => 12));
  $c->add(npg_qc::autoqc::results::qX_yield->new(position => 6, id_run => 12));
  $c->add(npg_qc::autoqc::results::insert_size->new(position => 1, id_run => 12));
  $c->add(npg_qc::autoqc::results::insert_size->new(position => 8, id_run => 12));
  
  my $new_c = $c->remove(q[check_name], ['qX yield'] );
  
  is($new_c->size, 3, 'size correct');
  
  $new_c = $c->remove(q[check_name], ['qX yield', 'insert size'] );
  
  is($new_c->size, 0, 'size correct');
  
  $new_c = $c->remove(q[check_name], ['adapter'] );
  
  is($new_c->size, 5, 'size correct');
}

{
    my $c = npg_qc::autoqc::results::collection->new();
    $c->add(npg_qc::autoqc::results::qX_yield->new(   position => 8, id_run => 12));
    $c->add(npg_qc::autoqc::results::split_stats->new(position => 8, id_run => 12));
    $c->add(npg_qc::autoqc::results::adapter->new(    position => 8, id_run => 12));
    $c->add(npg_qc::autoqc::results::adapter->new(    position => 7, id_run => 12));
    $c->add(npg_qc::autoqc::results::qX_yield->new(   position => 8, id_run => 13));
    $c->add(npg_qc::autoqc::results::insert_size->new(position => 8, id_run => 13));
    $c->add(npg_qc::autoqc::results::insert_size->new(position => 6, id_run => 14));
    $c->add(npg_qc::autoqc::results::insert_size->new(position => 2, id_run => 14));

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
    $c->add(npg_qc::autoqc::results::qX_yield->new(   position => 8, id_run => 12));
    $c->add(npg_qc::autoqc::results::split_stats->new(position => 8, id_run => 12));
    $c->add(npg_qc::autoqc::results::adapter->new(    position => 8, id_run => 12));
    $c->add(npg_qc::autoqc::results::adapter->new(    position => 8, id_run => 12, tag_index => 0));
    $c->add(npg_qc::autoqc::results::qX_yield->new(   position => 8, id_run => 12, tag_index => 1));
    $c->add(npg_qc::autoqc::results::insert_size->new(position => 8, id_run => 12, tag_index => 1));

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
    my $c = npg_qc::autoqc::results::collection->new();
    $c->add(npg_qc::autoqc::results::split_stats->new(id_run=>1, position=>1));
    $c->add(npg_qc::autoqc::results::split_stats->new(id_run=>1, position=>1));
    $c->add(npg_qc::autoqc::results::split_stats->new(id_run=>1, position=>2));
    $c->add(npg_qc::autoqc::results::split_stats->new(id_run=>1, position=>2));
    $c->add(npg_qc::autoqc::results::split_stats->new(id_run=>1, position=>3, ref_name=>q[phix]));
    $c->add(npg_qc::autoqc::results::qX_yield->new(id_run=>1, position=>1, tag_index=>1));
    $c->add(npg_qc::autoqc::results::qX_yield->new(id_run=>1, position=>1, tag_index=>1));
    $c->add(npg_qc::autoqc::results::qX_yield->new(id_run=>1, position=>1, tag_index=>3));
    $c->add(npg_qc::autoqc::results::qX_yield->new(id_run=>1, position=>1, tag_index=>4));
    $c->add(npg_qc::autoqc::results::adapter->new(id_run=>1, position=>1, tag_index=>1));
    $c->add(npg_qc::autoqc::results::bam_flagstats->new(id_run=>1, position=>3));
    $c->add(npg_qc::autoqc::results::bam_flagstats->new(id_run=>1, position=>3, subset => q[human]));

    my $check_names = $c->check_names;

    my @expected = ('adapter', 'qX yield', 'split stats', 'split stats phix', 'bam flagstats', 'bam flagstats human');
    is(join(q[:], @{$check_names->{list}}), join(q[:], @expected), 'check names list');
    my $expected_map = {'adapter' => 'adapter', 'qX yield' => 'qX_yield', 'split stats phix' => 'split_stats', 'split stats' => 'split_stats', 'bam flagstats'=>'bam_flagstats', 'bam flagstats human'=>'bam_flagstats',};
    is_deeply ($check_names->{map}, $expected_map, 'check names map');
}

{
    my $check_names = npg_qc::autoqc::results::collection->new()->check_names;
    ok (exists $check_names->{list}, 'empty collection check name list exists');
    ok (exists $check_names->{map}, 'empty collection check name map exists');
    is  (scalar @{$check_names->{list}}, 0, 'empty collection check name list is empty');
    is  (scalar keys %{$check_names->{map}}, 0, 'empty collection check name map is empty');
}

{
    my $c = npg_qc::autoqc::results::collection->join_collections();
    isa_ok ($c, 'npg_qc::autoqc::results::collection');
    ok($c->is_empty, 'undefined -> empty collection');
    $c = npg_qc::autoqc::results::collection->join_collections(());
    ok($c->is_empty, 'empty list -> empty collection');
    $c = npg_qc::autoqc::results::collection->join_collections((npg_qc::autoqc::results::collection->new()));
    ok($c->is_empty, 'empty collection -> empty collection');
    $c = npg_qc::autoqc::results::collection->join_collections(
      (npg_qc::autoqc::results::collection->new(), npg_qc::autoqc::results::collection->new()));
    ok($c->is_empty, 'two empty collections -> empty collection');

    my $oc = npg_qc::autoqc::results::collection->new();
    $oc->add(npg_qc::autoqc::results::split_stats->new(id_run=>1, position=>1));
    $oc->add(npg_qc::autoqc::results::split_stats->new(id_run=>1, position=>2));
    $c = npg_qc::autoqc::results::collection->join_collections(($oc));
    is($c->size, 2, 'one collection -> the same collection');
    $c = npg_qc::autoqc::results::collection->join_collections(($oc, npg_qc::autoqc::results::collection->new()));
    is($c->size, 2, 'collection plus an empty collection -> the same collection');
    $c = npg_qc::autoqc::results::collection->join_collections(($oc, $oc));
    is($c->size, 4, 'two collections -> a sum of two collections');  
}

1;

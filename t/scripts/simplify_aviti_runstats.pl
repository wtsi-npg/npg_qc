#!/usr/bin/env perl
# perl simplify_aviti_runstats.pl RunStats.json
# Emits a file in the same location with the name slim_RunStats.json

use strict;
use warnings;
use JSON;
use File::Slurp qw/read_file write_file/;

my $file_name = shift;
my $run_stats = read_file($file_name);

my $content = decode_json($run_stats);

for my $lane (@{$content->{Lanes}}) {
    for my $read (@{$lane->{Reads}}) {
        $read->{Cycles} = [];
        $read->{PerReadGCCountHistogram} = [];
        $read->{RemovedAdapterLengthHistogram} = [];
        $read->{QualityScoreHistogram} = [];
        $read->{PerReadMeanQualityScoreHistogram} = [];
    }
}

# Optionally remove all but 6 samples to further truncate the data
# splice(@{$content->{SampleStats}}, 6) if @{$content->{SampleStats}} > 6;

for my $sample (@{$content->{SampleStats}}) {
    for my $occurrence (@{$sample->{Occurrences}}) {
        for my $read (@{$occurrence->{Reads}}) {
            $read->{Cycles} = [];
            $read->{PerReadGCCountHistogram} = [];
            $read->{RemovedAdapterLengthHistogram} = [];
        }
    }
    for my $read (@{$sample->{Reads}}) {
        $read->{Cycles} = [];
        $read->{PerReadGCCountHistogram} = [];
        $read->{RemovedAdapterLengthHistogram} = [];
    }
}

for my $read (@{$content->{Reads}}) {
    $read->{Cycles} = [];
    $read->{RemovedAdapterLengthHistogram} = [];
    $read->{QualityScoreHistogram} = [];
    $read->{PerReadMeanQualityScoreHistogram} = [];
}


my $slim_file_name = "slim_$file_name";
write_file($slim_file_name, encode_json($content));

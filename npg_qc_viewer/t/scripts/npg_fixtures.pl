#!/usr/bin/env perl

use strict;
use warnings;
use npg_tracking::Schema;
use t::util;

my $util = t::util->new();
my $path = q[t/data/fixtures/npg];
my $real = npg_tracking::Schema->connect();
my $id_run = [4025, 6400, 3965, 3323, 3500];

my @tables =  qw(
             Run
             RunAnnotation
             RunLane
             TagRun
             RunStatus
		);

foreach my $tname (@tables) {
    my $rs = $real->resultset($tname)->search(
            {id_run => $id_run}
    );
    if ($rs->count > 0) {
        $util->rs_list2fixture($tname, [$rs], $path);
    }
}

my @tnames = qw/RunStatusDict User User2usergroup Usergroup Tag/;
foreach my $tname (@tnames) {
  my $rs = $real->resultset($tname);
  $util->rs_list2fixture($tname, [$rs], $path);
}

my @rows = $real->resultset('RunAnnotation')->search({id_run => $id_run,},)->all;
my @annot_ids = ();
foreach my $row (@rows) {
  push @annot_ids, $row->id_annotation;
}

@rows = $real->resultset('RunLane')->search({id_run => $id_run,},)->all;
my @ids = ();
foreach my $row (@rows) {
  push @ids, $row->id_run_lane;
}

my $rs = $real->resultset('RunLaneAnnotation')->search({id_run_lane => \@ids,},);
if ($rs->count > 0) {
    $util->rs_list2fixture('RunLaneAnnotation', [$rs], $path);
}
@rows = $rs->all;
foreach my $row (@rows) {
  push @annot_ids, $row->id_annotation;
}

$rs = $real->resultset('Annotation')->search({id_annotation => \@annot_ids,},);
if ($rs->count > 0) {
    $util->rs_list2fixture('Annotation', [$rs], $path);
}


1;

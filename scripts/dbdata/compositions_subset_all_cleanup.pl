#!/usr/bin/env perl

use strict;
use warnings;
use npg_qc::Schema;
use Carp;

############################
#
# Some rna_seqc results (2576 in total) were saved with subset value 'all',
# while the subset value should have been undefined. This script deletes
# one-component compositions with subset value 'all'; Should be run after
# rna_seq records have been relinked
#
############################

my $rs = $schema->resultset('SeqComponent')->search_autoqc({subset => 'all'});
while (my $component = $rs->next()) {
  if ($component->subset() ne 'all') {
    croak 'Wrong search result';
  }
  my $linked_rs = $component->seq_component_compositions();
  if ($linked_rs->count() > 1) {
    croak 'Mutiple compositions linked';
  }
  my $linked = $linked_rs->next();
  my $composition = $linked->seq_composition();
  $linked->delete();
  $composition->delete();
  $component->delete();
}

1;

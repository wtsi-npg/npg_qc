#!/usr/bin/env perl

use strict;
use warnings;
use npg_qc::Schema;
use npg_tracking::glossary::composition::component::illumina;
use Carp;

############################
#
# Some rna_seqc results (2576 in total) were saved with subset value 'all',
# while the subset value should have been undefined. This script relinks
# the database records.
#
############################

my $schema = npg_qc::Schema->connect();
my $rsss = $schema->resultset('SequenceSummary');
my $rs   = $schema->resultset('RnaSeqc')->search_autoqc({subset => 'all'});

while (my $row = $rs->next) {
  my $old_fk = $row->id_seq_composition;
  my $composition = $row->seq_composition->create_composition();
  if ($composition->num_components != 1) {
    croak 'Multiple components';
  }
  my $component = $composition->get_component(0);
  if ($component->subset() ne 'all') {
    croak 'Wrong search result';
  }
  my $other_rs = $rsss->search_autoqc({id_run    => $component->id_run,
                                       position  => $component->position,
                                       tag_index => $component->tag_index});
  my $other_row = $other_rs->next();
  if (!$other_row) {
    croak 'Failed to find composition I need';
  }
  my $other_composition = $other_row->seq_composition->create_composition();
  if ($other_composition->num_components != 1) {
    croak 'Multiple components in other';
  }

  my $test = npg_tracking::glossary::composition::component::illumina->new(
    id_run    => $component->id_run,
    position  => $component->position,
    tag_index => $component->tag_index
  );
  if ($other_composition->get_component(0)->digest ne $test->digest) {
    croak 'Wrong component found for reassignment';
  }

  my $new_fk = $other_row->id_seq_composition;
  if ($old_fk == $new_fk) {
    croak 'Not a new key';
  }
  print "OLD $old_fk NEW $new_fk\n";
  $row->update({id_seq_composition => $new_fk});
}

1;

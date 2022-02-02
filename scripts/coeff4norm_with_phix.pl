#!/usr/bin/env perl

use strict;
use warnings;
use Class::Load qw(try_load_class);
use List::Util qw(pairkeys sum);

###############################################################################
#
# See https://assets.publishing.service.gov.uk/government/uploads/system/uploads/attachment_data/file/926410/Understanding_Cycle_Threshold__Ct__in_SARS-CoV-2_RT-PCR_.pdf
# for information about Ct (cycle threshold) values.
#
# The Ct values are in the lighthouse_sample table in the following fields:
# ch1_target, ch1_result, ch1_cq
# ch2_target, ch2_result, ch2_cq
# ch3_target, ch3_result, ch3_cq
# ch4_target, ch4_result, ch4_cq
#
# The target is a gene, e.g. ORF1lab, N gene, S gene, MS2 (extraction control). 
# The result is the result of the test, e.g. Positive, Negative, Void.
# The value is the Ct value.
# 
# We will take the average Ct value for ORF1lab, N gene, S gene and consider
# samples with the average Ct value below the threshold value of 25.
# Aditionally, we will consider full plates only (384 samples) and only include
# plates where at least 90% of the samples have passed the threshold.
#
# Joining between the sample and lighthouse_sample tables
#
# *** Method 1 - uuids ***
# The easiest way is one using the fields 'lh_sample_uuid' and 'uuid_sample_lims'.
# This should work for the majority of samples. If you can't find a match for
# a sample using this then you can try the second method.
#
# *** Method 2 - root sample id and stock plate ***
# This only works for samples created using the 'Sentinel' process, which was
# the majority of samples cherrypicked before the Beckman robots came online.
# The reason it doesn't work for the Beckmans is that we don't store the source
# plates in the stock_resource table for these plates.
#
# 'root_sample_id' in lighthouse_sample matches 'description' in sample
# 'result' in lighthouse_sample matches 'phenotype' in sample
# 'plate_barcode' in lighthouse_sample matches 'labware_human_barcode' in stock_resource
# 'coordinate' in lighthouse_sample matches 'labware_coordinate' in stock_resource
# For this method, you have to use all the above fields in your join because
# we do receive samples with the same root sample id on different plates.
#
###############################################################################

my $wh_class = 'WTSI::DNAP::Warehouse::Schema';
my ($loaded, $error) = try_load_class($wh_class);
if (not $loaded) {
  $error ||= q[];
  warn "$error\n";
  warn "$wh_class is not available, exiting\n";
  exit 1;
}

my $schema = $wh_class->connect();

my $join = {'iseq_flowcell' => 'study'};
my @selection = qw/me.id_run me.position/;
my @run_lanes = $schema->resultset('IseqProductMetric')->search(
  { 'study.name' => 'Heron Project',
    'iseq_flowcell.primer_panel' => 'nCoV-2019/V4.1alt'},
  {join     => $join,
   prefetch => $join,
   distinct => 1,
   columns  => [@selection],
   order_by => [@selection]}
)->all();

my $lane_data = {};

for my $run_lane (@run_lanes) {
  
  my $id_run = $run_lane->id_run;
  my $p = $run_lane->position;

  my $rs = $schema->resultset('IseqProductMetric')->search({
                    id_run => $id_run, position => $p});
  # pool size - do not count PhiX and tag zero
  ($rs->count() - 2 > 380) or next; # skip partial plates
  my $row = $rs->search({tag_index => 888})->next;
  $row or next; # no PhiX
  $row->qc_seq or next; # filter out seq failures
  # number of reads in tag 888 after deplexing
  my $num_phix_reads = $row->tag_decode_count;
  $num_phix_reads or next; # no PhiX reads
  $lane_data->{$id_run}->{$p}->{num_reads_phix} = $num_phix_reads;
}

#use Data::Dumper;
#print Dumper $lane_data;

my @run_ids = keys %{$lane_data};
warn @run_ids . " RUNS FOUND\n";

$join = {
  'iseq_product_metric' => {'iseq_flowcell' => {'sample' =>
    [qw/lighthouse_sample lighthouse_sample_sentinel/]}
}};
my $hrs = $schema->resultset('IseqHeronProductMetric')->search(
  {'iseq_product_metric.id_run' => \@run_ids},
  {join     => $join,
   prefetch => $join,
   order_by => [qw/iseq_product_metric.id_run
                   iseq_product_metric.position
                   iseq_product_metric.tag_index/]
  }
);

my $old_position = 0;
my $old_run = 0;
warn "STARTING LOOP\n";
while (my $hrow = $hrs->next()) {
  
  my $prow = $hrow->iseq_product_metric;
  my $id_run    = $prow->id_run;
  my $position  = $prow->position;
  $lane_data->{$id_run}->{$position} or next;

  if ($id_run != $old_run or $position != $old_position) { # new plate
    if ($old_run and $old_position) { # start from the second plate
      prune_weak_lane($old_run, $old_position);
    }
    $old_run = $id_run;
    $old_position = $position;
    $lane_data->{$id_run}->{$position}->{num_with_values} = 0;
    $lane_data->{$id_run}->{$position}->{over_threshold} = 0;
    $lane_data->{$id_run}->{$position}->{controls} = [];
  }

  if ($prow->iseq_flowcell->sample->control) {
    if ($prow->iseq_flowcell->sample->control_type eq 'negative') {
      my $num_reads = $hrow->num_aligned_reads;
      if ($num_reads < 10000) { # This somewhat arbitrary, but sensible
                                # threshold cuts out 'fake' negative controls,
                                # ie real samples or positive controls.
        # save for future
        push @{$lane_data->{$id_run}->{$position}->{controls}},
          {tag_index => $prow->tag_index, num_reads => $num_reads};
      }
    }
    next; # Finished with the control sample
  }

  # Real sample
  my $lh_sample = $prow->iseq_flowcell->sample->lighthouse_sample;
  if (!$lh_sample) {
    $lh_sample = $prow->iseq_flowcell->sample->lighthouse_sample_sentinel;
  }
  $lh_sample or next;

  my @ct_values = grep { defined }
                  ($lh_sample->ch1_cq, $lh_sample->ch2_cq, $lh_sample->ch3_cq);
  @ct_values or next; #no Ct values of any kind

  my $value = (sum @ct_values) / (scalar @ct_values);
  if ($value > 0.00001) {
    $lane_data->{$id_run}->{$position}->{num_with_values}++;
    if ($value > 25) {
      $lane_data->{$id_run}->{$position}->{over_threshold}++;
    }
  }
}

# deal with the last plate
prune_weak_lane($old_run, $old_position);

# output data
print join qq[\t], qw(id_run position tag_index num_phix_reads
                      num_reads num_reads_norm*1000);
print qq[\n];

my @runs = sort { $a <=> $b } keys %{$lane_data};
for my $id_run (@runs) {
  my @positions = sort { $a <=> $b } keys %{$lane_data->{$id_run}};
  for my $position (@positions) {
    my @controls = sort { $a->{tag_index} <=> $b->{tag_index} }
                   @{$lane_data->{$id_run}->{$position}->{controls}};
    my $num_reads_ph = $lane_data->{$id_run}->{$position}->{num_reads_phix};
    for my $control (@controls) {
      print join qq[\t],
        $id_run, $position, $control->{tag_index},
        $num_reads_ph,
        $control->{num_reads},
        ($control->{num_reads} / $num_reads_ph)*1000;
      print qq[\n];
    }
  }
}

###### end of main ########

sub prune_weak_lane {
  my ($run, $position) = @_;
  return;
  my $total = $lane_data->{$run}->{$position}->{num_with_values};
  if (not $total) { # not sure
    delete $lane_data->{$run}->{$position};
    return 1;
  }

  my $num_over = $lane_data->{$run}->{$position}->{over_threshold};
  if ($num_over and ($num_over/$total) >= 0.1) {
    delete $lane_data->{$run}->{$position};
    return 1;
  }

  return 0;
}

exit 0;

#!/usr/bin/env perl

use strict;
use warnings;
use Class::Load qw(try_load_class);
use List::Util qw(sum);
use Readonly;

Readonly::Scalar my $STUDY_NAME => 'Heron Project';                             
Readonly::Scalar my $PRIMER_PANEL_NAME => 'nCoV-2019/V4.1alt';                  
Readonly::Scalar my $PHIX_TAG_INDEX => 888;
Readonly::Scalar my $CT_THRESHOLD => 25;

# This somewhat arbitrary, but sensible threshold cuts out                      
# 'fake' negative controls, ie real samples or positive controls,               
# which have not been fixed in LIMS.                                            
Readonly::Scalar my $NEGATIVE_CONTROL_MAX_NUM_READS => 100_000; 

Readonly::Scalar my $SCALING_FACTOR => 10_000;

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
# We will take the average Ct value for ORF1lab, N gene and S gene.
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
# Using the centinel process sometimes results in spurious rows in the DBIx   
# result set even when access to sentinel data is not required. This was noted    
# when examining the number of samples with Ct values, which in 22 plates was     
# higher than the size of the pool. Removing a join that uses this process        
# produces a slightly different dataset. For 77 plates both the number of         
# sample with known Ct values and samples with high Ct values goes down. Since    
# this affects less than 4% of plates in a way that is not going to skew    
# calculations, this simple method was adopted without further investigations.
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
  { 'study.name' => $STUDY_NAME,
    'iseq_flowcell.primer_panel' => $PRIMER_PANEL_NAME},
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
  my $row = $rs->search({tag_index => $PHIX_TAG_INDEX})->next;
  $row or next; # no PhiX
  $row->qc_seq or next; # Filter out seq failures
                        # or plates which have not been through qc yet
  # Number of reads in tag 888 after deplexing
  my $num_phix_reads = $row->tag_decode_count;
  $num_phix_reads or next; # no PhiX reads

  $lane_data->{$id_run}->{$p}->{num_reads_phix} = $num_phix_reads;
  # Pool size - do not count PhiX and tag zero 
  $lane_data->{$id_run}->{$p}->{pool_size} = $rs->count() - 2;
  $lane_data->{$id_run}->{$p}->{phix_lib} = $row->iseq_flowcell->id_library_lims;
  $lane_data->{$id_run}->{$p}->{lane_forward_q20yield} =
    $row->iseq_run_lane_metric->q20_yield_kb_forward_read;
}

warn "PLATES IDENTIFIED\n";

my @run_ids = keys %{$lane_data};

$join = {
  'iseq_product_metric' => {'iseq_flowcell' => {'sample' => 'lighthouse_sample'}
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

while (my $hrow = $hrs->next()) {
  my $prow = $hrow->iseq_product_metric;
  my $id_run    = $prow->id_run;
  my $position  = $prow->position;
  $lane_data->{$id_run}->{$position} or next;

  if ($id_run != $old_run or $position != $old_position) { # New plate
    $old_run = $id_run;
    $old_position = $position;
    $lane_data->{$id_run}->{$position}->{num_with_values} = 0;
    $lane_data->{$id_run}->{$position}->{over_threshold} = 0;
    $lane_data->{$id_run}->{$position}->{controls} = [];
  }

  if ($prow->iseq_flowcell->sample->control) {
    if ($prow->iseq_flowcell->sample->control_type eq 'negative') {
      my $num_reads = $hrow->num_aligned_reads;
      if (defined $num_reads && ($num_reads < $NEGATIVE_CONTROL_MAX_NUM_READS)) {
        push @{$lane_data->{$id_run}->{$position}->{controls}},
          {tag_index => $prow->tag_index, num_reads => $num_reads};
      }
    }
    next; # Finished with the control sample
  }

  # Real sample
  my $lh_sample = $prow->iseq_flowcell->sample->lighthouse_sample;
  my @ct_values = ();
  if ($lh_sample) {
    @ct_values = grep { defined } map { $lh_sample->$_ }
                 qw(ch1_cq ch2_cq ch3_cq);
  }
  @ct_values or next; # No Ct values of any kind

  my $value = (sum @ct_values) / (scalar @ct_values);
  $lane_data->{$id_run}->{$position}->{num_with_values}++;
  if ($value > $CT_THRESHOLD) {
    $lane_data->{$id_run}->{$position}->{over_threshold}++;
  }
}

my $log10 = log(10);

# Output data
print join qq[\t],
  qw(id_run position tag_index pool_size
     num_samples_with_cts num_high_cts
     num_reads_phix phix_lib lane_forward_q20yield num_reads_control
     log10_num_reads_control log10_num_reads_norm);
print qq[\n];

my @runs = sort { $a <=> $b } keys %{$lane_data};
for my $id_run (@runs) {
  my @positions = sort { $a <=> $b } keys %{$lane_data->{$id_run}};
  for my $position (@positions) {
    
    my $plate_data = $lane_data->{$id_run}->{$position};
    $plate_data or next;
    my $num_reads_ph = $plate_data->{num_reads_phix};
    my $pool_size = $plate_data->{pool_size};
    my $num_samples_with_cts = $plate_data->{num_with_values};
    my $ct_over_threshold = $num_samples_with_cts ?
                            $plate_data->{over_threshold} : q[];

    my @controls = sort { $a->{tag_index} <=> $b->{tag_index} }
                   @{$lane_data->{$id_run}->{$position}->{controls}};
    for my $control (@controls) {
      my $num_reads_control = $control->{num_reads};
      print join qq[\t],
        $id_run, $position, $control->{tag_index}, $pool_size,
        $num_samples_with_cts,
        $ct_over_threshold,
        $num_reads_ph,
        $plate_data->{phix_lib},
        $plate_data->{lane_forward_q20yield},
        $num_reads_control,
        $num_reads_control ? log($num_reads_control)/$log10 : q[],
        $num_reads_control ?
          log(($num_reads_control / $num_reads_ph) * $SCALING_FACTOR)/$log10 : q[];
      print qq[\n];
    }
  }
}

exit 0;

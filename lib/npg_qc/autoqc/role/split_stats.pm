#########
# Author:        gq1
# Maintainer:    $Author$
# Created:       2009-09-21
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#

package npg_qc::autoqc::role::split_stats;

use strict;
use warnings;
use Moose::Role;
use Carp;
use English qw(-no_match_vars);
use Readonly;
use File::Basename;

with qw(npg_qc::autoqc::role::result);

our $VERSION    = do { my ($r) = q$Revision$ =~ /(\d+)/smx; $r; };

Readonly::Scalar our $LOG_BASE_NUMBER_POSITION  => 10;
Readonly::Scalar our $GOOGLE_BAR_CHART => q{http://chart.apis.google.com/chart?cht=bvs&amp;chxt=x,y&amp;chs=800x250};
Readonly::Scalar our $PERCENTAGE   =>100;
Readonly::Scalar our $IMAGE_MARGIN => 55;
Readonly::Scalar our $BAR_WIDTH => 29;


has 'alignment_coverage1' =>  (isa            => 'Maybe[HashRef]',
                               is             => 'rw',
                               required       => 0,
                               lazy_build     => 1,
		                        );

has 'alignment_coverage2' => (isa            => 'Maybe[HashRef]',
                              is             => 'rw',
                              required       => 0,
                              lazy_build     => 1,
		                        );

sub _build_alignment_coverage1{
   my $self = shift;

   if(ref $self eq 'npg_qc::autoqc::db::checks::split_stats'){
     return $self->coverages_in_hash()->{1};
   }

   return;
}

sub _build_alignment_coverage2{
   my $self = shift;

   if(ref $self eq 'npg_qc::autoqc::db::checks::split_stats'){
     return $self->coverages_in_hash()->{2};
   }

   return;
}

sub num_total1{
  my $self = shift;

  return $self->num_aligned1() + $self->num_not_aligned1;
}

sub num_total2{
  my $self = shift;

  return $self->num_aligned2() + $self->num_not_aligned2();
}

sub num_total_merge{
  my $self = shift;

  return $self->num_aligned_merge() + $self->num_not_aligned_merge();
}

sub save_stats_xml{
  my ($self, $xml_filename) = @_;

  open my $output_stats_fh, q[>], $xml_filename or croak $ERRNO;
  print {$output_stats_fh} $self->stats_to_xml() or croak $ERRNO;
  close $output_stats_fh or croak $ERRNO;

  return 1;
}

sub stats_to_xml{
   my $self = shift;

   my $fastq1 = $self->filename1();
   my $fastq2 = $self->filename2();
   my $ref_name = $self->reference();
   my $chromosome_coverage1 = $self->alignment_coverage1();
   my $chromosome_depth1 = $self->alignment_depth1();
   my $chromosome_coverage2 = $self->alignment_coverage2();
   my $chromosome_depth2 = $self->alignment_depth2();

   my $stats_output = qq{<?xml version="1.0" encoding="utf-8"?>\n<?xml-stylesheet type="text/xsl" href="splitting_stats.xsl"?>\n<stats>\n};

  if($fastq1){

    $stats_output .= qq{<coverages fastq="$fastq1" reference="$ref_name">\n};
    $stats_output .= $self->coverage_to_string($chromosome_coverage1, $chromosome_depth1);
    $stats_output .= qq{</coverages>\n};
  }

  if($fastq2){

    $stats_output .= qq{<coverages fastq="$fastq2" reference="$ref_name">\n};
    $stats_output .= $self->coverage_to_string($chromosome_coverage2, $chromosome_depth2);
    $stats_output .= qq{</coverages>\n};
  }

  $stats_output .= qq{<splitting_percentages reference="$ref_name">\n};

  if($fastq1){

    my $num_not_aligned1 = $self->num_not_aligned1();
    my $num_aligned1 = $self->num_aligned1();
    my $num_total1 = $self->num_total1();

    my $percentage1 = $self->percentage($num_aligned1, $num_total1);

    $stats_output .= qq{<percentage value="$percentage1" fastq="$fastq1" num_aligned="$num_aligned1" num_not_aligned="$num_not_aligned1" num_total="$num_total1"/>\n};
  }

  if($fastq2){

    my $num_not_aligned2 = $self->num_not_aligned2();
    my $num_aligned2 = $self->num_aligned2();
    my $num_total2 = $self->num_total2();

    my $percentage2 = $self->percentage($num_aligned2, $num_total2);

    $stats_output .= qq{<percentage value="$percentage2" fastq="$fastq2" num_aligned="$num_aligned2" num_not_aligned="$num_not_aligned2" num_total="$num_total2"/>\n};
  }

   if($fastq1 && $fastq2){

     my $num_aligned3 = $self->num_aligned_merge();
     my $num_not_aligned3 = $self->num_not_aligned_merge();
     my $num_total3 = $self->num_total_merge();

     my $percentage3 = $self->percentage($num_aligned3, $num_total3);
    $stats_output .= qq{<percentage value="$percentage3" fastq="$fastq1" fastq2="$fastq2" num_aligned="$num_aligned3" num_not_aligned="$num_not_aligned3" num_total="$num_total3"/>\n};

    }

    $stats_output .= qq{</splitting_percentages>\n};

    $stats_output .= qq{</stats>\n};

    return $stats_output;
}

sub coverage_to_string{
  my ($self, $chromosome_coverage, $chromosome_depth) = @_;
  my $output;

  my $coverage_google_chart = $GOOGLE_BAR_CHART;
  my $chd = q{&amp;chd=t:};
  my $chxl = q{&amp;chxl=0:|};

  foreach my $chromosome (sort keys %{$chromosome_coverage}){

   my $coverage_value = $chromosome_coverage->{$chromosome} * $PERCENTAGE;
   $output .= qq{<coverage sequence="$chromosome" value="}.($coverage_value).qq{">\n};

   #$coverage_value = sprintf '%.3f', (log $coverage_value) / (log 10);
   $chd .= qq{$coverage_value,};
   $chxl .= qq{$chromosome|};

   my $one_chromosome_depth = $chromosome_depth->{$chromosome};

   my @depthes = sort{$a <=> $b} keys %{$one_chromosome_depth};

   if(scalar @depthes){

     foreach my $depth (@depthes){

       my $value = $one_chromosome_depth->{$depth};
       $output .= qq{<depth value="$depth" num_of_position="$value" />\n};
     }

     my $log_positions_depth = $self->log_positions_depth($one_chromosome_depth);
     $output .= q{<depth_google_chart url="};
     $output .= $self->depth_google_chart($log_positions_depth);
     $output .= qq{"/>\n};
   }

   $output .= qq{</coverage>\n};
  }
  chop $chd;
  chop $chxl;
  $coverage_google_chart .= $chd.$chxl.q{&amp;chtt=Coverage+vs+Chromosome};
  $output .= qq{<coverage_google_chart url="$coverage_google_chart"/>\n};

  return $output;
}

sub depth_google_chart{
  my ($self, $one_chromosome_depth, $filename) = @_;

  my $num_bars = scalar keys %{$one_chromosome_depth};
  my $image_width = $IMAGE_MARGIN + $num_bars * $BAR_WIDTH;
  my $amp = $filename ? q[&] : q[&amp;];

  my $google_chart = q{http://chart.apis.google.com/chart?cht=bvs} .
                     $amp . q{chxt=x,y} . $amp . q{chs=} . $image_width . q{x250};

  my $chd = $amp . q{chd=t:};
  my $chxl = $amp . q{chxl=0:|};

  my @depthes = sort{$a <=> $b} keys %{$one_chromosome_depth};
  my $max = 0;

  foreach my $depth (@depthes){

     my $value = $one_chromosome_depth->{$depth};
     $value = (log $value)/ (log $LOG_BASE_NUMBER_POSITION);
     if($max <$value){
        $max = $value;
     }
     $value = sprintf '%.2f', $value;
     $chd .= "$value,";
     $depth = 2 ** $depth;
     $chxl .= "$depth|";
  }

  chop $chd;
  $max = int $max + 1;
  $google_chart .= $chd.$amp. qq{chds=0,$max};

  $chxl .= q{1:|0};
  my $chxp = $amp . q{chxp=1,0};

  foreach my $label_count (1..$max){
    $chxp .= qq{,$label_count};
    my $label = $LOG_BASE_NUMBER_POSITION ** $label_count;
    $chxl .= qq{|$label};
  }

  $google_chart .= qq{$chxl$chxp|} . $amp . q{chtt=Number+of+bases+at+and+above+depth};
  if ($filename) {
      $google_chart .= q{|} . $filename;
  }

  return $google_chart;
}

sub log_positions_depth{
  my ($self, $one_chromosome_depth) = @_;

  my $log_positions_depth;

  foreach my $depth (sort keys %{$one_chromosome_depth}){

    my $value = $one_chromosome_depth->{$depth};

    my $depth_log = (log $depth)/(log 2);

    $depth_log = int $depth_log;

    $log_positions_depth->{$depth_log} += $value;
  }

  my $sum = 0;

  foreach my $depth (reverse sort {$a <=> $b} keys %{$log_positions_depth}){

    my $value = $log_positions_depth->{$depth};
    $sum += $value;
    $log_positions_depth->{$depth} = $sum;
  }

  return $log_positions_depth;
}

sub image_url {
  my ($self, $index) = @_;

  my $method = q[filename] . $index;
  my $fastq = $self->$method;
  if ($fastq) {
    $method = q[alignment_depth] . $index;
    my $chromosome_depth = $self->$method;
    my $log_positions_depth = $self->log_positions_depth($chromosome_depth->{'All'});
    my ($filename, $dir, $extension) = fileparse($fastq);
    return $self->depth_google_chart($log_positions_depth, $filename);
  }
  return;
}

sub percentage{
  my ($self, $num_aligned, $num_total) = @_;

  my $percentage;

  if($num_total){

      $percentage = sprintf '%.2f', ($PERCENTAGE * $num_aligned/$num_total);
  }else{

      $percentage = q{};
  }

  return $percentage;
}

sub percent_split {
  my ($self) = @_;
  my $tot = $self->num_total_merge;
  return $tot ? $PERCENTAGE * $self->num_aligned_merge / $tot : undef;
}

sub check_name {
  my $self = shift;

  my $ref = $self->class_name;
  $ref =~ s/_/ /gsmx;
  if ($self->ref_name) {
    $ref = $ref.q{ }.$self->ref_name;
  }
  return $ref;
}

no Moose;

1;
__END__

=head1 NAME

npg_qc::autoqc::role::split_stats

=head1 VERSION

$Revision$

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 _build_alignment_coverage1 - lazy build method to get the coverage data from database in hash

=head2 _build_alignment_coverage2 - lazy build method to get the coverage data from database in hash

=head2 num_total1 -return the total number of reads in fastq 1

=head2 num_total2 -return the total number of reads in fastq 2

=head2 num_total_merge -return the total number of reads in both fastq files

=head2 stats_to_xml - output stats results into xml

=head2 save_stats_xml - given a file name, save the stats into a xml file

=head2 coverage_to_string - output alignment coverage statistics

=head2 depth_google_chart - given a hash of number of positions of each alignment depth, generate a google char url

=head2 log_positions_depth - given a hash of number of positions of each alignment depth, covert the value of depth to log2

=head2 percentage - given two number, calculate the percentage

=head2 image_url - google chart url for number of bases vs depth for all chromosomes

=head2 check_name - human readable check name, including the type of the split

=head2 percent_split - percent of templates split by alignment

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

strict
warnings
Carp
English
Moose::Role
npg_qc::autoqc::results::result
File::Basename

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Guoying Qi, E<lt>gq1@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Guoying Qi

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut

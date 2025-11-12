#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib ( -d "$Bin/../lib/perl5" ? "$Bin/../lib/perl5" : "$Bin/../lib" );
use Text::CSV;
use List::MoreUtils qw/uniq any/;
use List::Util qw/sum max/;
use File::Basename;
use Cwd qw/cwd/;
use JSON;
use Perl6::Slurp;
use Carp;
use Getopt::Long;
use Pod::Usage;
use autodie;
use Readonly;

use npg_qc::ultimagen::library_info;
use npg_qc::autoqc::results::tag_metrics;
use npg_qc::autoqc::results::qX_yield;

our $VERSION = '0';

#####
#
# ####### Reads Filtering and Read Groups #######
#
# Ultima apply a noisy read filter similar to the Illumina PF filter.
# All analysis pipelines apply this filter. Reads that fail this filter,
# called RSQ, won't appear in any cram or fastq files. While the reads are
# failed, the sample barcode might be sufficiently good so that the reads
# can be assigned to the sample which is why these reads are included in the
# 'num input' reads.
#
# If the only reason any reads where failed is due to the noisy read filter
# there will no _unmatched.cram file.
#
# Both run-level merged_trimmer-failure_codes.csv and merged_trimmer-stats.csv
# files contain read group 'none'. This seems to be a summary across all
# read groups excluding TT. The numbers are difficult to interpret.
#
# merged_trimmer-*.csv files are not available in run folders for at least
# some early runs. The latest run that does not have these top-level files
# is from 2024/08/24.
#
# The cram files can include primary, secondary and supplementary reads.
# An independent way of getting stats is running samtools flagstats and
# selecting the number of primary reads (example: '89932 + 0 primary').
#
# Application-specific output can be either CRAM or FASTQ files, but the
# unmatched files seem to be always CRAM.
# 
# Perl-barcode directories contain one or two *.csv files. Examples:
# 421054-s1-Z0001-CAGCTCGAATGCGAT_unmatched.csv and
# 421054-s1-Z0001-CAGCTCGAATGCGAT.csv These files contain lots of
# useful metrics. While *_unmatched.csv contain metrics for the
# matching _unmatched.cram file, the file without 'unmatched' in its
# name contains metrics for all reads that were assigned to the barcode
# and passed 'noisy read' filter. This was checked by summing up the
# number of primary reads for both target and unmatched file for a
# barcode and comparing this number with 'PF_Barcode_reads' value in
# the CSV file for this barcode.
#
# ###### Runfolder structure ######
# 
# File [RunID]_LibraryInfo.xml on top level provides a list of target samples.
#
# - TT is the control, example directory name 425347-TT-TT
# - UNKN is for data that was not assigned to any of barcodes,
#                                      example directory name 425347-UNKN
#
# ###### Rules for NPG Calculations ###### 
#
# Run-level files merged_trimmer-failure_codes.csv and merged_trimmer-stats.csv
# contain deplexing and filtering stats. The data there is listed by read group.
# Each read group corresponds to a single barcode and to a directory with data.
# The barcodes used for target samples are listed in [RunId]_LibraryInfo.xml
# file and in the user-supplied manifest.csv. [RunId]_LibraryInfo.xml reflects the
# mapping of target samples to barcodes which was used in the analysis by
# Ultima software. Occasionally the actual mapping might be adjusted after
# this analysis, manifest.csv will have the up-to-date mapping. Therefore
# manifest.csv should be used as a source of target sample listing.
#
# Tag metrics - use all read group's input reads apart from the ones that failed
# the 'noisy read' filter.
#   - assign reads in the TT group to a control sample
#   - assign reads in non-target read groups (barcodes) and UNKN to tag zero
#   - assign reads in target read groups (barcodes) to target samples
#   - save the mapping of non-target barcodes to read numbers; these numbers
#     will be useful for troubleshooting in case of a low deplexing rate.
# 
# Other metrics (if any) - calculate for target barcodes and TT only,
# disregard the reads that failed any(?) of the filters.
#

Readonly::Scalar my $HUNDRED => 100;
Readonly::Scalar my $THOUSAND => 1000;
Readonly::Scalar my $NON_TARGET_OR_CONTROL => 'NON_TARGET';

Readonly::Scalar my $POSITION => 1;

Readonly::Scalar my $NPG_TAG_INDEX_FOR_ULTIMA_CONTROL => 9999; # Highest allowed according to our spec
Readonly::Scalar my $NPG_TAG_INDEX_ZERO => 0;

sub get_options {

  my %options = ();

  my $result = GetOptions(\%options,
                          'runfolder_path=s',
                          'id_run=i',
                          'output=s',
                          'help',
                         );

  my $sections = 'NAME|DESCRIPTION|USAGE|REQUIRED ARGUMENTS|OPTIONS';

  if( $options{help} ) {
    pod2usage(-exitval => 1, -verbose => 99, -sections => $sections);
  }

  if( !$result || !exists $options{runfolder_path} || !exists $options{output} || !exists $options{id_run}) {
    warn "\nERROR: Incorrect options when invoking the script.\n\n";
    pod2usage(-exitval => 2, -verbose => 99, -sections => $sections);
  }

  return \%options;
}

sub main { ##no critic (Subroutines::ProhibitExcessComplexity)
  my $options = get_options();
  my $runfolder = $options->{runfolder_path};
  my $qc_output_dir = $options->{output};
  my $id_run = $options->{id_run};

  -d $runfolder or croak "Run folder $runfolder does not exist";


  my @library_info_paths = glob join q[/], $runfolder, '*LibraryInfo.xml';
  (@library_info_paths == 1) or croak 'Too many or too few';
  my $li = npg_qc::ultimagen::library_info->new(input_file_path => $library_info_paths[0]);
  if ($li->application && ($li->application =~ /quantum/xmsi)) {
    carp 'Skipping quantum application';
    return;
  }

  my $failure_codes_file_name = 'merged_trimmer-failure_codes.csv';
  my $stats_file_name = 'merged_trimmer-stats.csv';

  my $csv = Text::CSV->new();
  open my $fh1, q[<], "${runfolder}/${stats_file_name}";
  $csv->header ($fh1);
  my $barcodes_stats = {};
  while (my $row = $csv->getline_hr($fh1)) {
    push @{$barcodes_stats->{$row->{'read group'}}}, $row;
  }
  close $fh1;

  $csv = Text::CSV->new();
  open my $fh2, q[<], "${runfolder}/${failure_codes_file_name}";
  $csv->header ($fh2);
  my $barcodes_failure_codes = {};
  while (my $row = $csv->getline_hr($fh2)) {
    push @{$barcodes_failure_codes->{$row->{'read group'}}}, $row;
  }
  close $fh2;

  # Compute deplexing stats per barcode for all barcodes.

  my %target_samples = map { $_->index_label => $_ } @{$li->samples};

  my $stats_all_barcodes = {};
  my $total_num_reads = 0;
  my $total_input_num_reads = 0;

  foreach my $read_group (keys %{$barcodes_stats}) {
    if ($read_group eq 'none') { # The meaning of this entry is not clear yet, some sort of wafer total
      next;
    }
    my @input_reads_numbers = uniq map { $_->{'num input reads'}}
                              @{$barcodes_stats->{$read_group}};
    if (@input_reads_numbers > 1) {
      croak "Inconsistent input reads numbers for read group $read_group";
    }
    $total_input_num_reads += $input_reads_numbers[0];
    my @failure_codes = $barcodes_failure_codes->{$read_group} ?
      @{$barcodes_failure_codes->{$read_group}} : ();
    my $noisy_filtered_num_reads = 0;
    my $count_key = 'failed read count';

    if (@failure_codes) {
      $noisy_filtered_num_reads = sum map  { $_->{$count_key} }
                                  grep { $_->{'reason'} eq 'rsq file' }
                                  @failure_codes;
      $noisy_filtered_num_reads ||= 0;
    } else {
      carp "No failure codes for read group $read_group";
    }

    my $deplexed_num_reads = $input_reads_numbers[0] - $noisy_filtered_num_reads;
    $stats_all_barcodes->{$read_group}->{'deplexed_num_reads'} = $deplexed_num_reads;
    $stats_all_barcodes->{$read_group}->{'input_num_reads'} = $input_reads_numbers[0];

    $total_num_reads += $deplexed_num_reads;
  }

  # Present deplexing stats for target barcodes, TT control and 'tag zero'
  my $deplexing_stats = {};
  my $nontarget_num_reads = 0;
  my $nontarget_input_num_reads = 0;

  foreach my $read_group (keys %{$stats_all_barcodes}) {

    my $num_reads = $stats_all_barcodes->{$read_group}->{'deplexed_num_reads'};
    my $input_num_reads = $stats_all_barcodes->{$read_group}->{'input_num_reads'};

    if (exists $target_samples{$read_group}) {

      my $target_barcode = $target_samples{$read_group}->index_sequence();
      $deplexing_stats->{$target_barcode}->{'num_reads'} = $num_reads;
      $deplexing_stats->{$target_barcode}->{'input_num_reads'} = $input_num_reads;
      $deplexing_stats->{$target_barcode}->{'sample'} = $target_samples{$read_group}->id();
      #$deplexing_stats->{$target_barcode}->{'library'} = $target_samples{$read_group}->{'library_name'};
      $deplexing_stats->{$target_barcode}->{'read_group'} = $read_group;
      my ($tag_index) = $read_group =~ /[0]*(\d+)/xms;
      $tag_index or croak "Undefined or zero tag index from read group $read_group";
      $deplexing_stats->{$target_barcode}->{'npg_tag_index'} = int $tag_index;
    } elsif ($read_group eq 'TT') {
      my $name = 'TT_ULTIMA_CONTROL';
      $deplexing_stats->{$read_group}->{'read_group'} = $read_group;
      $deplexing_stats->{$read_group}->{'library'} = $name;
      $deplexing_stats->{$read_group}->{'sample'} = $name;
      $deplexing_stats->{$read_group}->{'num_reads'} = $num_reads;
      $deplexing_stats->{$read_group}->{'input_num_reads'} = $input_num_reads;
      $deplexing_stats->{$read_group}->{'npg_tag_index'} = $NPG_TAG_INDEX_FOR_ULTIMA_CONTROL;
    } else {
      $nontarget_num_reads += $num_reads;
      $nontarget_input_num_reads += $input_num_reads;
    }
  }

  my @tag_indexes = map { $_->{'npg_tag_index'} }
                    grep { exists $_->{'npg_tag_index'} } values %{$deplexing_stats};
  if (@tag_indexes != uniq @tag_indexes) {
    croak 'Non-unique tag indexes in ' . join q[,], @tag_indexes;
  }

  $deplexing_stats->{$NON_TARGET_OR_CONTROL}->{'npg_tag_index'} = $NPG_TAG_INDEX_ZERO;
  $deplexing_stats->{$NON_TARGET_OR_CONTROL}->{'num_reads'} = $nontarget_num_reads;
  $deplexing_stats->{$NON_TARGET_OR_CONTROL}->{'input_num_reads'} = $nontarget_input_num_reads;

  $deplexing_stats->{'WAFER_NUM_READS'}->{'num_reads'} = $total_num_reads;
  $deplexing_stats->{'WAFER_NUM_READS'}->{'input_num_reads'} = $total_input_num_reads;

  # The deplexing percent is calculated against a total number of reads on a wafer,
  # including both the TT control and the UNKN (unassigned) read groups. It is
  # possible to exclude the TT read group the the calculation of total if this is what
  # the QC team wants.
  foreach my $key (keys %{$deplexing_stats}) {
    next if ($key eq 'WAFER_NUM_READS');
    $deplexing_stats->{$key}->{'percent_reads'} =
      sprintf '%.2f', ($deplexing_stats->{$key}->{'num_reads'}/$total_num_reads)*$HUNDRED;
  }

  if (!$id_run) {
    carp 'NPG tracking run id is not provided, autoqc results will not be generated.';
    exit 0;
  }

  # If needed create top-level output directory.
  if (!-e $qc_output_dir) {
    mkdir $qc_output_dir;
  }

  my $tm_result = npg_qc::autoqc::results::tag_metrics->new(
    id_run => $id_run,
    position => $POSITION
  );

  # Generate tag metrics in autoqc format.

  my $wafer_num_pf_reads = $deplexing_stats->{'WAFER_NUM_READS'}->{'num_reads'};
  my $wafer_num_reads = $deplexing_stats->{'WAFER_NUM_READS'}->{'input_num_reads'};

  for my $barcode (sort keys %{$deplexing_stats}) {

    my $tag_index = $deplexing_stats->{$barcode}->{'npg_tag_index'};
    (defined $tag_index) or next; # Exclude wafer summary.

    my $num_pf_reads = $deplexing_stats->{$barcode}->{'num_reads'};
    my $num_reads = $deplexing_stats->{$barcode}->{'input_num_reads'};

    $tm_result->reads_pf_count->{$tag_index} = $num_pf_reads;
    $tm_result->reads_count->{$tag_index} = $num_reads;
    # For now consider all matches as perfect.
    $tm_result->perfect_matches_pf_count->{$tag_index} = $num_pf_reads;
    $tm_result->perfect_matches_count->{$tag_index} = $num_reads;
    $tm_result->one_mismatch_matches_pf_count->{$tag_index} = 0;
    $tm_result->one_mismatch_matches_count->{$tag_index} = 0;

    $tm_result->matches_pf_percent->{$tag_index} =
      $wafer_num_pf_reads == 0 ? 0 : $num_pf_reads/$wafer_num_pf_reads;
    $tm_result->matches_percent->{$tag_index} =
      $wafer_num_reads == 0 ? 0 : $num_reads/$wafer_num_reads;

    $tm_result->tags->{$tag_index} = $tag_index == 0 ? 'NA' : $barcode;
  }

  $tm_result->spiked_control_index($NPG_TAG_INDEX_FOR_ULTIMA_CONTROL);
  $tm_result->store($qc_output_dir);

  ######
  # Target samples and control stats - use tag sequence to identify sample directories
  # Map run folder sample directories to samples.
  for my $barcode (keys %{$deplexing_stats}) {
    next if any {$barcode eq $_ } ($NON_TARGET_OR_CONTROL, 'WAFER_NUM_READS');
    my @found = grep { -d } glob "$runfolder/*-${barcode}";
    (@found > 0) or croak "Sample directory is not found for $barcode";
    (@found == 1) or croak "Multiple sample directories for $barcode";
    $deplexing_stats->{$barcode}->{'directory'} = $found[0];
  }

  # Read per-sample metrics files.
  for my $barcode (keys %{$deplexing_stats}) {

    my $directory = $deplexing_stats->{$barcode}->{'directory'};
    $directory or next;
    my ($directory_name, $path) = fileparse($directory);
    my $file_base_name = join q[/], $directory, $directory_name;
    my $file = $file_base_name . '.csv';
    -f $file or croak "File $file does not exist";

    open my $sfh, q[<], $file;
    my $sample_csv = Text::CSV->new();
    my @rows = $sample_csv->getline_all($sfh);
    close $sfh;

    my %sample_stats = map { $_->[0] => $_->[1] } @{$rows[0]};
    # Cross-check number of reads
    if ( $sample_stats{'PF_Barcode_reads'} != $deplexing_stats->{$barcode}->{'num_reads'} ) {
      croak "Inconsistent read numbers for $barcode";
    }
    my $pct_pf_q30_bases = $sample_stats{'PCT_PF_Q30_bases'};
    my $pct_pf_q20_bases = $sample_stats{'PCT_PF_Q20_bases'};

    $file = $file_base_name . '.json';
    -f $file or croak "File $file does not exist";
    my @files = ($file);

    # Since Q20 and Q30 values above are for the total number of reads,
    # we have to add unmatched count if present.
    $file = $file_base_name . '_unmatched.json';
    if (-f $file) {
      push @files, $file;
    } else {
      carp "File $file does not exist";
    }

    my $num_bases = 0;
    for my $json_file (@files) {
      my $data = from_json(slurp $json_file);
      $num_bases += $data->{'pf_bases'};
    }

    my $tag_index = $deplexing_stats->{$barcode}->{'npg_tag_index'};
    my $result = npg_qc::autoqc::results::qX_yield->new(
      id_run => $id_run,
      position => $POSITION,
      tag_index => $tag_index
    );
    $result->yield1(int(($pct_pf_q20_bases*$num_bases)/($HUNDRED*$THOUSAND)));
    $result->yield1_q30(int(($pct_pf_q30_bases*$num_bases)/($HUNDRED*$THOUSAND)));

    $result->store($qc_output_dir);
  }

  return;
}

main();

1;

__END__

=head1 NAME

parse_ultima_stats.pl

=head1 CONFIGURATION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 USAGE

parse_ultima_stats.pl --runfolder_path <runfolder> --output <folder> --id_run <run_id>

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 REQUIRED ARGUMENTS

=over

=item --runfolder_path <dir>

Directory with on-instrument analysis data for a run.

=item --output <dir>

Directory Where to put the transformed tag_metrics and other outputs,
will be created if does not exist.

=item --id_run

NPG tracking run ID.

=back

=head1 OPTIONS

=over

=item --help

Prints a brief help message and exits.

=back

=head1 EXIT STATUS

0

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

Works for relatively recent runs, post August 2024.

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina GourtovaiaE<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2025 Genome Research Ltd.

This file is part of NPG.

NPG is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut

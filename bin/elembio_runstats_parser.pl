#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib ( -d "$Bin/../lib/perl5" ? "$Bin/../lib/perl5" : "$Bin/../lib" );

use File::Slurp qw(write_file);
use Getopt::Long;
use JSON;

use npg_qc::autoqc::results::tag_metrics;
use npg_qc::elembio::run_stats;

our $VERSION = '0';

sub get_options {

  my $usage = q[

  Usage:
          elembio_qc_converter.pl <opts>
          perl bin/elembio_runstats_parser.pl --input /lustre/scratch120/npg/elembio_deplex/20250509_AV244103_NT1854541J/20250509_AV244103_NT1854541J --output ~/elembio_parsing_tests/ --id_run 15

  Options:
         --input <dir>      Deplexing folder where RunStats.json, RunParameters.json and RunManifest.json live
         --output <dir>     Where to put the transformed tag_metrics outputs
         --id_run <int>     Supply an id_run from npg_tracking
         -h                 help

  ];

  my %options = (verbose => 0);

  my $result = GetOptions(\%options,
                          'input:s',
                          'output:s',
                          'id_run:i',
                          'verbose',
                          'help'
                          );

  die "$usage\n" if( !$result || $options{help});

  return \%options;
}

sub main {
    my $opts = get_options();

    my $deplex_folder = $opts->{'input'};

    my $run_stats = npg_qc::elembio::run_stats::run_stats_from_file($deplex_folder.'/RunStats.json', $deplex_folder.'/RunManifest.json');

    # Where do we get an id_run from? Argument for now. $runstats->{'RunName'} is non-numeric.
    # Waiting for a script.

    while (my($lane, $lane_stats) = each %{$run_stats->lanes}) {
        my $metrics_obj = npg_qc::autoqc::results::tag_metrics->new(
            id_run => $opts->{'id_run'},
            position => $lane_stats->lane,
        );
        foreach my $sample ($lane_stats->all_samples()) {
            $metrics_obj->reads_pf_count->{$sample->tag_index} = $sample->num_polonies; # ??
            $metrics_obj->tags->{$sample->tag_index} = $sample->barcode_string();
            # polonies before trim are equal to polonies in the source data, or so it seems
            $metrics_obj->reads_count->{$sample->tag_index} = $sample->num_polonies;
        }
        # Add tag 0 (unassigned reads) as a sample
        $metrics_obj->reads_count->{'0'} = $lane_stats->unassigned_reads;
        $metrics_obj->reads_pf_count->{'0'} = $lane_stats->unassigned_reads;

        my ($sample) = $lane_stats->all_samples();
        my ($i1_length, $i2_length) = $sample->index_lengths();
        $metrics_obj->tags->{'0'} = 'N' x $i1_length;
        if ($i2_length) {
            $metrics_obj->tags->{'0'} .= q{-} . 'N' x $i2_length;
        }

        my $output_name = sprintf '%s_%s_tag_metrics.json', $opts->{'id_run'}, $lane_stats->lane;

        my $tag_metrics_json = $metrics_obj->freeze();
        write_file($opts->{'output'}.$output_name, $tag_metrics_json);
    }
    return;
}


main();
1;

__END__

=head1 NAME

elembio_runstats_parser.pl

=head1 USAGE

elembio_runstats.parser.pl --input <runfolder> --output <folder> --id_run <id>

=head1 CONFIGURATION

=head1 SYNOPSIS

=head1 DESCRIPTION

Extracts lane-centric metrics from the Element BioSciences Aviti deplexing
outputs and converts them to format amenable to NPG_QC

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 REQUIRED ARGUMENTS

=head1 OPTIONS

=head1 EXIT STATUS

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item FindBin

=item Getopt::Long

=item npg_qc::autoqc::results::tag_metrics

=item npg_qc::elembio::run_stats

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Kieron Taylor<lt>kt19@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2025 GRL, by Kieron Taylor

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


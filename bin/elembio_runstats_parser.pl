#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib ( -d "$Bin/../lib/perl5" ? "$Bin/../lib/perl5" : "$Bin/../lib" );
use Getopt::Long;
use JSON;

use npg_qc::elembio::run_stats;
use npg_qc::elembio::tag_metrics_generator qw(convert_run_stats_to_tag_metrics);
use Monitor::Elembio::RunFolder; # from npg_tracking

our $VERSION = '0';
Readonly::Scalar my $PERCENT_TO_DECIMAL => 100;

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
    my $run_folder = Monitor::Elembio::RunFolder->new(
        runfolder_path => $deplex_folder,
        npg_tracking_schema => npg_tracking::Schema->connect(),
    );
    my $lane_count = $run_folder->lane_count;

    my $run_stats = npg_qc::elembio::run_stats::run_stats_from_file(
        $deplex_folder.'/RunManifest.json',
        $deplex_folder.'/RunStats.json',
        $lane_count
    );

    # Where do we get an id_run from? Argument for now. $runstats->{'RunName'} is non-numeric.

    my @metrics = convert_run_stats_to_tag_metrics($run_stats, $opts->{'id_run'});
    for my $metrics_obj (@metrics) {
        $metrics_obj->store($opts->{'output'});
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


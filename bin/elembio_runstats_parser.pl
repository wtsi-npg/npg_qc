#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib ( -d "$Bin/../lib/perl5" ? "$Bin/../lib/perl5" : "$Bin/../lib" );
use English;
use Getopt::Long;
use Pod::Usage;

use npg_qc::elembio::run_stats;
use npg_qc::elembio::tag_metrics_generator qw(convert_run_stats_to_tag_metrics);
use Monitor::Elembio::RunFolder; # from npg_tracking
use npg_tracking::Schema;

our $VERSION = '0';

sub get_options {

  my %options = ();

  my $result = GetOptions(\%options,
                          'input=s',
                          'output=s',
                          'id_run=i',
                          'help',
                         );

  my $sections = 'NAME|DESCRIPTION|USAGE|REQUIRED ARGUMENTS|OPTIONS';

  if( $options{help} ) {
    pod2usage(-exitval => 1, -verbose => 99, -sections => $sections);
  }

  if( !$result || !exists $options{input} || !exists $options{output} || !exists $options{id_run} ) {
    warn "Incorrect options when invoking the script\n\n";
    pod2usage(-exitval => 2, -verbose => 99, -sections => $sections);
  }

  return \%options;
}

sub main {
    my $opts = get_options();

    my $deplex_folder = $opts->{'input'};

    # Unfortunately, a database handle is required.
    # No data is retrieved from the tracking database.
    # Lane count is calculated from data in RunParameters.json .
    # TODO - drop the dependency on npg_tracking::Schema when
    # a stand-alone parser for RunParameters.json is available.
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

    # @metrics a list of npg_qc::autoqc::results::tag_metrics objects,
    # one object per lane.
    my @metrics = convert_run_stats_to_tag_metrics($run_stats, $opts->{'id_run'});
    for my $metrics_obj (@metrics) {
        $metrics_obj->set_info('Check', $PROGRAM_NAME);
        $metrics_obj->set_info('Check_version', $VERSION);
        # Save JSON representation of the object to the output directory.
        $metrics_obj->store($opts->{'output'});
    }

    return;
}

main();

1;

__END__

=head1 NAME

elembio_runstats_parser.pl

=head1 CONFIGURATION

=head1 SYNOPSIS

=head1 DESCRIPTION

Extracts lane-centric metrics from the Element BioSciences Aviti deplexing
outputs and converts them to C<npg_qc::autoqc::results::tag_metrics> type
objects. The objects are serialised to JSON. The JSON representation is
saved to the directory given as C<--output> script argument.

=head1 USAGE

elembio_runstats.parser.pl --input <runfolder> --output <folder> --id_run <id>

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 REQUIRED ARGUMENTS

=over

=item --input <dir>

Deplexing folder where RunStats.json, RunParameters.json and RunManifest.json live.

=item --output <dir>

Directory Where to put the transformed tag_metrics outputs.

=item --id_run <int>

NPG tracking run ID for this run.

=back

=head1 OPTIONS

=over

=item --help

Prints a brief help message and exits.

=back

=head1 EXIT STATUS

0

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item English

=item FindBin

=item Getopt::Long

=item Pod::Usage

=item npg_qc::autoqc::results::tag_metrics

=item npg_qc::elembio::run_stats

=item Monitor::Elembio::RunFolder

=item npg_tracking::Schema

=back

=head1 INCOMPATIBILITIES

Only applicable to Sequencing-type runs from the Aviti24. Cell profiling is
not compatible.

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Kieron TaylorE<lt>kt19@sanger.ac.ukE<gt>

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


#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib ( -d "$Bin/../lib/perl5" ? "$Bin/../lib/perl5" : "$Bin/../lib" );

use npg_qc::ultimagen::run_stats;

our $VERSION = '0';

npg_qc::ultimagen::run_stats->new_with_options()->parse();

1;

__END__

=head1 NAME

parse_ultima_stats.pl

=head1 CONFIGURATION

=head1 SYNOPSIS

=head1 DESCRIPTION

This script parses Ultima Genomics stats files that are availale in the run folder.

The script produces C<npg_qc::autoqc::results::tag_metrics> and
C<npg_qc::autoqc::results::qX_yield> results and serializes them as JSON to the
output directory.

See documentation for C<npg_qc::ultimagen::run_stats> for more details.

=head1 USAGE

  parse_ultima_stats.pl --runfolder_path <runfolder> --qc_output_dit <folder> --id_run <run_id>

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 REQUIRED ARGUMENTS

=over

=item --runfolder_path

Directory with on-instrument analysis data for a run, required

=item --qc_output_dir

Directory Where to put the transformed tag_metrics and other outputs,
will be created if does not exist.

=item --id_run

NPG tracking run ID, required.

=back

=head1 OPTIONS

=over

=item --help

Prints a brief help message and exits.

=item --manifest_path

A full path to the manifest CSV file. If this argument is set, information about
target samples will be read from the manifest rather than from [RunId]_LibraryInfo.xml
file in the run folder.

=back

=head1 EXIT STATUS

0

=head1 DEPENDENCIES

=over

=item npg_qc::ultimagen::run_stats

=back

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

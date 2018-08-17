#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib ( -d "$Bin/../lib/perl5" ? "$Bin/../lib/perl5" : "$Bin/../lib" );
use npg_qc::autoqc::db_loader;

our $VERSION = '0';

npg_qc::autoqc::db_loader->new_with_options()->load;

0;

__END__

=head1 NAME

    npg_qc_autoqc_data.pl

=head1 USAGE

    npg_qc_autoqc_data.pl --path path1 [--path path2]
    npg_qc_autoqc_data.pl --json_file file1 [--json_file file2]
    npg_qc_autoqc_data.pl --archive_path apath

=head1 DESCRIPTION

   Loads autoqc data to the database.

=head1 REQUIRED ARGUMENTS

=head1 OPTIONS

=head1 DIAGNOSTICS

=head1 EXIT STATUS

=head1 CONFIGURATION

    Set the environmental variable dev to 'dev' to use the development
    database.

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item FindBin

=item lib

=item npg_qc::autoqc::db_loader

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia, E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014 GRL, by Marina Gourtovaia

This program is free software: you can redistribute it and/or modify
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

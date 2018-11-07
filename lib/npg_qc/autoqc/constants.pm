package npg_qc::autoqc::constants;

use strict;
use warnings;
use base 'Exporter';
use Readonly;

our $VERSION = '0';

our @EXPORT_OK = qw/ $SAMTOOLS_NO_FILTER
                     $SAMTOOLS_SUPPL_FILTER
                     $SAMTOOLS_SEC_QCFAIL_SUPPL_FILTER /;

Readonly::Scalar our $SAMTOOLS_NO_FILTER               => 'F0x000';
Readonly::Scalar our $SAMTOOLS_SEC_QCFAIL_SUPPL_FILTER => 'F0xB00';
Readonly::Scalar our $SAMTOOLS_SUPPL_FILTER            => 'F0x800';

1;

__END__

=head1 NAME

npg_qc::autoqc::constants

=head1 SYNOPSIS

=head1 DESCRIPTION

Constants used by autoqc check and result objects.

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item Readonly

=item Exporter

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018 GRL

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

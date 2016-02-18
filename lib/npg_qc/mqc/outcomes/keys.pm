package npg_qc::mqc::outcomes::keys;

use strict;
use warnings;
use base 'Exporter';
use Readonly;

our $VERSION = '0';

our @EXPORT_OK = qw/$LIB_OUTCOMES $SEQ_OUTCOMES $QC_OUTCOME/;

Readonly::Scalar our $LIB_OUTCOMES => q[lib];
Readonly::Scalar our $SEQ_OUTCOMES => q[seq];
Readonly::Scalar our $QC_OUTCOME   => q[mqc_outcome];

1;
__END__


=head1 NAME

npg_qc::mqc::outcomes::keys

=head1 SYNOPSIS

  use npg_qc::mqc::outcomes::keys qw/$LIB_OUTCOMES/;
  use npg_qc::mqc::outcomes::keys qw/$LIB_OUTCOMES $SEQ_OUTCOMES $QC_OUTCOME/;

=head1 DESCRIPTION

A set of strings used as keys in input and output data structures
in npg_qc::mqc::outcomes.

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

Author: Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2016 GRL, by Marina Gourtovaia

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

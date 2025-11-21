package npg_qc::ultimagen::sample;

use Moose;
use namespace::autoclean;

our $VERSION = '0';

##no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc::ultimagen::sample

=head1 SYNOPSIS

=head1 DESCRIPTION

Representation of a sample for sequencing on the Ultima Genetics instrument.

=head1 SUBROUTINES/METHODS

=head2 id

Sample identifier.

=cut

has 'id' => (
  isa      => 'Str',
  is       => 'ro',
  required => 1,
);

=head2 index_label

Manufacturer's label for the barcode.

=cut

has 'index_label' => (
  isa      => 'Str',
  is       => 'ro',
  required => 1,
);

=head2 index_sequence

The barcode sequence of the index.
=cut

has 'index_sequence' => (
  isa      => 'Str',
  is       => 'ro',
  required => 1,
);

1;

__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia

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
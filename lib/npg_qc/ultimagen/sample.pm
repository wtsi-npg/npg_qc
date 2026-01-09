package npg_qc::ultimagen::sample;

use Moose;
use namespace::autoclean;
use Carp;
use Readonly;

use npg_tracking::util::types;

with qw/npg_tracking::glossary::tag/;

our $VERSION = '0';

##no critic (Documentation::RequirePodAtEnd)

Readonly::Scalar our $ULTIMA_CONTROL_INDEX_SEQUENCE => q[TT];
# Highest allowed according to our spec
Readonly::Scalar our $NPG_TAG_INDEX_FOR_ULTIMA_CONTROL =>
  $npg_tracking::util::types::TAG_INDEX_MAX;

=head1 NAME

npg_qc::ultimagen::sample

=head1 SYNOPSIS

=head1 DESCRIPTION

Representation of a sample for sequencing on the Ultima Genomics instrument.

=head1 SUBROUTINES/METHODS

=head2 id

Sample identifier.

=cut

has 'id' => (
  isa      => 'Str',
  is       => 'ro',
  required => 1,
);

=head2 library_name

In our practice this is sample name or supplier sample name.

=cut

has 'library_name' => (
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

=head2 tag_index

NPG tag index, derived from C<index_label> attribute.

=cut

has '+tag_index' => (
  lazy_build => 1,,
);
sub _build_tag_index {
  my $self = shift;
  return $self->tag_index_from_read_group($self->index_label);
}

=head2 tag_index_from_read_group

Class-level method.

Given an Ultima Genomics read group or index label
(see C<index_label> attribute) returns NPG tag index.

=cut

sub tag_index_from_read_group {
  my ($package, $read_group) = @_;

  if ($read_group eq $ULTIMA_CONTROL_INDEX_SEQUENCE) {
    return $NPG_TAG_INDEX_FOR_ULTIMA_CONTROL;
  }
  my ($tag_index) = $read_group =~ /[0]*(\d+)/xms;
  $tag_index or croak "Undefined or zero tag index from read group $read_group";
  return $tag_index;
}

1;

__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item Carp

=item Readonly

=item npg_tracking::util::types

=item npg_tracking::glossary::tag

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

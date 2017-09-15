package npg_qc::Schema::Composition;

use Moose::Role;

requires 'seq_composition';

our $VERSION = '0';

has 'composition' => ( is         => 'ro',
                       isa        => 'npg_tracking::glossary::composition',
                       init_arg   => undef,
                       lazy_build => 1,
                     );
sub _build_composition {
  my $self = shift;
  return $self->seq_composition()->create_composition();
}

1;

__END__

=head1 NAME

npg_qc::Schema::Composition

=head1 SYNOPSIS

=head1 DESCRIPTION

Moose role providing a composition attribute for a row object.

=head1 SUBROUTINES/METHODS

=head2 composition

 Read-only lazy-build attribute, cannot be set in the constructor.
 Object of type npg_tracking::glossary::composition which is
 created by inspecting a linked seq_composition record.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2017 GRL

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

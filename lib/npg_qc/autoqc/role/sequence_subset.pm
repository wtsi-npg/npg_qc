package npg_qc::autoqc::role::sequence_subset;

use Moose::Role;

our $VERSION = '0';

has 'subset' => ( isa         => 'Maybe[Str]',
                  is          => 'ro',
                  required    => 0,
                  predicate   => 'has_subset',
                  writer      => 'set_subset',
);

1;
__END__

=head1 NAME

npg_qc::autoqc::role::sequence_subset

=head1 SYNOPSIS

  package my_package;
  use Moose;
  with 'npg_qc::autoqc::role:::sequence_subset';

=head1 DESCRIPTION

Moose role representing sequence subset interface.
Provides a string 'subset' attribute, which is optional
and allowed to be set to null.

=head1 SUBROUTINES/METHODS

=head2 subset

Sequence subset for cases when an entity being sequenced has to be
divided (usually by alignment) into subset. Leave undefined if the subset
is the target sequence. Typical examples: phix, human, xahuman, yhuman.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 GRL

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

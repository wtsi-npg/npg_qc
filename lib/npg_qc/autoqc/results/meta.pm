package npg_qc::autoqc::results::meta;

use Moose;
use namespace::autoclean;
extends qw(npg_qc::autoqc::results::result);

our $VERSION = '0';

## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc::autoqc::results::meta

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 library_type

=cut

has 'library_type' => (
  isa        => 'Str',
  is         => 'rw',
);

=head2 criteria

A read-write hash reference attribute representing evaluation criteria
in a form that would not require any additional information to repeate
the evaluation as it was done at the time the check was run.

All boolean operators are listed explicitly. The top-level expression
is either a conjunction or disjunction performed on a list of
expressions, each of wich can be, in turn, either a math expression or
a conjunction or disjunction.

Examples:

  Assuming a = 2 and b = 5,
  {'and' => ["a-1 < 0", "b+3 > 10"]} translates to
  (a-1 > 0) && (b+3 > 10) and evaluates to false, while
  {'or' => ["a-1 > 0", "b+3 > 10"]} translates to
  (a-1 > 0) || (b+3 > 10) and evaluates to true.

  Assuming additionally c = 3 and d = 1,
  {'and' => ["a-1 > 0", "b+3 > 5", {'or' => ["c-d > 0",  "c-d < -1"]}]}
  translates to
  (a-1 > 0) && (b+3 > 5) && ((c-d > 0) || (c-d < -1)) and evaluates to true.

=cut

has 'criteria' => (
  isa        => 'HashRef',
  is         => 'rw',
  lazy_build => 1,
);

__PACKAGE__->meta->make_immutable;

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

Copyright (C) 2019 GRL

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

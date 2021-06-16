package npg_qc::autoqc::results::cscreen;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use Carp;

extends qw(npg_qc::autoqc::results::base);

our $VERSION = '0';

has 'doc' =>  (
  isa      => 'HashRef',
  is       => 'rw',
  required => 0,
);

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

 npg_qc::autoqc::results::cscreen

=head1 SYNOPSIS

 my $cs = npg_qc::autoqc::results::cscreen->new(rpt_list => '40:1:1');

=head1 DESCRIPTION

An autoqc result class that wraps the output of a contamination screen,
which is performed with mash.

=head1 SUBROUTINES/METHODS

=head2 doc

A hash reference attribute, defailts to an empty hash. This data structure
is going to be serialized to JSON when saved either to a file or to a
datababase.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item namespace::autoclean

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2021 Genome Research Ltd.

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

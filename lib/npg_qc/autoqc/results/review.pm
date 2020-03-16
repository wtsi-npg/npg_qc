package npg_qc::autoqc::results::review;

use Moose;
use namespace::autoclean;

extends 'npg_qc::autoqc::results::result';
with 'npg_qc::autoqc::role::result';

our $VERSION = '0';

## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc::autoqc::results::review

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 library_type

=cut

has 'library_type' => (
  isa  => 'Str',
  is   => 'rw',
);

=head2 criteria

A read-write hash reference attribute representing evaluation criteria
in a form that would not require any additional information to repeate
the evaluation as it was done at the time the check was run. An empty
hash is default.

=cut

has 'criteria' => (
  isa     => 'HashRef',
  is      => 'rw',
  default => sub { return {} },
);

=head2 criteria_md5

md5 of the canonical JSON serialization of criteria.

=cut

has 'criteria_md5' => (
  isa => 'Maybe[Str]',
  is  => 'rw',
);

=head2 evaluation_results

A hash of individual string expressions (keys) mapped to boolean outcomes of
their evaluation. An empty hash is default.

=cut

has 'evaluation_results' => (
  isa     => 'HashRef',
  is      => 'rw',
  default => sub { return {} },
);

=head2 qc_outcome

A hash reference with information necessary for creating a record in the
mqc_library_outcome_ent table of the QC database. An empty hash is default.

=cut

has 'qc_outcome' => (
  isa        => 'HashRef',
  is         => 'rw',
  default    => sub { return {} },
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

Copyright (C) 2019,2020 Genome Research Ltd.

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

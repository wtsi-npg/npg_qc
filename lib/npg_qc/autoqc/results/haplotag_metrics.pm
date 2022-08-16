package npg_qc::autoqc::results::haplotag_metrics;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;

extends qw(npg_qc::autoqc::results::result);

our $VERSION = '0';

has '+position' => (isa => 'Maybe[NpgTrackingLaneNumber]');

has [qw/ clear_file
         unclear_file
         missing_file
      / ] => (
    is         => 'rw',
    isa        => 'Str',
);

has [qw/ clear_count
         unclear_count
         missing_count
         pass
      / ] => (
    is         => 'rw',
    isa        => 'Int',
);

__PACKAGE__->meta->make_immutable;

1;

__END__


=head1 NAME

npg_qc::autoqc::results::haplotag_metrics

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

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

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2022 GRL

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


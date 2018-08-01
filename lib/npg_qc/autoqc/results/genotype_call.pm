
package npg_qc::autoqc::results::genotype_call;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;

extends qw(npg_qc::autoqc::results::result);

with qw(npg_qc::autoqc::role::genotype_call);

our $VERSION = '0';


has [qw/genotypes_attempted
        genotypes_called
        genotypes_passed
        sex_markers_attempted
        sex_markers_called
        sex_markers_passed
      / ] => (
    is         => 'rw',
    isa        => 'Int',
);

has [qw/gbs_plex_name
        gbs_plex_path
        sex
      / ] => (
    is         => 'rw',
    isa        => 'Str',
);

has 'output_dir' => (is       => 'rw',
                     isa      => 'Str',
                     );


__PACKAGE__->meta->make_immutable;

1;

__END__


=head1 NAME

    npg_qc::autoqc::results::genotype_call

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

=item npg_qc::autoqc::results::result

=item npg_qc::autoqc::role::genotype_call

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2017 GRL

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

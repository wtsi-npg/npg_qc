package npg_qc::autoqc::results::bcfstats;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;

extends qw(npg_qc::autoqc::results::result);

with qw(npg_qc::autoqc::role::bcfstats);

our $VERSION = '0';

has [qw/genotypes_attempted
        genotypes_called
        genotypes_passed
        genotypes_compared
        genotypes_concordant
        genotypes_nrd_dividend
        genotypes_nrd_divisor
      / ] => (
    is         => 'rw',
    isa        => 'Int',
);

has [qw/geno_refset_name
        geno_refset_path
        expected_sample_name
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

    npg_qc::autoqc::results::bcfstats

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

=item npg_qc::autoqc::role::bcfstats

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018 GRL

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

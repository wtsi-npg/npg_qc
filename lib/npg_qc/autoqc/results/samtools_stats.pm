package npg_qc::autoqc::results::samtools_stats;

use Moose;
use namespace::autoclean;
use npg_tracking::util::types;
use Compress::Zlib;
use Perl6::Slurp;
use Readonly;

extends qw(npg_qc::autoqc::results::base);

our $VERSION = '0';

has 'stats_file'     => ( 
    isa        => 'NpgTrackingReadableFile',
    is         => 'ro',
    required   => 1,
);

has 'filter'         => (
    is         => 'ro',
    isa        => 'Str',
    required   => 1,
);

has 'stats'         => (
    is         => 'ro',
    isa        => 'Str',
    required   => 0,
    lazy_build => 1,
);
sub _build_stats {
  my $self = shift;
  return compress(slurp $self->stats_file);
}

sub execute {
  my $self = shift;
  $self->stats();
  return;
}

__PACKAGE__->meta->make_immutable;

1;
__END__


=head1 NAME

npg_qc::autoqc::results::qX_yield

=head1 SYNOPSIS


=head1 DESCRIPTION

A class for wrapping results of qX (q20) check. Inherits from npg_qc::autoqc::results::result.

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item npg_tracking::util::types

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Author: Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

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

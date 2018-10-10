package npg_qc::autoqc::checks::spatial_filter;

use Moose;
use namespace::autoclean;
use Carp;

use File::Find;

extends qw(npg_qc::autoqc::checks::check);

## no critic (Documentation::RequirePodAtEnd)
our $VERSION = '0';

=head1 NAME

npg_qc::autoqc::checks::spatial_filter

=head1 SYNOPSIS

Inherits from npg_qc::autoqc::checks::check.
See description of attributes in the documentation for that module.
  my $check = npg_qc::autoqc::checks::spatial_filter->new(rpt_list => q{1234:1:5;1234:2:5}, --filename_root=1234_1, --qc_out=out/qc, -qc_in_roots=in/qc_dir);

=head1 DESCRIPTION

A check which aggregates results from spatial_filter application stats files

=head1 SUBROUTINES/METHODS

=cut

=head2 qc_in_roots

Array reference with names of input directories to be searched for stats files

=cut

has 'qc_in_roots'    => (isa        => 'ArrayRef',
                         is         => 'ro',
                         required   => 1,
                        );

override 'execute' => sub {
  my ($self) = @_;

  my @infiles=();

  find(sub { if( /spatial_filter.stats$/ ) { push @infiles, $File::Find::name }}, @{$self->qc_in_roots});

  $self->result->parse_output(\@infiles); #read stderr from spatial_filter -a for each sample

  return 1;
};

__PACKAGE__->meta->make_immutable();

1;

__END__


=head1 NAME

npg_qc::autoqc::checks::spatial_filter

=head1 SYNOPSIS

    use npg_qc::autoqc::checks::spatial_filter;

=head1 DESCRIPTION

    Parse stats files produced by spatial_filter application and aggregate number of reads filtered


=head1 SUBROUTINES/METHODS

=head2 new

    Moose-based.

=head1 DIAGNOSTICS

    None.

=head1 CONFIGURATION AND ENVIRONMENT

=head1 INCOMPATIBILITIES

    None known.

=head1 BUGS AND LIMITATIONS

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=back

=head1 AUTHOR

    David K. Jackson

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2016 GRL

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

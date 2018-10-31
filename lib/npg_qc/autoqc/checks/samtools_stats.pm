package npg_qc::autoqc::checks::samtools_stats;

use Moose;
use namespace::autoclean;
use Carp;
use Readonly;

extends qw(npg_qc::autoqc::checks::check);
with qw( npg_tracking::glossary::moniker);

## no critic (Documentation::RequirePodAtEnd)
our $VERSION = '0';

Readonly::Scalar our $DEFAULT_EXT     => q[stats];
Readonly::Scalar our $DEFAULT_SUFFIX  => q[F0x00];

=head1 NAME

npg_qc::autoqc::checks::samtools_stats

=head1 SYNOPSIS

Inherits from npg_qc::autoqc::checks::check.
See description of attributes in the documentation for that module.
  my $check = npg_qc::autoqc::checks::samtools_stats->new(rpt_list => q{1234:1:5;1234:2:5}, --filename_root=1234_1, --qc_out=out/qc, -qc_in=in/qc);

=head1 DESCRIPTION

A check which stores results from samtools stats file in standard QC JSON format

=head1 SUBROUTINES/METHODS

=head2 ext

Input file type extension.  Default - stats.

=cut

has 'ext' => (isa        => 'Str',
              is         => 'ro',
              required   => 0,
              default    => $DEFAULT_EXT,
              );

=head2 suffix

Input file type extension.  Default - stats.

=cut

has 'suffix' => (isa        => 'Str',
                 is         => 'ro',
                 required   => 0,
                 default    => $DEFAULT_SUFFIX,
                 );

=head2 execute

=cut

override 'execute' => sub {
  my $self = shift;

  super();

  # Read from stats files produced by spatial filter application for each sample

  $self->result->stats_file($self->input_files->[0]);
  $self->result->execute();

  return 1;
};

=head2 input_files

=cut

#####
# Custom builder for the input_files attribute 
#
sub _build_input_files {
  my $self = shift;

  if(!$self->has_qc_in) { croak 'qc_out should be defined'; }

  my $ffn = File::Spec->catdir($self->qc_in, $self->file_name_full($self->file_name, ext => $self->ext, suffix => $self->suffix));

  return [ $ffn ];
}

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

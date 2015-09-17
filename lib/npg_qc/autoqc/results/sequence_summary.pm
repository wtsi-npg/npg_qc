package npg_qc::autoqc::results::sequence_summary;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use Perl6::Slurp;
use Readonly;
use Carp;

use npg_tracking::util::types;
use npg_common::roles::software_location;

extends 'npg_qc::autoqc::results::base';

our $VERSION = '0';

Readonly::Array my @ATTRIBUTES => qw/ sequence_format
                                      header
                                      md5
                                      seqchksum
                                      seqchksum_sha512
                                    /;

has 'sequence_file'  => (
    isa        => 'NpgTrackingReadableFile',
    is         => 'ro',
    traits     => [ 'DoNotSerialize' ],
    required   => 0,
);

has [ @ATTRIBUTES ] => (
    is         => 'ro',
    isa        => 'Str',
    required   => 0,
    lazy_build => 1,
);
sub _build_sequence_format {
  my $self = shift;
  my ($path, $format) = $self->sequence_file =~ /\A(.+)[.]([^.]+)\Z/smx;
  $self->_set_root_path($path);
  return $format;
}
sub _build_header {
  my $self = shift;
  return join q[], grep { $_ !~ /\A\@SQ/smx }
    slurp q{-|}, $self->_samtools, 'view', '-H', $self->sequence_file;
}
sub _build_md5 {
  my $self = shift;
  return slurp $self->sequence_file . '.md5';
}
sub _build_seqchksum {
  my $self = shift;
  return slurp $self->_root_path . '.seqchksum';
}
sub _build_seqchksum_sha512 {
  my $self = shift;
  return slurp $self->_root_path . '.sha512primesums512.seqchksum';
}

has '_root_path' => (
    isa        => 'Str',
    traits     => [ 'DoNotSerialize' ],
    is         => 'ro',
    required   => 0,
    writer     => '_set_root_path',
);

has '_samtools' => (
    isa        => 'NpgCommonResolvedPathExecutable',
    coerce     => 1,
    is         => 'ro',
    traits     => [ 'DoNotSerialize' ],
    required   => 0,
    writer     => '_set_samtools',
);

override 'execute' => sub {
  my $self = shift;
  if (!$self->sequence_file) {
    croak 'CRAM/BAM file path (sequence_file attribute) should be set';
  }
  $self->_set_samtools('samtools1');
  super();
  for my $attr ( @ATTRIBUTES ) {
    $self->$attr;
  }
  return;
};

override 'filename_root' => sub  {
  my $self = shift;
  return $self->filename_root_from_filename($self->sequence_file);
};

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

npg_qc::autoqc::results::sequence_summary

=head1 SYNOPSIS

=head1 DESCRIPTION

A class for wrapping information about a sequence such as
a header, md5, etc.

=head1 SUBROUTINES/METHODS

=head2 sequence_file

Attribute, a path of bam/cram input file.

=head2 sequence_format

Attribute, sequence format (bam|cram) derived from the sequence file extension.

=head2 header

Attribute, header of the bam/cram sequence file, SQ lines filtered out.

=head2 md5

Attribute, md5 of the sequence file.

=head2 seqchksum

Attribute, seqchksum of the sequence file.

=head2 seqchksum_sha512

Attribute, seqchksum_sha512 of the sequence file.

=head2 execute

Method forcing all lazy attributes of the object to be built.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item namespace::autoclean

=item Readonly

=item Carp

=item Perl6::Slurp

=item npg_tracking::util::types

=item npg_common::roles::software_location

=item npg_qc::autoqc::results::base

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

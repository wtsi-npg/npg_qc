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

Readonly::Array my @ATTRIBUTES => qw/ header
                                      md5
                                      seqchksum
                                      seqchksum_sha512
                                    /;

has 'file_path_root' => (
    isa        => 'Str',
    traits     => [ 'DoNotSerialize' ],
    is         => 'ro',
    predicate  => '_has_file_path_root',
    required   => 0,
);

has 'sequence_format' => (
    is         => 'ro',
    isa        => 'Str',
    required   => 1,
);

has '_sequence_file' => (
    isa        => 'Str',
    traits     => [ 'DoNotSerialize' ],
    is         => 'ro',
    predicate  => '_has_sequence_file',
    required   => 0,
    lazy_build => 1,
);
sub _build__sequence_file {
  my $self = shift;
  if (!$self->_has_file_path_root) {
    croak 'file_path_root attribute is required';
  }
  return join q[.], $self->file_path_root, $self->sequence_format;
}

has [ @ATTRIBUTES ] => (
    is         => 'ro',
    isa        => 'Str',
    required   => 0,
    lazy_build => 1,
);

sub _build_header {
  my $self = shift;

  my $header = q[];
  my $header_file = $self->_sequence_file . q[.header];

  if (-f $header_file) { # Maybe a pre-generated header file exists.
    $header = slurp $header_file;
  } elsif (-f $self->_sequence_file) { # Maybe the bam|cram file exists,
                                       # should exist in the prod pipeline.
    $header =  join q[], grep { ($_ !~ /\A\@SQ/smx) }
      slurp q{-|}, {'utf8' => 1},
      $self->_samtools, 'view', '-H', $self->_sequence_file;
  } else {
    carp sprintf 'WARNING: Cannot generate header, %s does not exist or is not a file',
         $self->_sequence_file;
  }

  return $header;
}
sub _build_md5 {
  my $self = shift;
  return slurp $self->_sequence_file . '.md5';
}
sub _build_seqchksum {
  my $self = shift;
  return slurp $self->file_path_root . '.seqchksum';
}
sub _build_seqchksum_sha512 {
  my $self = shift;
  return slurp $self->file_path_root . '.sha512primesums512.seqchksum';
}

has '_samtools' => (
    isa        => 'NpgCommonResolvedPathExecutable',
    coerce     => 1,
    is         => 'ro',
    traits     => [ 'DoNotSerialize' ],
    predicate  => '_has_samtools',
    required   => 0,
    writer     => '_set_samtools',
);

sub execute {
  my $self = shift;
  $self->_set_samtools('samtools1');
  for my $attr ( @ATTRIBUTES ) {
    $self->$attr;
  }
  return;
}

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

=head2 file_path_root

Attribute, a path of the relevant bam/cram file with extension truncated,
required, is not serialized to json.

=head2 sequence_format

Attribute, sequence format (bam|cram), required.

=head2 header

Attribute, header of the bam/cram sequence file, @SQ lines filtered out.
To be compatible with JSON format, this string is UTF8-encoded.

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

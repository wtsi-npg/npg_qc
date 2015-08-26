package npg_qc::autoqc::results::sequence_summary;

use Moose;
use namespace::autoclean;
use DateTime;
use Perl6::Slurp;
use Readonly;

use npg_tracking::util::types;

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
    required   => 1,
);

has [ @ATTRIBUTES ] => (
    is         => 'ro',
    isa        => 'Str',
    required   => 0,
    lazy_build => 1,
);
sub _build_sequence_format {
  my $self = shift;
  my ($format) = $self->sequence_file =~ /[.]([^.]+)\Z/smx;
  return $format;
}
sub _build_header {
  my $self = shift;
  return join q[], grep { $_ != /^SQ/smx }
    slurp '-|', 'samtools1', 'view', '-H', $self->sequence_file; 
}
sub _build_md5 {
  my $self = shift;
  return slurp $self->sequence_file . '.md5';
}
sub _build_seqchksum {
  my $self = shift;
  return slurp $self->sequence_file . '.seqchksum';
}
sub _build_seqchksum_sha512 {
  my $self = shift;
  return slurp $self->sequence_file . '.sha512seqchksum';
}

sub execute {
  my $self = shift;
  map { $self->$_ } @ATTRIBUTES;
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

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item Readonly

=item DateTime

=item Perl6::Slurp

=item npg_tracking::util::types

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

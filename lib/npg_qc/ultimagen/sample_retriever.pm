package npg_qc::ultimagen::sample_retriever;

use Moose::Role;
use Carp;

use npg_tracking::util::types;
use npg_qc::ultimagen::library_info;
use npg_qc::ultimagen::manifest;

our $VERSION = '0';

##no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc::ultimagen::sample_retriever

=head1 SYNOPSIS

=head1 DESCRIPTION

Source-agnostic retriever of information about samples from files either
supplied at the time of setting up an Ultima Genomics run or produced by
this platform's software.

=head1 SUBROUTINES/METHODS

=head2 manifest_path

=cut

has 'manifest_path' => (
  isa      => 'NpgTrackingReadableFile',
  is       => 'ro',
  required => 0,
  predicate => 'has_manifest_path',
  documentation => 'Ultima Genomics manifest file path, optional',
);

=head2 runfolder_path

=cut

has 'runfolder_path' => (
  isa      => 'NpgTrackingDirectory',
  is       => 'ro',
  required => 0,
  predicate => 'has_runfolder_path',
  documentation => 'Ultima Genomics run folder path, optional',
);

=head2 get_samples

Returns an array of C<npg_qc::ultimagen::sample> objects, which can be empty.

=cut

sub get_samples {
  my $self= shift;

  my $si;
  if ($self->has_manifest_path) {
    $si = npg_qc::ultimagen::manifest->new(input_file_path => $self->manifest_path);
  } elsif ($self->has_runfolder_path) {
    my @library_info_paths = glob join q[/], $self->runfolder_path, '*LibraryInfo.xml';
    (@library_info_paths == 1) or croak 'Too many or no *LibraryInfo.xml files';
    $si = npg_qc::ultimagen::library_info->new(input_file_path => $library_info_paths[0]);
    if ($si->application && ($si->application =~ /quantum/xmsi)) {
      carp 'Skipping quantum application';
      $si = undef;
    }
  } else {
    croak 'Either runfolder_path or manifest_path should be set';
  }

  return defined $si ? $si->samples : [];
}

1;

__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Carp

=item npg_tracking::util::types

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina GourtovaiaE<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2025 Genome Research Ltd.

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

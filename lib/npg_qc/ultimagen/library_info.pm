package npg_qc::ultimagen::library_info;

use Moose;
use namespace::autoclean;
use XML::LibXML;
use Carp;

use npg_tracking::util::types;
use npg_qc::ultimagen::sample;

our $VERSION = '0';

##no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc::ultimagen::library_info

=head1 SYNOPSIS

  my $li = npg_qc::ultimagen::library_info->new(input_file_path => '123_LibraryInfo.xml');
  foreach my $sample ( @{$li->samples} ) {
    print $sample->index_sequence();
  }

=head1 DESCRIPTION

Parser for the manifest supplied to start a run on the Ultima Genomics
sequencing instrument.

This class provides a number of public attributes. Only one of them, C<input_file_path>,
can be set via the constructor. The rest of them are the results of parsing
the input file.

=head1 SUBROUTINES/METHODS

=head2 input_file_path

[RunId]_LibraryInfo.xml, a full path, required. This file is available
at the top level of the run folder. The content of this file is the input
for the parser.

=cut

has input_file_path => (
  isa      => 'NpgTrackingReadableFile',
  is       => 'ro',
  required => 1,
);

=head2 xml_doc

Top level C<XML::LibXML::Document> object for the input file.

=cut

has 'xml_doc' => (
  isa        => 'XML::LibXML::Document',
  is         => 'ro',
  init_arg   => undef,
  lazy_build => 1,
);
sub _build_xml_doc {
  my $self = shift;
  return XML::LibXML->load_xml(location => $self->input_file_path);
}

=head2 application

Ultima Genomics application name as defined in the input file. Might be undefined. 

=cut

has 'application' => (
  isa        => 'Str|Undef',
  is         => 'ro',
  init_arg   => undef,
  lazy_build => 1,
);
sub _build_application {
  my $self = shift;
  my @nodelist = $self->xml_doc()->getElementsByTagName('Attributes');
  (@nodelist <= 1) or croak 'Only one Attributes element is expected';
  my @applications = ();
  if (@nodelist) {
    @applications = map { $_->getAttribute('Value') }
                    grep { ($_->getAttribute('Name') || q[]) eq 'Application'}
                    grep { ref $_ eq 'XML::LibXML::Element' }
                    $nodelist[0]->childNodes();
    (@applications <= 1) or croak 'Only one Applicaton definition is expected';
  }
  my $application = $applications[0];
  $application ||= undef;

  return $application;
}

=head2 sample_elements

A list of C<XML::LibXML::Element> ojects for a sample.

=cut

has 'sample_elements' => (
  isa => 'ArrayRef[XML::LibXML::Element]',
  is         => 'ro',
  init_arg   => undef,
  lazy_build => 1,
);
sub _build_sample_elements {
  my $self = shift;
  my @nodelist = $self->xml_doc()->getElementsByTagName('Sample');
  @nodelist or croak 'Sample elements are not found in ' . $self->input_file_path;
  return \@nodelist;
}

=head2 samples

The main output of the parser.

A list of C<npg_qc::ultimagen::sample> objects in the order the samples
are listed in the input file. 

=cut

has 'samples' => (
  isa        => 'ArrayRef[npg_qc::ultimagen::sample]',
  is         => 'ro',
  init_arg   => undef,
  lazy_build => 1,
);
sub _build_samples {
  my $self = shift;
  my @samples = ();
  foreach my $se (@{$self->sample_elements}) {
    my ($sample_id, $lib_name) = split /@/smx, $se->getAttribute('Id');
    my $init = {
      id => $sample_id,
      library_name => $lib_name,
      index_label => $se->getAttribute('Index_Label'),
      index_sequence => $se->getAttribute('Index_Sequence'),
    };
    my @app_type_values =
      map  { $_->getAttribute('Value') }
      grep { $_->getAttribute('Name') eq 'application_type' }
      grep { ref $_ eq 'XML::LibXML::Element' }
      $se->childNodes();
    if (@app_type_values == 1) {
      $init->{application_type} = $app_type_values[0];
    } elsif (@app_type_values > 1) {
      croak 'Multiple application type values for index label '
        . $init->{index_label};
    }

    push @samples, npg_qc::ultimagen::sample->new($init);
  }
  return \@samples;
}

1;

__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item XML::LibXML

=item Carp

=item npg_tracking::util::types

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia

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

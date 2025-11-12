package npg_qc::ultimagen::library_info;

use Moose;
use namespace::autoclean;
use XML::LibXML;
use Carp;

use npg_tracking::util::types;
use npg_qc::ultimagen::sample;

our $VERSION = '0';

has input_file_path => (
  isa      => 'NpgTrackingReadableFile',
  is       => 'ro',
  required => 1,
);

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
    push @samples, npg_qc::ultimagen::sample->new(
      id => $se->getAttribute('Id'),
      index_label => $se->getAttribute('Index_Label'),
      index_sequence => $se->getAttribute('Index_Sequence')
    );
  }
  return \@samples;
}

1;
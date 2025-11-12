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
#map { $_->getAttribute('Value') }
#grep { ($_->getAttribute('Name') || q[]) eq 'Application'}

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
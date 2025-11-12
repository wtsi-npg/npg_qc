package npg_qc::ultimagen::manifest;

use Moose;
use namespace::autoclean;
use Text::CSV;
use Carp;

use npg_tracking::util::types;
use npg_qc::ultimagen::sample;

our $VERSION = '0';

has input_file_path => (
  isa      => 'NpgTrackingReadableFile',
  is       => 'ro',
  required => 1,
);

has 'samples' => (
  isa        => 'ArrayRef[npg_qc::ultimagen::sample]',
  is         => 'ro',
  init_arg   => undef,
  lazy_build => 1,
);
sub _build_samples {
  my $self = shift;
  my @samples = ();
  foreach my $row (@{$self->_sample_rows}) {
    push @samples, npg_qc::ultimagen::sample->new(
      id => $row->{'sample_id'},
      index_label => $row->{'index_barcode_num'},
      index_sequence => $row->{'index_barcode_sequence'}
    );
  }
  return \@samples;
}

has '_sample_rows' => (
  isa        => 'ArrayRef[HashRef]',
  is         => 'ro',
  init_arg   => undef,
  lazy_build => 1,
);
sub _build__sample_rows {
  my $self = shift;

  open my $fh3, q[<], $self->input_file_path;
  ## no critic (InputOutput::RequireBriefOpen)
  open my $fh4, q[<], $self->input_file_path;
  # Read from both file handles in parallel till $fh3 reaches the
  # samples section. At this point discards $fh3 and pass $fh4
  # to the parser.
  while ( my $line = readline $fh3 ) {
    readline $fh4 ;
    if ($line =~ /^\[(?:Samples)|(?:Data)\]/xms) {
      close $fh3;
     last;
    }
  }

  my $csv = Text::CSV->new();
  $csv->header($fh4);
  my @rows = ();
  while (my $row = $csv->getline_hr($fh4)) {
    if ($row->{'sample_id'} =~ /^\[/xms) { # Start of some other section.
      last;
    }
    push @rows, $row;
  }
  close $fh4;

  @rows or croak 'No sample rows in ' . $self->input_file_path;
  return \@rows;
}

1;
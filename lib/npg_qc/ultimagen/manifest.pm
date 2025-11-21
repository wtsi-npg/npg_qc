package npg_qc::ultimagen::manifest;

use Moose;
use namespace::autoclean;
use Text::CSV;
use autodie;
use Carp;

use npg_tracking::util::types;
use npg_qc::ultimagen::sample;

our $VERSION = '0';

##no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc::ultimagen::manifest

=head1 SYNOPSIS

  my $m = npg_qc::ultimagen::manifest->new(input_file_path => '123_458.csv');
  foreach my $sample ( @{$m->samples} ) {
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

Manifest file, a full path, required. The content of this file is the input
for the parser.

=cut

has input_file_path => (
  isa      => 'NpgTrackingReadableFile',
  is       => 'ro',
  required => 1,
);

=head2 samples

The output of the parser.

A list of C<npg_qc::ultimagen::sample> type objects in the order the samples
are listed in the manifest. 

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

__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item Text::CSV

=item autodie

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
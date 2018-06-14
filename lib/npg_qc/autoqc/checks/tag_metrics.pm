package npg_qc::autoqc::checks::tag_metrics;

use Moose;
use namespace::autoclean;
use MooseX::ClassAttribute;
use Carp;
use Readonly;
use List::Util qw(min);
use st::api::lims;

our $VERSION = '0';

extends qw(npg_qc::autoqc::checks::check);

## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc::autoqc::checks::tag_metrics

=head1 SYNOPSIS

Inherits from npg_qc::autoqc::checks::check. See description of attributes in the documentation for that module.

=head1 DESCRIPTION

 An autoqc check object that parses results of barcode decoding
 by picard https://broadinstitute.github.io/picard/command-line-overview.html#ExtractIlluminaBarcodes
 according to the metric described in
 https://broadinstitute.github.io/picard/picard-metric-definitions.html#ExtractIlluminaBarcodes.BarcodeMetric


=head1 SUBROUTINES/METHODS

=cut

Readonly::Hash our %METRICS_MAPPING => (
          'BARCODE' => 'tags',
          'BARCODE_NAME' => undef,
          'DESCRIPTION' => undef,
          'READS' => 'reads_count',
          'PF_READS' => 'reads_pf_count',
          'PERFECT_MATCHES' => 'perfect_matches_count',
          'PF_PERFECT_MATCHES' => 'perfect_matches_pf_count',
          'ONE_MISMATCH_MATCHES' => 'one_mismatch_matches_count',
          'PF_ONE_MISMATCH_MATCHES' => 'one_mismatch_matches_pf_count',
          'PCT_MATCHES' => 'matches_percent',
          'PF_PCT_MATCHES' => 'matches_pf_percent', );

Readonly::Hash our %HEADER_MAPPING => (
          'BARCODE_TAG_NAME' => 'barcode_tag_name',
          'MAX_MISMATCHES' => 'max_mismatches_param',
          'MIN_MISMATCH_DELTA' => 'min_mismatch_delta_param',
          'MAX_NO_CALLS' => 'max_no_calls_param',
          'PCT_TAG_HOPS' => 'tag_hops_percent',
                                      );

Readonly::Scalar our $ERROR_TOLERANCE_PERCENT => 20;

=head2 spiked_control_description

Class Attribute. Returns an expected description of the spiked control.

=cut
class_has 'spiked_control_description' => (isa        => 'Str',
                                           is         => 'ro',
                                           default    => 'SPIKED_CONTROL',
                                          );

has '+file_type' => (default  => 'bam.tag_decode.metrics',);

has '_columns'   => (isa => 'Maybe[HashRef]', is => 'ro', writer => '_set_columns',);

sub _set_column_indices {
  my ($self, $columns_header) = @_;

  my @column_names = split /\t/smx, $columns_header;
  my $index = 0;

  my $columns = {};

  foreach my $name (@column_names) {
    if (exists $METRICS_MAPPING{$name}) {
      $columns->{$name} = $index;
    }
    $index++;
  }
  if (scalar keys %{$columns} != scalar keys %METRICS_MAPPING) {
    croak q[Not all needed columns are present in ] . $self->result->metrics_file .
    q[. Was looking for ] . (join q[ ], sort keys %METRICS_MAPPING);
  }
  $self->_set_columns($columns);
  return;
}

sub _parse_header {
  my ($self, $header) = @_;

  my @components = split /\s/smx, $header;
  foreach my $component (@components) {
    if (!$component) { next; }
    my $delim = q[=];
    my @pair = split /$delim/smx, $component;
    if (scalar @pair == 2) {
      my $key   = $pair[0];
      my $value = $pair[1];
      if (!$value || !$key) { next; }
      if (exists $HEADER_MAPPING{$key}) {
        my $attr = $HEADER_MAPPING{$key};
        $self->result->$attr($value);
      }
    }
  }
  return;
}

sub _parse_tag_metrics {
  my ($self, $barcode_line) = @_;

  my @values = split /\t/smx, $barcode_line;

  my $barcode_index = $values[$self->_columns->{'BARCODE_NAME'}];
  if (!$barcode_index) { $barcode_index = 0; }

  foreach my $column_name (keys %METRICS_MAPPING) {
    my $attr_name = $METRICS_MAPPING{$column_name};
    if ($attr_name) {
      my $value = $values[$self->_columns->{$column_name}];
      if ($value || $value == 0) {
        $self->result->$attr_name->{$barcode_index} = $value;
      }
    }
  }

  my $description = $values[$self->_columns->{'DESCRIPTION'}];
  my $spiked_description = $self->spiked_control_description;
  if ($description =~ /$spiked_description/smxi) {
    if ($self->result->spiked_control_index) {
      croak 'Multiple indices are marked as spiked control';
    }
    $self->result->spiked_control_index($barcode_index);
  }

  return;
}

sub _calculate_tag_hops_power {
  my ($self) = @_;

  my $nsamples = 0;
  my %tags0 = ();
  my %tags1 = ();
  my $lims = st::api::lims->new(id_run=>$self->id_run, position=>$self->position);
  foreach my $plex ($lims->children) {
    my $tag_sequences = $plex->tag_sequences;
    # skip samples with no second index i.e. phix
    if (@{$tag_sequences} != 2) { next; }
    $nsamples++;
    $tags0{$tag_sequences->[0]}++;
    $tags1{$tag_sequences->[1]}++;
  }

  my $count0 = scalar keys %tags0 ;
  my $count1 = scalar keys %tags1 ;
  my $ncombinations = $count0 * $count1;
  my $nudis = min($count0, $count1);
  my $power = ($ncombinations == $nudis) ? 0 : ($ncombinations - $nsamples) / ($ncombinations - $nudis);

  $self->result->tag_hops_power($power);
  return;
}

override 'can_run' => sub  {
  my $self = shift;
  return ($self->num_components() == 1 &&
    !defined $self->composition->get_component(0)->tag_index) ? 1 : 0;
};

override 'execute' => sub  {
  my $self = shift;

  super();

  my $metrics_file = $self->input_files->[0];
  $self->result->metrics_file($metrics_file);
  ## no critic (InputOutput::RequireBriefOpen)
  open my $fh, '<', $metrics_file or croak qq[Cannot open $metrics_file for reading];
  ## use critic
  my $line = <$fh>;
  $line = <$fh>;
  $self->_parse_header($line);
  <$fh>;<$fh>;<$fh>;<$fh>;
  $line = <$fh>;
  $self->_set_column_indices($line);
  while (my $tag_metrics = <$fh>) {
    chomp $tag_metrics;
    if (!$tag_metrics) { next; }
    $self->_parse_tag_metrics($tag_metrics);
  }
  close $fh or carp q[Cannot close a filehandle];

  if (open my $fh, '<', $metrics_file.q[.hops]) {
    $line = <$fh>;
    $line = <$fh>;
    if ($line) {
      $self->_parse_header($line);
    } else {
      $self->result->tag_hops_percent(0);
    }
    close $fh or carp q[Cannot close a filehandle for hops file];
    $self->_calculate_tag_hops_power();
  }

  my $pass = ($self->result->errors_percent > $ERROR_TOLERANCE_PERCENT) ? 0 : 1;
  $self->result->pass($pass);

  return 1;
};

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item MooseX::ClassAttribute

=item Carp

=item Readonly

=item List::Util

=item st::api::lims

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

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

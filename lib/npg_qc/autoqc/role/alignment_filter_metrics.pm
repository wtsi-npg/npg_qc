package npg_qc::autoqc::role::alignment_filter_metrics;

use Moose::Role;
use Readonly;

our $VERSION = '0';
## no critic (Documentation::RequirePodAtEnd)

Readonly::Scalar our $HUNDRED   => 100;
Readonly::Scalar our $UNMAPPED  => 'Unmapped';
Readonly::Scalar our $UNKNOWN   => 'Unknown';

=head1 NAME

npg_qc::autoqc::role::alignment_filter_metrics

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SUBROUTINES/METHODS

=head2 refs

 An array of species whose references are used in split by alignment. If the species information is missing, 'Unknown' is used. If the sequence is unaligned, 'Unmapped' is used.

=cut

sub refs {
  my $self = shift;

  my @refs = ();
  foreach my $ref (@{$self->all_metrics->{'refList'}}) {
    my $species = q[];
    my $assembly = q[];
    my $sequence_name = q[];
    foreach my $chromosome (@{$ref}) {
      $species = $chromosome->{'sp'};
      $assembly = $chromosome->{'as'};
      $sequence_name = $chromosome->{'sn'};
      if ($species || $assembly || $sequence_name) {
	last;
      }
    }
    if ($species && $assembly) {
      $species .= qq[ $assembly];
    }
    $species ||= $assembly;
    $species ||= $sequence_name;
    $species ||= $UNKNOWN;
    push @refs, $species;
  }

  my $command = $self->all_metrics->{'programCommand'};
  if ($command && $command =~ /OUTPUT_UNALIGNED/xms) {
    push @refs, $UNMAPPED;
  }
  return @refs;
}

=head2 stats_per_ref

 A count and percent of reads in split files by organism. For the last organism, if aligned, the values for unmapped reads are also available. All percents are calculated against the total reads number.

=cut

sub stats_per_ref {
  my $self = shift;

  my $h = {};
  my $total = $self->total_reads;
  my @refs = $self->refs;
  my $num_refs = scalar @refs;
  my $i = 0;
  while ($i < $num_refs) {

    my $ref = $refs[$i];
    my $count = $ref eq $UNMAPPED ? 0 : $self->all_metrics->{readsCountPerRef}->[$i];

    if ($num_refs - $i == 1) { # last output
      my $count_unmapped = $self->all_metrics->{readsCountUnaligned};
      $count += $count_unmapped;
      if ( $ref ne $UNMAPPED ) {
        $h->{$ref}->{count_unmapped} =  $count_unmapped;
        $h->{$ref}->{percent_unmapped} =  $total ? ($count_unmapped * $HUNDRED ) /$total : 0;
      }
    }

    $h->{$ref}->{count}   = $count;
    $h->{$ref}->{percent} = $total ? ($count * $HUNDRED ) /$total : 0;
    $i++;
  }
  return $h;
}

=head2 chimeric_reads

 A count and percent of chimeric reads ie fragments with ends mapping to different references. Percent is calculated against the total reads number.

=cut

sub chimeric_reads {
  my $self = shift;

  my $counts_array = $self->all_metrics->{chimericReadsCount};
  my $metrics_size = scalar @{$counts_array};

  my $chimeric_reads_count = 0;
  my $i = 0;
  while ($i < $metrics_size) {
    if ( !@{$counts_array->[$i]} ) {
      $chimeric_reads_count = 0;
      last;
    }
    my $j = 0;
    while ($j < $metrics_size) {
      if ($i != $j) {
        $chimeric_reads_count += $counts_array->[$i]->[$j];
      }
      $j++;
    }
    $i++;
  }

  my $h = {};
  my $total = $self->total_reads;
  $h->{count} = $chimeric_reads_count;
  $h->{percent} = $total ? ( $chimeric_reads_count * $HUNDRED ) / $total : 0;

  return $h;
}

=head2 ambiguous_reads

 A pessimistic estimate of a number and percent of reads that have at least one end aligning to multiple references. Percent is calculated against the total reads number.

=cut

sub ambiguous_reads {
  my $self = shift;

  my $h = {};
  my $total = $self->total_reads;
  my @forward = @{$self->all_metrics->{readsCountByAlignedNumForward}};
  my @reverse = @{$self->all_metrics->{readsCountByAlignedNumReverse}};

  my $ambiguous_count = 0;
  my $array_length = scalar @forward;

  # The first number is non aligned to any reference
  # The second number is aligned to a single reference
  my $i = 2;
  while ($i < $array_length) {
    my $tempr = @reverse ? $reverse[$i] : 0;
    my $tempf = $forward[$i];
    my $temp = $tempr > $tempf ? $tempr : $tempf;
    $ambiguous_count += $temp;
    $i++;
  }

  $h->{count} = $ambiguous_count;
  $h->{percent} = $total ? ( $ambiguous_count * $HUNDRED ) / $total : 0;

  return $h;
}

=head2 total_reads

 Number of total reads before the split

=cut

sub total_reads {
  my $self = shift;
  return $self->all_metrics->{'totalReads'};

}

no Moose::Role;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Readonly

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

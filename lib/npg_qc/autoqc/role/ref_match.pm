package npg_qc::autoqc::role::ref_match;

use Moose::Role;
use Readonly;

our $VERSION = '0';

Readonly::Scalar my $PERCENT => 100;

sub percent_count {
  my $self = shift;

  my $counts      = $self->aligned_read_count() || {};
  my $sample_size = $self->sample_read_count();
  my $percentage = {};

  if ($sample_size) {
    foreach my $organism ( keys %{$counts} ) {
      $percentage->{$organism} = sprintf '%.1f',
         $PERCENT * ( $counts->{$organism} / $sample_size );
    }
  }

  return $percentage;
}

sub ranked_organisms {
  my ($self, $ratings) = @_;

  $ratings ||= $self->percent_count();

  # Deterministic ranking of organisms:
  # reverse numerical comparison of alignment results
  # followed, if necessary, by string comparison of names.
  my @ranked_organisms = sort {
    $ratings->{$b} <=> $ratings->{$a}
    || $a cmp $b
  } keys %{$ratings};

  return \@ranked_organisms;
}

sub top_two {
  my $self = shift;

  my $ratings = $self->percent_count();
  my @ranked = @{$self->ranked_organisms($ratings)};
  my @top_two = ();
  for (qw/1 2/) {
    my $organism = shift @ranked;
    $organism or last;
    my $strain = $self->reference_version->{$organism};
    my $percent = $ratings->{$organism};
    $organism =~ s/_/ /xms;
    $organism = join q[ ], $organism, $strain;
    push @top_two, {name => $organism, percent => $percent};
  }
  return @top_two;
}

no Moose::Role;

1;

__END__


=head1 NAME

    npg_qc::autoqc::role::ref_match

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 percent_count

Calculates a rating value for each organism, i.e. the percentage of
sampled reads aligning to the organism's reference genome. Returns
a potentially empty hash of organism-rating key-value pairs.

=head2 ranked_organisms

Returns an array of reference names. The array is sorted according to
the number of reads from the sample, which aligned to the reference.
Where the number of aligned reads is the same, the reference names are
sorted alphabetically. The sort order is better alignment first.

=head2 top_two

Return a list of up to two hash references, each containing the
organist name and version/strain and corresponding to it percent
mapped.

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

John O'Brien E<lt>jo3@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2016, 2019 GRL

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

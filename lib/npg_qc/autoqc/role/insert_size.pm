package npg_qc::autoqc::role::insert_size;

use Moose::Role;
use Readonly;
use Math::Round qw(round);
use List::Util qw(max min);

with qw( npg_qc::autoqc::role::result );

our $VERSION = '0';
## no critic (Documentation::RequirePodAtEnd)

Readonly::Scalar our $HUNDRED              => 100;

=head1 NAME

npg_qc::autoqc::role::insert_size

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SUBROUTINES/METHODS

=head2 criterion

Criterion that was used to evaluate a pass/fail for this check.

=cut
sub criterion {
    return q[The value of the third quartile is larger than the lower boundary of the expected size];
};


=head2 quartiles

A string representation of the quartile array or undef

=cut
sub quartiles {
  my $self = shift;
  my $result = undef;
  if ($self->quartile1) {
    $result =  $self->quartile1 . q[ ] . $self->median . q[ ] . $self->quartile3;
  }
  return $result;
}


=head2 percent_well_aligned_reads

Percent of well-aligned reads or undef

=cut
sub percent_well_aligned_reads {
  my ($self, $opp_dir) = @_;
  my $method = q[num_well_aligned_reads];
  if ($opp_dir) {
    $method .= q[_opp_dir];
  }
  return defined $self->$method ? round($self->$method/$self->sample_size * $HUNDRED) : undef;
}


=head2 expected_size_range

A string representation of the insert size range or undef

=cut
sub expected_size_range {
  my $self = shift;

  my $expected_size;
  if ($self->expected_mean) {
    $expected_size = $self->expected_mean;
  } elsif ($self->expected_size) {
    my $min = min @{$self->expected_size};
    my $max = max @{$self->expected_size};
    if ($min == $max) {
      $expected_size = $min;
	  } else {
      $expected_size = join q[:], $min, $max;
	  }
  }
  return $expected_size;
}

no Moose;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Readonly

=item Math::Round

=item List::Util

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 Genome Research Ltd

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

#########
# Author:        Marina Gourtovaia
# Created:       14 April 2009
#

package npg_qc::autoqc::role::insert_size;

use strict;
use warnings;
use Moose::Role;
use Carp;
use English qw(-no_match_vars);
use Readonly;
use Math::Round qw(round);

use npg_common::diagram::visio_histo_google;

with qw( npg_qc::autoqc::role::result );

our $VERSION = '0';
## no critic (Documentation::RequirePodAtEnd)


=head1 NAME

npg_qc::autoqc::role::insert_size

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SUBROUTINES/METHODS

=cut


Readonly::Scalar our $HUNDRED              => 100;

Readonly::Scalar our $MIN_Y                => 0;
Readonly::Scalar our $NUM_XAXIS_POINTS     => 9;
Readonly::Scalar our $NUM_YAXIS_POINTS     => 6;
Readonly::Scalar our $IMAGE_WIDTH          => 650;
Readonly::Scalar our $IMAGE_HIGHT          => 300;
Readonly::Scalar our $BLUE                 => '4D89F9';
Readonly::Scalar our $YELLOW               => 'FFCC66';

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

    my $expected_size = undef;
    if ($self->expected_mean) {
        $expected_size = $self->expected_mean;
    } else {
        if ($self->expected_size) {
            my $l = scalar @{$self->expected_size};
            my $min = $self->expected_size->[0];
            my $max = $self->expected_size->[1];
            if ($l > 2) {
                my $i = 2;
                while ($i < $l) {
                    if ($self->expected_size->[$i] < $min) {
                        $min = $self->expected_size->[$i];
		    }
                    $i++;
                    if ($i == $l) { last; }
                    if ($self->expected_size->[$i] > $max) {
                        $max = $self->expected_size->[$i];
		    }
                    $i++;
                }
	    }
            if ($min == $max) {
                $expected_size = $min;
	    } else {
                $expected_size = join q[:], $min, $max;
	    }
	}
    }
    return $expected_size;
}


=head2 image_url

The URL of the google API image or an empty string

=cut
sub image_url {
  my $self = shift;

  if (!$self->bins || !$self->bin_width || !(defined $self->min_isize)) {return q[]};

  my $colour = $self->paired_reads_direction_in ? $BLUE : $YELLOW;
  my $dia = npg_common::diagram::visio_histo_google->new( {
      chco_chart_colour      => ['chco', $colour],
  } );
  $dia->set_data($self->bins);

  my $ymax = 0;
  for my $d (@{$self->bins}) {
    if ($d > $ymax) {$ymax = $d;}
  }

  $dia->set_axisY_min_max(0, $ymax);
  $dia->set_chart_title(q[Insert sizes: run ] . $self->id_run . q[, position ] . $self->position);
  $dia->set_chart_size($IMAGE_WIDTH, $IMAGE_HIGHT);

  my $xmax = $self->min_isize + $self->bin_width * (scalar (@{$self->bins}) - 1);

  my $x_delta = ($xmax-$self->min_isize) /($NUM_XAXIS_POINTS - 1);
  my $y_delta = ($ymax-$MIN_Y)/($NUM_YAXIS_POINTS - 1);
  $x_delta = int $x_delta;
  $y_delta = int $y_delta;

  $dia->set_chart_labels($self->min_isize, $xmax, $x_delta, $MIN_Y, $ymax, $y_delta);
  return $dia->get_diagram_string();
}


no Moose;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Carp

=item English

=item Readonly

=item Math::Round

=item npg_common::diagram::visio_histo_google

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Author: Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Marina Gourtovaia

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

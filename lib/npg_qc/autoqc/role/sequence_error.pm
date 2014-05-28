#########
# Author:        gq1
# Created:       16 November 2009
#

package npg_qc::autoqc::role::sequence_error;

use strict;
use warnings;
use PDL::Lite;
use PDL::Core qw(list pdl);
use PDL::Primitive qw(stats);
use Moose::Role;
use Readonly;
use npg_common::diagram::visio_histo_google;

with qw(npg_qc::autoqc::role::result);

our $VERSION = '0';

Readonly::Scalar our $IMAGE_WIDTH_EXTRA     => 45;
Readonly::Scalar our $BAR_WIDTH             => 4;
Readonly::Scalar our $BAR_DISTANCE          => 1;
Readonly::Scalar our $IMAGE_HEIGHT          => 300;
Readonly::Scalar our $MIN_Y                 => 0;
Readonly::Scalar our $NUM_XAXIS_POINTS      => 9;
Readonly::Scalar our $PERCENT               => 100;
Readonly::Scalar our $UNDEF_N_COUNT_COLOUR  => q{9EAAFF};
Readonly::Scalar our $N_COUNT_COLOUR        => q{DB4400};
Readonly::Scalar our $MISMATCH_COLOUR       => q{4D89F9};
Readonly::Scalar our $DEF_N_COUNT_COLOUR    => qq{$MISMATCH_COLOUR,$N_COUNT_COLOUR};
Readonly::Scalar our $HIGH_Q_VALS           => q{0812F7};
Readonly::Scalar our $MID_Q_VALS            => q{31F613};
Readonly::Scalar our $LOW_Q_VALS            => q{ECF21C};
Readonly::Scalar our $MISC_1                => q{CC2EFA};
Readonly::Scalar our $MISC_2                => q{58FAF4};
Readonly::Scalar our $MISC_3                => q{0B243B};
Readonly::Scalar our $LIGHT_GREY            => q{BDBDBD};
Readonly::Scalar our $BY_PERCENT_COLOUR     => qq{$HIGH_Q_VALS,$MID_Q_VALS,$LOW_Q_VALS,$N_COUNT_COLOUR};
Readonly::Scalar our $CIGAR_COLOUR          => qq{$HIGH_Q_VALS,$MID_Q_VALS,$LIGHT_GREY,$N_COUNT_COLOUR,$MISC_1,$MISC_2,$MISC_3};
Readonly::Scalar our $CIGAR_X_DELTA         => 10;
Readonly::Scalar our $CIGAR_Y_DELTA         => 1000;

sub forward_average_percent_error {
  my $self = shift;

  my $total_count = $self->forward_count();
  if(!$total_count || ( scalar @{$total_count} == 0 ) ){
    $total_count = $self->forward_aligned_read_count;
  }

  my $error_rate_by_cycle = pdl($self->forward_errors||[])/ pdl( $total_count );
  return _average_percent($error_rate_by_cycle);
}

sub reverse_average_percent_error {
  my $self = shift;

  my $total_count = $self->reverse_count();
  if(!$total_count || ( scalar @{$total_count} == 0 ) ){
    $total_count = $self->reverse_aligned_read_count;
  }

  my $error_rate_by_cycle = pdl($self->reverse_errors||[])/ pdl( $total_count );
  return _average_percent($error_rate_by_cycle);
}

sub _average_percent{
  my $error_rate_by_cycle = shift;

  return sprintf '%.2f',(stats($error_rate_by_cycle))[0]*$PERCENT;
}

sub forward_google_chart{
  my ( $self, $args ) = @_;
  $args ||= {};

  my $total_count = $self->forward_count();
  if(!$total_count || ( scalar @{$total_count} == 0 ) ){
    $total_count = $self->forward_aligned_read_count;
  }

  my $forward_errors_less_n_count = $self->forward_errors || [];

  my $forward_n_error_rate_by_cycle;
  my $error_rate_by_cycle;

  $args->{error_by_base}  = $error_rate_by_cycle;
  $args->{fastq}          = $self->forward_read_filename();
  $args->{n_count}        = $forward_n_error_rate_by_cycle;

  if ( defined $self->forward_quality_bins() ) {
    $args->{n_count} = pdl($self->forward_n_count)/ pdl( $total_count );
    $forward_errors_less_n_count = [];
    my $index = 0;
    foreach my $type ( qw{high mid low}) {
      $args->{$type} = pdl($self->forward_quality_bins()->[$index])/pdl($total_count);
      $index++;
    }
  } elsif ( defined $self->forward_n_count() ) {
    $forward_errors_less_n_count = pdl($self->forward_errors||[]) - pdl($self->forward_n_count||[]);
    $args->{n_count} = pdl($self->forward_n_count)/ pdl( $total_count );
    $args->{error_by_base} = pdl( $forward_errors_less_n_count )/ pdl( $total_count );
  } else {
    $args->{error_by_base} = pdl( $forward_errors_less_n_count )/ pdl( $total_count );
  };

  return $self->_image_url( $args );
}

sub reverse_google_chart{
  my ( $self, $args ) = @_;
  $args ||= {};

  my $total_count = $self->reverse_count();
  if(!$total_count || ( scalar @{$total_count} == 0 ) ){
    $total_count = $self->reverse_aligned_read_count;
  }

  my $reverse_errors_less_n_count = $self->reverse_errors || [];

  my $reverse_n_error_rate_by_cycle;
  my $error_rate_by_cycle;

  $args->{error_by_base}  = $error_rate_by_cycle;
  $args->{fastq}          = $self->reverse_read_filename();
  $args->{n_count}        = $reverse_n_error_rate_by_cycle;

  if ( defined $self->reverse_quality_bins() ) {
    $args->{n_count} = pdl($self->reverse_n_count)/ pdl( $total_count );
    $reverse_errors_less_n_count = [];
    my $index = 0;
    foreach my $type ( qw{high mid low}) {
      $args->{$type} = pdl($self->reverse_quality_bins()->[$index])/pdl($total_count);
      $index++;
    }
  } elsif ( defined $self->reverse_n_count() ) {
    $reverse_errors_less_n_count = pdl($self->reverse_errors||[]) - pdl($self->reverse_n_count||[]);
    $args->{n_count} = pdl($self->reverse_n_count)/ pdl( $total_count );
    $args->{error_by_base} = pdl( $reverse_errors_less_n_count )/ pdl( $total_count );
  } else {
    $args->{error_by_base} = pdl( $reverse_errors_less_n_count )/ pdl( $total_count );
  };

  return $self->_image_url( $args );
}

sub chart_legend {
  my ( $self ) = @_;

  my $args = {
    chart_legend => 1,
  };
  if ( defined $self->forward_n_count() ) {
    $args->{n_count} = 1;
  }
  if ( defined $self->forward_quality_bins() ) {
    $args->{high} = 1;
  }

  return $self->_image_url( $args );
}

sub chart_legend_cigar
{
	my $self = shift;
	my @legend;

	return if !$self->forward_cigar_char_count_by_cycle;

	my $chart_colour = $CIGAR_COLOUR;
	my $object_args = {
		cht_chart_type         => ['cht' , 'bvs'],
		chco_chart_colour      => ['chco', $chart_colour],
		encode                 => 0,
	};

	my $dia = npg_common::diagram::visio_histo_google->new( $object_args );
	foreach my $k (keys %{$self->forward_cigar_char_count_by_cycle}) {
	  if ( $k !~ /[HNP]/sxm ) {push @legend, $k;}
	}
    $dia->chdl_chart_legend( \@legend );
    return $dia->get_diagram_string(1);
}

sub google_charts_cigars {
	my $self = shift;
	return ($self->_image_url_cigar('forward', $self->forward_cigar_char_count_by_cycle),
	        $self->_image_url_cigar('reverse', $self->reverse_cigar_char_count_by_cycle),
	);
}

sub google_charts {
  my $self = shift;

  my $forward_url = $self->forward_google_chart();
  my $reverse_url;
  if ( defined $self->reverse_errors() ) {
    $reverse_url = $self->reverse_google_chart();
  }

  if ( ! $reverse_url ) {
    return ( $forward_url );
  }

  # A pair of charts need the same y max to be comparable

  my ( $f_chxr_start, $f_ymax ) = $forward_url =~ /(chxr.*?[|].*?,.*?,)(.*?),/xms;
  my ( $r_chxr_start, $r_ymax ) = $reverse_url =~ /(chxr.*?[|].*?,.*?,)(.*?),/xms;

  my $y_max = $f_ymax > $r_ymax ? $f_ymax
            :                     $r_ymax
            ;
  $forward_url = $self->forward_google_chart( { ymax => $y_max } );
  $reverse_url = $self->reverse_google_chart( { ymax => $y_max } );
  return ( $forward_url, $reverse_url );
}

sub _image_url_cigar {
	my $self = shift;
	my $title = shift;
	my $count_by_cycles = shift;

  my $chart_colour = $CIGAR_COLOUR;

  my $object_args = {
    cht_chart_type         => ['cht' , 'bvs'],
    chco_chart_colour      => ['chco', $chart_colour],
	encode                 => 0,
  };

	my $dia = npg_common::diagram::visio_histo_google->new( $object_args );

	my $data = [];
	my $xmax = 0;
	my $ymax = $self->sample_size;

    foreach my $k ( keys %{$count_by_cycles} ) {
		my $d = $count_by_cycles->{$k};
		if ($d) {
			my $x = scalar @{$d};
			$xmax = ($x > $xmax) ? $x : $xmax;
		}
	}

    my @required_keys = qw(I D M S); # in reverse order
    my $data_encountered = 0; # we can omit empty data series if no more data.
    foreach my $k (@required_keys) {
	if ((exists $count_by_cycles->{$k}) && (defined $count_by_cycles->{$k})) {
	    $data_encountered = 1;
	} elsif ($data_encountered) {
	    @{$count_by_cycles->{$k}} = ((0) x $xmax);
	}
    }

    foreach my $k ( keys %{$count_by_cycles} ) {
		if ($count_by_cycles->{$k}) {
		  if ( $k !~ /[HNP]/smx) {push @{$data}, $count_by_cycles->{$k};}
		}
    }

	$dia->y_max( $ymax );

	$dia->set_data($data);

	$ymax  = sprintf '%.2f', $ymax;
	$dia->set_axisY_min_max(0, $ymax);
	$dia->set_chart_title("$title cigar count by cycles");
	$dia->set_chart_size($xmax * ($BAR_WIDTH + $BAR_DISTANCE) + $IMAGE_WIDTH_EXTRA, $IMAGE_HEIGHT);

	$dia->set_chart_labels(0, $xmax, $CIGAR_X_DELTA, $MIN_Y, $ymax, $CIGAR_Y_DELTA);

	$dia->set_bar_size($BAR_WIDTH,$BAR_DISTANCE);
	return $dia->get_diagram_string();
}

sub _image_url {  ## no critic (Subroutines::ProhibitExcessComplexity)
  my ($self, $args) = @_;

  my $error_by_base = $args->{error_by_base};
  my $fastq         = $args->{fastq};
  my $ymax          = $args->{ymax};
  my $n_count       = $args->{n_count};
  my $high          = $args->{high};
  my $mid           = $args->{mid};
  my $low           = $args->{low};

  my $getdim;
  eval {
    $getdim = defined $high ? $high->getdim(0)
            :                 $error_by_base->getdim(0);
  } or do {};

  if ( ! ( $getdim || $args->{chart_legend} ) ) {
    return;
  }

  my $chart_colour =   defined $high    ? $BY_PERCENT_COLOUR
                   : ! defined $n_count ? $UNDEF_N_COUNT_COLOUR
                   :                      $DEF_N_COUNT_COLOUR
                   ;

  my $object_args = {
    cht_chart_type         => ['cht' , 'bvs'],
    chco_chart_colour      => ['chco', $chart_colour],
  };

  if ( ! ( $ENV{dev} && (uc $ENV{dev} eq q{TEST}))) {
    $object_args->{encode} = 1;
  }

  if ( defined $ymax ) {
    $object_args->{y_max} = $ymax;
  }

  my $dia = npg_common::diagram::visio_histo_google->new( $object_args );

  if ( $args->{chart_legend} ) {
    my $legend;

    # there will only be one data set if we don't have either high or n_count,
    # so no need for a legend
    if ( ! ( $args->{high} || $args->{n_count} ) ) {
      return;
    }

    # legend values need some quantifiers for human reading
    if ( $args->{high} ) {
      $legend = [ @{ $self->quality_bin_values() } ];
      $legend->[0] = q{>=} . $legend->[0];
      foreach my $i ( 1..( scalar @{ $legend } - 1 ) ) {
        $legend->[$i] = q{=<} . $legend->[$i];
      }
    }

    # if the only separation is N's and other bases, then say this
    if ( ! $legend ) {
      $legend = [ q{A/C/G/T} ];
    }
    # the last part of the legend needs to be an N base
    push @{$legend}, q{N};
    $dia->chdl_chart_legend( $legend );

    return $dia->get_diagram_string(1);
  }

  my $data = [];
  my $number_of_bars;
  if ( defined $high ) {
    foreach my $set ( qw{high mid low} ) {
      push @{ $data }, [map{sprintf '%.2f', $_} list($args->{$set} * $PERCENT)];
    }
    if ( defined $n_count ) {
      push @{ $data }, [map{sprintf '%.2f', $_} list($n_count * $PERCENT)];
    }
    $number_of_bars = scalar @{ $data->[0] };
  } else {
    $data = [map{sprintf '%.2f', $_} list($error_by_base * $PERCENT)];
    $number_of_bars = scalar @{ $data };
    if ( defined $n_count ) {
      $data = [ $data, [map{sprintf '%.2f', $_} list($n_count * $PERCENT)] ];
    }
  }

  if ( ! defined $ymax ) {
    if ( defined $high ) {
      $ymax = (pdl( $high ) + pdl( $mid ) + pdl( $low ))->maximum * $PERCENT;
      if ( defined $n_count ) {
        $ymax = (pdl( $high ) + pdl( $mid ) + pdl( $low ) + pdl( $n_count ))->maximum * $PERCENT;
      }
    } else {
      $ymax = $error_by_base->maximum * $PERCENT;
      if ( defined $n_count ) {
        $ymax = (pdl( $error_by_base ) + pdl( $n_count ))->maximum * $PERCENT;
      }
    }
    $dia->y_max( $ymax );
  }

  $dia->set_data($data);

  $ymax  = sprintf '%.2f', $ymax;

  $dia->set_axisY_min_max(0, $ymax);

  $dia->set_chart_title(qq[Mismatch percent by cycle, $fastq]);

  $dia->set_chart_size($number_of_bars * ($BAR_WIDTH + $BAR_DISTANCE) + $IMAGE_WIDTH_EXTRA, $IMAGE_HEIGHT);

  my $xmax = $getdim;

  my $x_delta = ($xmax) /($NUM_XAXIS_POINTS - 1);
  $x_delta = int $x_delta;
  my $y_delta = 0;

  $dia->set_chart_labels(0, $xmax, $x_delta, $MIN_Y, $ymax, $y_delta);
  $dia->set_bar_size($BAR_WIDTH,$BAR_DISTANCE);
  return $dia->get_diagram_string();
}

sub criterion {
  my $self = shift;
  if ($self->forward_common_cigars && $self->forward_common_cigars->[0]->[0]) {
    return q[Most common cigar (alignment pattern) does not indicate insertions or deletions];
  }
  return;
}

no Moose;

1;

__END__


=head1 NAME

    npg_qc::autoqc::role::sequence_error

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SUBROUTINES/METHODS

=head2 check_name - human readable check name

=head2 forward_average_percent_error - forware average percentage of error across all cycle

=head2 reverse_average_percent_error - reverse average percentage of error across all cycles

=head2 _image_url - return a google url of error by cycle plot

=head2 forward_google_chart

=head2 reverse_google_chart

=head2 google_charts - returns an array with URLs for error plots for the forward and reverse read. The plots have the same dimentions and scale both in X and Y direction.

=head2 chart_legend

produces a google chart url which will represent just a legend based on the data in the JSON/db for this set.

=head2 criterion
=head2 chart_legend_cigar
=head2 google_charts_cigars
=head2 _image_url_cigar

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Readonly

=item npg_common::diagram::visio_histo_google

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Author: Guoying Qi E<lt>gq1@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Guoying Qi

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

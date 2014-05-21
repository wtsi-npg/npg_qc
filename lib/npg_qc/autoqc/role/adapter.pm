#########
# Author:        John O'Brien and Marina Gourtovaia
# Maintainer:    $Author: mg8 $
# Created:       14 April 2009
# Last Modified: $Date: 2013-03-20 09:55:43 +0000 (Wed, 20 Mar 2013) $
# Id:            $Id: adapter.pm 16861 2013-03-20 09:55:43Z mg8 $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/autoqc/role/adapter.pm $
#

package npg_qc::autoqc::role::adapter;

use strict;
use warnings;
use Moose::Role;
use Readonly;
use List::Util qw(max);

use npg_common::diagram::visio_histo_google;

with qw(npg_qc::autoqc::role::result);

our $VERSION = '0';

Readonly::Scalar our $PERCENT              => 100;
Readonly::Scalar our $IMAGE_WIDTH_EXTRA    => 45;
Readonly::Scalar our $BAR_WIDTH            => 4;
Readonly::Scalar our $BAR_DISTANCE         => 1;
Readonly::Scalar our $IMAGE_HIGHT          => 200;
Readonly::Scalar our $MIN_IMAGE_WIDTH      => 260;
Readonly::Scalar our $NUM_XAXIS_POINTS     => 9;
Readonly::Scalar our $TEN     => 10;

sub forward_percent_contam_reads {
    my $self = shift;
    if (!defined $self->forward_fasta_read_count ||
            !defined $self->forward_contaminated_read_count ||
            $self->forward_fasta_read_count == 0) {
        return;
    }
    return sprintf '%0.2f',
        $PERCENT
        * $self->forward_contaminated_read_count()
        / $self->forward_fasta_read_count();
}


sub reverse_percent_contam_reads {
    my $self = shift;
    if (!defined $self->reverse_fasta_read_count ||
            !defined $self->reverse_contaminated_read_count ||
            $self->reverse_fasta_read_count == 0) {
        return;
    }
    return sprintf '%0.2f',
        $PERCENT
        * $self->reverse_contaminated_read_count()
        / $self->reverse_fasta_read_count();
}

sub image_url {

  my ($self, $read) = @_;
  my $method = $read . q[_start_counts];
  my $frequencies = $self->$method;
  if (!$frequencies) { return q[]; }

  my @cycles = sort { $a <=> $b } keys %{$frequencies};
  my $num_cycles = scalar @cycles;
  if (!$num_cycles) { return q[]; }

  my $log_ten = log $TEN;

  my @data = ();
  foreach my $cycle (1 .. $num_cycles) {
      if (exists $frequencies->{$cycle}) {
          push @data, sprintf '%0.2f', (log $frequencies->{$cycle})/$log_ten;
      } else {
          push @data, 0;
      }
  }

  my $dia = npg_common::diagram::visio_histo_google->new();
  $dia->set_data(\@data);

  my $ymax = max @data;
  $ymax = (int $ymax) + 1;
  $dia->set_axisY_min_max(0, $ymax);

  $method = $read . q[_read_filename];
  $dia->set_chart_title(q[Adapter start count (log10 scale) vs|cycle for ] . $self->$method);
  my $width = $num_cycles * ($BAR_WIDTH + $BAR_DISTANCE) + $IMAGE_WIDTH_EXTRA;
  $width = $width > $MIN_IMAGE_WIDTH ? $width : $MIN_IMAGE_WIDTH;
  $dia->set_chart_size($width, $IMAGE_HIGHT);

  my $xmax = $num_cycles;
  my $x_delta =  int $xmax/($NUM_XAXIS_POINTS - 1);
  my $y_delta = 0;

  $dia->set_chart_labels(0, $xmax, $x_delta, 0, $ymax, $y_delta);
  $dia->set_bar_size($BAR_WIDTH,$BAR_DISTANCE);
  return $dia->get_diagram_string();
}

no Moose;

1;

__END__


=head1 NAME

    npg_qc::autoqc::role::adapter

=head1 VERSION

    $Revision: 16861 $

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SUBROUTINES/METHODS

=head2 forward_percent_contam_reads

=head2 reverse_percent_contam_reads

=head2 image_url
 my google_url = $obj->image_url(q[forward]);
 google_url = $obj->image_url(q[reverse]);

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Readonly

=item npg_common::diagram::visio_histo_google

=item List::Util

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Author: Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt> and John O'Brien E<lt>jo3@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by John O'Brien and Marina Gourtovaia

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

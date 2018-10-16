package npg_qc_viewer::Model::QualityHeatmap;

use Carp;
use Moose;
use namespace::autoclean;
use GD::Image;
use Math::Gradient;

use npg_common::fastqcheck;

BEGIN { extends 'Catalyst::Model' }

our $VERSION  = '0';
## no critic (Documentation::RequirePodAtEnd ProhibitParensWithBuiltins ProhibitMagicNumbers)

=head1 NAME

npg_qc_viewer::Model::QualityHeatmap

=head1 SYNOPSIS

=head1 DESCRIPTION

Catalyst model for rendering quality by cycle heatmaps at run time

=head1 SUBROUTINES/METHODS

=head2 legend

Returns a binary stream representing a PNG image with a legend for quality by cycle heatmaps

=cut
sub legend {
    my $self = shift;

    my $height = 240;
    my $width  = 60;
    my $im = GD::Image->new($width, $height);
    if (!$im) {
        croak q[Failed to create an image object];
    }

    my $colours = {};
    my $white = $im->colorAllocate(255,255,255);
    $im->transparent($white);
    my $black = $im->colorAllocate(0,0,0);
    my @hot_spots = ([0, 0, 0] ,[ 255, 0, 0 ], [ 255, 255, 0 ] , [0, 0, 255], [ 0, 255, 0 ]);

    my @gradient = Math::Gradient::multi_array_gradient(101, @hot_spots);

    my @colour_table = ();

    my $count = 0;
    foreach my $g (@gradient) {
       $colours->{$count} = $im->colorAllocate($g->[0], $g->[1], $g->[2]);
       push @colour_table, $count;
       $count++;
    }

    my $vshift = 2;
    my $hshift = 15;
    my $y1 = 10;
    my $x1 = 0;
    my $x2 = $x1 + $hshift;
    my $y2 = 0;

    $count = 0;

    foreach my $colour (@colour_table) {

        $y2 = $y1 + $vshift;
        $im->filledRectangle($x1,$y1,$x2,$y2, $colours->{$colour});

        if ($count % 10 == 0) {
           $im->string(GD::gdSmallFont, $x2+5, $y1-5, $count, $black);
        }

        $y1 = $y2;
        $count ++;
    }

    $im->stringUp(GD::gdSmallFont, $x2+25, int(($y1-10)/2)+20, q[Bases, %], $black);

    return $im->png;
}


=head2 data2image

Returns a binary stream representing a PNG image with the quality by cycle visualisation.

=cut
sub data2image { ##no critic (ProhibitExcessComplexity)
    my ($self, $content, $read) = @_;

    $content or croak 'Content is required';
    $read or croak 'Read is required';
    my $fq = npg_common::fastqcheck->new(file_content => $content);
    my $num_cycles = $fq->read_length;
    my $max_q = $fq->_max_threshold;
    my $total = $fq->total_pf_bases;

    if ($total == 0 || $num_cycles == 0  || $max_q == 0) {
        return q[];
    }

    my $shift = 5;

    my $width = $num_cycles * $shift + 60;
    if ($read && $read =~ /^tag/smx) {
        $width += 20;
    }
    my $height = 50 * $shift + 55;

    my $im = GD::Image->new($width, $height);
    if (!$im) {
        croak q[Failed to create an image object];
    }

    my $colours = {};
    my $white = $im->colorAllocate(255,255,255);
    $im->transparent($white);

    my $black = $im->colorAllocate(0,0,0);
    my @hot_spots = ([0, 0, 0] ,[ 255, 0, 0 ], [ 255, 255, 0 ] , [0, 0, 255], [ 0, 255, 0 ]);

    my @gradient = Math::Gradient::multi_array_gradient(101, @hot_spots);

    my @colour_table = ();

    my $count = 0;
    foreach my $g (@gradient) {
       $colours->{$count} = $im->colorAllocate($g->[0], $g->[1], $g->[2]);
       push @colour_table, $colours->{$count};
       $count++;
    }

    my @qs = ();
    for my $q ((1 ... 50)) {
        push @qs, $q;
    }

    my $y1 = 0;
    my $x1 = 40;
    my $x2 = 0;
    my $y2 = 0;

    my $cycle_count = 1;
    my $pct_total = $total / 100;
    while ($cycle_count <= $num_cycles) {
        $y1 = 10;
        $x2 = $x1 + $shift;
        my $values = $fq->qx_yield(\@qs, $cycle_count);
        my $quality = 50;
        while (scalar @{$values}) {
            if ($cycle_count == 1 && ($quality == 1 || ($quality > 1 && $quality % 5 == 0))) {
                 $im->string(GD::gdSmallFont, 25, $y1-5, $quality, $black);
	    }
            $y2 = $y1 + $shift;
            my $value = pop @{$values};
            $value = int ($value/$pct_total);
            $im->filledRectangle($x1,$y1,$x2,$y2, $colours->{$value});
            $y1 = $y2;
            $quality -= 1;
	}

        if ($cycle_count == 1 || $cycle_count % 5 == 0) {
           $im->string(GD::gdSmallFont, $x1, $y1+5, $cycle_count, $black);
	}
        $cycle_count++;
        $x1 = $x2;
    }

    my $xaxis_label = q[Cycle number];
    if ($read) {
        $xaxis_label .= qq[ ($read];
        if ($read !~ /^tag/smx) {
            $xaxis_label .= q[ read];
	}
	$xaxis_label .= q[)];
    }

    my $start_xaxis_label = (int $num_cycles*$shift/2) - 40;
    if ($start_xaxis_label < 0) { $start_xaxis_label = 0; }
    $im->string(GD::gdSmallFont, $start_xaxis_label, $y1+20, $xaxis_label, $black);

    $im->stringUp(GD::gdSmallFont, 5, $height/2, q[Quality], $black);

    return $im->png;
}

__PACKAGE__->meta->make_immutable;

1;

__END__


=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Carp

=item Moose

=item namespace::autoclean

=item GD::Image

=item Math::Gradient

=item Catalyst::Model

=item npg_common::fastqcheck

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018 Genome Research Ltd.

This file is part of NPG software.

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


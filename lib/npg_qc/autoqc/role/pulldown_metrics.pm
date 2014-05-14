#########
# Author:        Marina Gourtovaia
# Maintainer:    $Author: kl2 $
# Created:       May 2012
# Last Modified: $Date: 2014-02-06 14:59:16 +0000 (Thu, 06 Feb 2014) $
# Id:            $Id: pulldown_metrics.pm 18051 2014-02-06 14:59:16Z kl2 $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/autoqc/role/pulldown_metrics.pm $
#

package npg_qc::autoqc::role::pulldown_metrics;

use Moose::Role;
use Readonly;

with qw( npg_qc::autoqc::role::result );

our $VERSION    = do { my ($r) = q$Revision: 18051 $ =~ /(\d+)/smx; $r; };
## no critic (Documentation::RequirePodAtEnd)

Readonly::Scalar our $HUNDRED              => 100;

=head1 NAME

npg_qc::autoqc::role::pulldown_metrics

=head1 VERSION

$Revision: 18051 $

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SUBROUTINES/METHODS

=head2 criterion

 Pass/Fail criterion

=cut

sub criterion {
	my $self = shift;

	return q[Fail if on bait bases less than 20%];
}

=head2 bait_design_efficiency

 Target territory / bait territory. 1 == perfectly efficient, 0.5 = half of baited bases are not target. BAIT_DESIGN_EFFICIENCY in Picard metrics.

=cut

sub bait_design_efficiency {
    my $self = shift;
    if ($self->bait_territory && defined $self->target_territory) {
        return $self->target_territory/$self->bait_territory;
    }
    return;
}

=head2 unique_reads_percent

 unique_reads_num / total_reads_num,  PCT_PF_UQ_READS in Picard metrics.

=cut

sub unique_reads_percent {
    my $self = shift;
    if ($self->total_reads_num && defined $self->unique_reads_num) {
        return ($self->unique_reads_num / $self->total_reads_num) * $HUNDRED;
    }
    return;
}

=head2 unique_reads_aligned_percent
   
 unique_reads_aligned_num / total_reads_num

=cut

sub unique_reads_aligned_percent {
    my $self = shift;
    if ($self->total_reads_num && defined $self->unique_reads_aligned_num) {
        return ($self->unique_reads_aligned_num / $self->total_reads_num) * $HUNDRED;
    }
    return;
}

=head2 on_bait_reads_percent
   
 Picard metrics:
 PF_UQ_READS_ALIGNED_BAIT :      The number of PF unique reads that are aligned overlapping a bait by >= 1bp

=cut

sub on_bait_reads_percent {
    my $self = shift;

      if ($self->total_reads_num && defined $self->other_metrics->{PF_UQ_READS_ALIGNED_BAIT}) {
       return ($self->other_metrics->{PF_UQ_READS_ALIGNED_BAIT} / $self->total_reads_num) * $HUNDRED;
      }
    return;
}

=head2 near_bait_reads_percent


Picard metrics :
PF_UQ_READS_ALIGNED_NEAR_BAIT: The number of PF unique reads that dont overlap a bait but align within 250bp 
                                of a bait.

=cut

sub near_bait_reads_percent {
    my $self = shift;

    if ($self->total_reads_num && defined $self->other_metrics->{PF_UQ_READS_ALIGNED_NEAR_BAIT}) {
        return ($self->other_metrics->{PF_UQ_READS_ALIGNED_NEAR_BAIT} / $self->total_reads_num) * $HUNDRED;
    }
    return;
}

=head2 on_target_reads_percent

Picard metrics:
PF_UQ_READS_ALIGNED_TARGET:    The number of PF unique reads that are aligned overlapping a target by >= 1bp

=cut

sub on_target_reads_percent {
    my $self = shift;

    if ($self->total_reads_num && defined $self->other_metrics->{PF_UQ_READS_ALIGNED_TARGET}) {
        return ($self->other_metrics->{PF_UQ_READS_ALIGNED_TARGET} / $self->total_reads_num) * $HUNDRED;
    }
    return;
}

=head2 selected_bases_percent
   
 (on_bait_bases_num + near_bait_bases_num) / unique_bases_aligned_num PCT_SELECTED_BASES in Picard metrics.

=cut

sub selected_bases_percent {
    my $self= shift;
    if ($self->unique_bases_aligned_num && defined $self->on_bait_bases_num && defined $self->near_bait_bases_num) {
        return (($self->on_bait_bases_num + $self->near_bait_bases_num) / $self->unique_bases_aligned_num) * $HUNDRED;
    }
    return;
}

=head2 on_bait_bases_percent

The percentage of aligned, de-duped, on-bait bases out of the PF bases available. PCT_USABLE_BASES_ON_BAIT in Picard metrics

=cut

sub on_bait_bases_percent {
    my $self = shift;
    if($self->unique_bases_aligned_num && defined $self->on_bait_bases_num) {
        return ($self->on_bait_bases_num / $self->unique_bases_aligned_num) * $HUNDRED;
    }
    return;
}

=head2 near_bait_bases_percent

The percentage of aligned, de-duped, on-bait bases out of the PF bases available.

=cut

sub near_bait_bases_percent {
    my $self = shift;
    if($self->unique_bases_aligned_num && defined $self->near_bait_bases_num) {
        return ($self->near_bait_bases_num / $self->unique_bases_aligned_num) * $HUNDRED;
    }
    return;
}

=head2 off_bait_bases_percent

The percentage of aligned PF bases that mapped neither on or near a bait. PCT_OFF_BAIT in Picard metrics

=cut

sub off_bait_bases_percent {
    my $self = shift;
    if ($self->unique_bases_aligned_num && defined $self->selected_bases_percent) {
        return $HUNDRED - $self->selected_bases_percent;
    }
    return;
}

=head2 on_bait_vs_selected_percent 

ON_BAIT_VS_SELECTED in Picard metrics

=cut

sub  on_bait_vs_selected_percent {
    my $self = shift;
    if (defined $self->on_bait_bases_num && defined $self->near_bait_bases_num) {
        my $selected = $self->on_bait_bases_num + $self->near_bait_bases_num;
        if ($selected) {
            return ($self->on_bait_bases_num / $selected) * $HUNDRED;
        }
    }
    return;
}

=head2 on_target_bases_percent

The percentage of aligned, de-duped, on-target bases out of the PF bases available. PCT_USABLE_BASES_ON_TARGET in Picard metrics

=cut

sub on_target_bases_percent {
    my $self = shift;
    if ($self->unique_bases_aligned_num && defined $self->on_target_bases_num) {
        return ($self->on_target_bases_num / $self->unique_bases_aligned_num) * $HUNDRED;
    }
    return;
}

=head2 zero_coverage_targets_percent

The percentage of targets that did not reach coverage=2 over any base.

=cut

sub zero_coverage_targets_percent {
    my $self = shift;
    if (defined $self->zero_coverage_targets_fraction) {
        return $self->zero_coverage_targets_fraction * $HUNDRED;
    }
    return;
}

=head2 target_bases_coverage_percent

=cut

sub target_bases_coverage_percent {
    my $self = shift;
    my $tbc = {};
    if ($self->other_metrics) {
        my @keys = keys %{$self->other_metrics};
        @keys = grep {/^PCT_TARGET_BASES/smx} @keys;
        foreach my $key (@keys) {
	    my ($coverage) = $key =~ /_(\d+)X/smx;
            $tbc->{$coverage} = $self->other_metrics->{$key} * $HUNDRED;
        }
    }
    return $tbc;
}

=head2 bait_bases_coverage_percent

Various increments between PCT_BAIT_BASES_1X and PCT_BAIT_BASES_1000X
to be stored in npgqc pulldown_metrics.other_metrics

Represents the fraction of bait bases with a depth of >= Nx

PCT_BAIT_BASES_2X
PCT_BAIT_BASES_10X
PCT_BAIT_BASES_20X
PCT_BAIT_BASES_30X

=cut

sub bait_bases_coverage_percent {
    my $self = shift;
    my $bbc = {};
    if ($self->other_metrics) {
        my @keys = keys %{$self->other_metrics};
        @keys = grep {/^PCT_BAIT_BASES/smx} @keys;
        foreach my $key (@keys) {
            # e.g. PCT_BAIT_BASES_30X
            # multiply by a 100 as is not already a percentage, despite the name
            my ($coverage) = $key =~ /_(\d+)X/smx;
            $bbc->{$coverage} = $self->other_metrics->{$key} * $HUNDRED;
        }
    }


    return $bbc;
}


=head2 hs_penalty

=cut

sub hs_penalty {
    my $self = shift;
    my $penalty = {};
    if ($self->other_metrics) {
        my @keys = keys %{$self->other_metrics};
        @keys = grep {/^HS_PENALTY/smx} @keys;
        foreach my $key (@keys) {
	    my ($coverage) = $key =~ /_(\d+)X/smx;
            $penalty->{$coverage} = $self->other_metrics->{$key};
        }
    }
    return $penalty;
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

Author: Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2012 GRL, by Marina Gourtovaia

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

package npg_qc::autoqc::role::pulldown_metrics;

use Moose::Role;
use Readonly;

our $VERSION = '0';
## no critic (Documentation::RequirePodAtEnd)

Readonly::Scalar our $HUNDRED => 100;

=head1 NAME

npg_qc::autoqc::role::pulldown_metrics

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SUBROUTINES/METHODS

=head2 criterion

 Pass/Fail criterion

=cut

sub criterion {
    return q[Fail if on bait bases less than 20%];
}

=head2 bait_design_efficiency

 Picard metrics BAIT_DESIGN_EFFICIENCY: target territory / bait territory.
 1 == perfectly efficient, 0.5 = half of baited bases are not target.

=cut

sub bait_design_efficiency {
    my $self = shift;
    if ($self->bait_territory && defined $self->target_territory) {
        return $self->target_territory / $self->bait_territory;
    }
    return;
}

=head2 unique_reads_percent

 Picard metrics PCT_PF_UQ_READS: unique_reads_num / total_reads_num

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
        return ($self->unique_reads_aligned_num /
                $self->total_reads_num) * $HUNDRED;
    }
    return;
}

=head2 on_bait_reads_percent

 Picard metrics PF_UQ_READS_ALIGNED_BAIT:
 The number of PF unique reads that are aligned overlapping a bait by >= 1bp

=cut

sub on_bait_reads_percent {
    my $self = shift;

    if (defined $self->other_metrics && $self->total_reads_num &&
        defined $self->other_metrics->{PF_UQ_READS_ALIGNED_BAIT}) {
        return ($self->other_metrics->{PF_UQ_READS_ALIGNED_BAIT} /
                $self->total_reads_num) * $HUNDRED;
    }
    return;
}

=head2 near_bait_reads_percent

 Picard metrics PF_UQ_READS_ALIGNED_NEAR_BAIT:
 The number of PF unique reads that dont overlap a bait but align within 250bp
 of a bait.

=cut

sub near_bait_reads_percent {
    my $self = shift;

    if (defined $self->other_metrics && $self->total_reads_num &&
        defined $self->other_metrics->{PF_UQ_READS_ALIGNED_NEAR_BAIT}) {
        return ($self->other_metrics->{PF_UQ_READS_ALIGNED_NEAR_BAIT} /
                $self->total_reads_num) * $HUNDRED;
    }
    return;
}

=head2 on_target_reads_percent

 Picard metrics PF_UQ_READS_ALIGNED_TARGET:
 The number of PF unique reads that are aligned overlapping a target by >= 1bp

=cut

sub on_target_reads_percent {
    my $self = shift;

    if (defined $self->other_metrics && $self->total_reads_num &&
        defined $self->other_metrics->{PF_UQ_READS_ALIGNED_TARGET}) {
        return ($self->other_metrics->{PF_UQ_READS_ALIGNED_TARGET} /
                $self->total_reads_num) * $HUNDRED;
    }
    return;
}

=head2 selected_bases_percent

 (on_bait_bases_num + near_bait_bases_num) / [PF_BASES, PCT_SELECTED_BASES]
 in Picard metrics.

=cut

sub selected_bases_percent {
    my $self= shift;
    if ($self->picard_version_base_count && defined $self->on_bait_bases_num &&
        defined $self->near_bait_bases_num) {
        return (($self->on_bait_bases_num + $self->near_bait_bases_num) /
                 $self->picard_version_base_count) * $HUNDRED;
    }
    return;
}

=head2 on_bait_bases_percent

 The percentage of aligned, de-duped, on-bait bases out of the PF bases
 available. PCT_USABLE_BASES_ON_BAIT in Picard metrics

=cut

sub on_bait_bases_percent {
    my $self = shift;
    if($self->picard_version_base_count && defined $self->on_bait_bases_num) {
        return ($self->on_bait_bases_num /
                $self->picard_version_base_count) * $HUNDRED;
    }
    return;
}

=head2 near_bait_bases_percent

 The percentage of aligned, de-duped, on-bait bases out of the PF bases
 available.

=cut

sub near_bait_bases_percent {
    my $self = shift;
    if($self->picard_version_base_count && defined $self->near_bait_bases_num) {
        return ($self->near_bait_bases_num /
                $self->picard_version_base_count) * $HUNDRED;
    }
    return;
}

=head2 off_bait_bases_percent

 The percentage of aligned PF bases that mapped neither on or near a bait.
 PCT_OFF_BAIT in Picard metrics

=cut

sub off_bait_bases_percent {
    my $self = shift;
    if (defined $self->selected_bases_percent) {
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

 The percentage of aligned, de-duped, on-target bases out of the PF bases
 available. PCT_USABLE_BASES_ON_TARGET in Picard metrics

=cut

sub on_target_bases_percent {
    my $self = shift;
    if ($self->picard_version_base_count && defined $self->on_target_bases_num) {
        return ($self->on_target_bases_num /
                $self->picard_version_base_count) * $HUNDRED;
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
    if (defined $self->other_metrics) {
        my @keys = grep {/^PCT_TARGET_BASES/smx} keys %{$self->other_metrics};
        foreach my $key (@keys) {
            my ($coverage) = $key =~ /_(\d+)X/smx;
            $tbc->{$coverage} = $self->other_metrics->{$key} * $HUNDRED;
        }
    }
    return $tbc;
}

=head2 bait_bases_coverage_percent

Various increments between PCT_BAIT_BASES_1X and PCT_BAIT_BASES_1000X
Represents the fraction of bait bases with a depth of >= Nx

PCT_BAIT_BASES_2X
PCT_BAIT_BASES_10X
PCT_BAIT_BASES_20X
PCT_BAIT_BASES_30X

=cut

sub bait_bases_coverage_percent {
    my $self = shift;
    my $bbc = {};
    if (defined $self->other_metrics) {
        my @keys = grep {/^PCT_BAIT_BASES/smx} keys %{$self->other_metrics};
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
    if (defined $self->other_metrics) {
        my @keys = grep {/^HS_PENALTY/smx} keys %{$self->other_metrics};
        foreach my $key (@keys) {
        my ($coverage) = $key =~ /_(\d+)X/smx;
            $penalty->{$coverage} = $self->other_metrics->{$key};
        }
    }
    return $penalty;
}

=head2 picard_version_base_count

Backward compatibility for older QC values, this method returns a suitable
total base count for determining percentages, by the presence or absence of
the PF_BASES key in the data.

Older Picard versions counted duplicates in the PCT_SELECTED_BASES count. In
later versions bundled with GATK the PCT_SELECTED_BASES stopped including the
duplicates. In order to calculate the same metrics we must use the value of
PF_BASES instead.

=cut

sub picard_version_base_count {
    my $self = shift;
    return
        (defined $self->other_metrics && exists $self->other_metrics->{PF_BASES})
        ? $self->other_metrics->{PF_BASES} : $self->unique_bases_aligned_num;
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

Copyright (C) 2016, 2021 Genome Research Ltd.

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

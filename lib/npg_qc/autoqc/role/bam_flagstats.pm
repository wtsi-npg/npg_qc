package npg_qc::autoqc::role::bam_flagstats;

use Moose::Role;
use Readonly;

our $VERSION = '0';

Readonly::Scalar my $PERCENTAGE   => 100;
Readonly::Scalar my $TWO_PLACES   => 2;
Readonly::Scalar my $FACTOR_TEN   => 10;
Readonly::Scalar my $GIGABASE     => 1_000_000_000;

sub total_reads {
  my $self = shift;
  if ( defined $self->num_total_reads() ) {
    return $self->num_total_reads();
  } elsif (defined $self->unpaired_mapped_reads &&
           defined $self->paired_mapped_reads &&
           defined  $self->unmapped_reads) {
    return ( $self->unpaired_mapped_reads + 2 * $self->paired_mapped_reads +
             $self->unmapped_reads );
  }
  return;
}

sub total_mapped_reads {
  my $self = shift;
  if (defined $self->unpaired_mapped_reads && defined $self->paired_mapped_reads) {
     return $self->unpaired_mapped_reads + 2 * $self->paired_mapped_reads;
  }
  return;
}

sub total_duplicate_reads {
   my $self = shift;
   if (defined $self->unpaired_read_duplicates && defined $self->paired_read_duplicates ) {
     return $self->unpaired_read_duplicates + 2 * $self->paired_read_duplicates;
   }
   return;
}

sub percent_mapped_reads {
  my $self = shift;
  if ($self->total_reads && defined $self->total_mapped_reads) {
    return $PERCENTAGE * $self->total_mapped_reads / $self->total_reads;
  }
  return;
}

sub percent_duplicate_reads {
  my $self = shift;
  if ($self->total_mapped_reads && defined $self->total_duplicate_reads) {
    return $PERCENTAGE * $self->total_duplicate_reads / $self->total_mapped_reads;
  }
  return;
}

sub percent_properly_paired {
   my $self = shift;
   if ($self->total_reads && defined $self->proper_mapped_pair) {
     return $PERCENTAGE * $self->proper_mapped_pair / $self->total_reads;
   }
   return;
}

sub percent_singletons {
   my $self = shift;
   if ($self->total_reads && defined $self->unpaired_mapped_reads) {
     return $PERCENTAGE * $self->unpaired_mapped_reads / $self->total_reads;
   }
   return;
}

sub percent_target_proper_pair_mapped_reads {
  my $self = shift;
  if ($self->target_mapped_reads && defined $self->target_proper_pair_mapped_reads) {
    return $PERCENTAGE * $self->target_proper_pair_mapped_reads / $self->target_mapped_reads;
  }
  return;
}

sub target_mean_coverage {
  my $self = shift;
  if (defined $self->target_mapped_bases && $self->target_length) {
    return $self->target_mapped_bases / $self->target_length;
  }
  return;
}

sub target_mapped_bases_gb{
  my $self = shift;
  if (defined $self->target_mapped_bases) {
    my $factor = $FACTOR_TEN**$TWO_PLACES;
    return int(($self->target_mapped_bases/$GIGABASE) * $factor) / $factor;
  }
  return;
}

sub percent_target_autosome_proper_pair_mapped_reads {
  my $self = shift;
  if ($self->target_autosome_mapped_reads &&
      defined $self->target_autosome_proper_pair_mapped_reads) {
    return $PERCENTAGE *
        $self->target_autosome_proper_pair_mapped_reads / $self->target_autosome_mapped_reads;
  }
  return;
}

sub target_autosome_mean_coverage {
  my $self = shift;
  if (defined $self->target_autosome_mapped_bases && $self->target_autosome_length) {
    return $self->target_autosome_mapped_bases / $self->target_autosome_length;
  }
  return;
}

no Moose;

1;

__END__

=head1 NAME

    npg_qc::autoqc::role::bam_flagstats

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 percent_duplicate_reads

=head2 percent_mapped_reads

=head2 percent_properly_paired

=head2 percent_singletons

=head2 percent_target_autosome_proper_pair_mapped_reads

=head2 percent_target_proper_pair_mapped_reads

=head2 target_autosome_mean_coverage

=head2 target_mean_coverage

=head2 total_duplicate_reads

=head2 target_mapped_bases_gb

=head2 total_mapped_reads

=head2 total_reads

=head2 check_name

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Readonly

=item npg_qc::autoqc::role::result

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Guoying Qi E<lt>gq1@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014,2015,2016,2018,2019,2020 Genome Research Ltd.

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

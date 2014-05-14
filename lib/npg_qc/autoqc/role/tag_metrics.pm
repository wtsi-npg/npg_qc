#########
# Author:        Marina Gourtovaia
# Maintainer:    $Author: mg8 $
# Created:       26 October 2011
# Last Modified: $Date: 2012-07-23 11:22:17 +0100 (Mon, 23 Jul 2012) $
# Id:            $Id: tag_metrics.pm 15913 2012-07-23 10:22:17Z mg8 $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/autoqc/role/tag_metrics.pm $
#

package npg_qc::autoqc::role::tag_metrics;

use strict;
use warnings;
use Carp;
use Moose::Role;
use PDL::Lite;
use PDL::Core qw(pdl);

with qw(npg_qc::autoqc::role::result);

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 15913 $ =~ /(\d+)/smx; $r; };

Readonly::Scalar  my $ONE_TENTH => 0.1;
Readonly::Scalar  my $HUNDRED   => 100;

sub _total_reads_count {
  my ($self, $attr) = @_;
  my $total = 0;
  foreach my $tag_index (keys %{$self->$attr}) {
    my $value = $self->$attr->{$tag_index};
    if ($value) {
      $total += $value;
    }
  }
  return $total;
}

sub all_reads {
  my ($self) = @_;
  return $self->_total_reads_count(q[reads_pf_count]);
}

sub all_reads_percent {
  my ($self) = @_;
  return $HUNDRED;
}

sub perfect_matches {
  my ($self) = @_;
  return $self->_total_reads_count(q[perfect_matches_pf_count]);
}

sub perfect_matches_percent {
  my ($self) = @_;
  my $total = $self->all_reads();
  my $value = !$total ? 0 :($self->perfect_matches() * $HUNDRED) / $total ;
  return $value;
}

sub one_mismatch {
  my ($self) = @_;
  return $self->_total_reads_count(q[one_mismatch_matches_pf_count]);
}

sub one_mismatch_percent {
  my ($self) = @_;
  my $total = $self->all_reads();
  my $value = !$total ? 0 : ($self->one_mismatch() * $HUNDRED) / $total;
  return $value;
}

sub errors {
  my ($self) = @_;
  return exists $self->reads_pf_count->{0} ? $self->reads_pf_count->{0} :
    $self->all_reads() - ($self->perfect_matches() + $self->one_mismatch());
}

sub errors_percent {
  my ($self) = @_;
  my $total = $self->all_reads();
  my $value = !$total ? 0 : ($self->errors() * $HUNDRED) / $total;
  return $value;
}

sub sorted_tag_indices {
  my $self = shift;

  my @removed = ();
  my @tags  = ();
  foreach my $i (keys %{$self->tags}) {
    if ($i == 0 || ($self->spiked_control_index && $i == $self->spiked_control_index)) {
      push @removed, $i;
    } else {
      push @tags, $i;
    }
  }
  @tags = sort { $a <=> $b } @tags;
  if (@removed) {
    ## no critic (BuiltinFunctions::ProhibitReverseSortBlock)
    push @tags, sort {$b <=> $a } @removed;
  }
  return @tags;
}

sub underrepresented_tags {
  my $self = shift;

  my $total = 0;
  my $num_indices;
  foreach my $i (keys %{$self->reads_pf_count}) {
    if($i == 0 || ($self->spiked_control_index && $i == $self->spiked_control_index)) {
      next;
    }
    my $value = $self->reads_pf_count->{$i};
    if ($value) {
      $total += $value;
    }
    $num_indices++;
  }
  my $u = {};

  if ($total && $num_indices && $total >= $num_indices) {
    my $expected_average = $total / $num_indices;
    foreach my $i (keys %{$self->reads_pf_count}) {
      if($i == 0 || ($self->spiked_control_index && $i == $self->spiked_control_index)) {
        next;
      }
      if (defined $self->reads_pf_count->{$i} && $self->reads_pf_count->{$i} / $expected_average < $ONE_TENTH) {
        $u->{$i} = 1;
      }
    }
  }
  return $u;
}

sub variance_coeff {
  my ($self, $all_matches ) = @_;

  my @values = ();
  foreach my $key (keys %{$self->tags}) {
    if ($key != 0 && (!defined $self->spiked_control_index || $key != $self->spiked_control_index)) {
      if (exists $self->perfect_matches_count->{$key}) {
        my $value = $self->perfect_matches_count->{$key};
        if ($all_matches) {
	  $value += $self->one_mismatch_matches_pf_count->{$key};
        }
        push @values, $value;
      }
    }
  }
  if (!@values) { return; }
  my $p = (pdl \@values);
  my ($mean,$prms,$median,$min,$max,$adev,$rms) = PDL::Primitive::stats($p);
  if ($mean->sclr == 0) {
    return 0;
  }
  my $cv = $rms/$mean * $HUNDRED;
  return $cv->sclr;
}

no Moose;

1;

__END__


=head1 NAME

 npg_qc::autoqc::role::tag_metrics

=head1 VERSION

 $Revision: 15913 $

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 	all_reads

=head2 	all_reads_percent

=head2 	errors

=head2 	errors_percent

=head2 	one_mismatch

=head2 	one_mismatch_percent

=head2 	perfect_matches

=head2 	perfect_matches_percent

=head2 	sorted_tag_indices

=head2 	underrepresented_tags

=head2 	variance_coeff

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item npg_qc::autoqc::results::result

=item npg_qc::autoqc::role::barcode_metrics

=item PDL::Lite

=item PDL::Core qw(pdl)

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Author: Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt><gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2011 GRL, by Marina Gourtovaia

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

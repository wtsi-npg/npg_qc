package npg_qc::autoqc::role::bcfstats;

use Moose::Role;
use Readonly;

our $VERSION = '0';

Readonly::Scalar our $HUNDRED => 100;

sub percent_condordance {
  my $self = shift;

  my $concordance;
  if ($self->genotypes_compared) {
    $concordance = sprintf '%.2f', ($self->genotypes_concordant * $HUNDRED)/$self->genotypes_compared;
  }
  return $concordance;
}

sub percent_nrd {
  my $self = shift;

  my $nrd;
  if ($self->genotypes_nrd_divisor) {
    $nrd = sprintf '%.2f', ($self->genotypes_nrd_dividend * $HUNDRED)/$self->genotypes_nrd_divisor;
  }
  return $nrd;
}

sub criterion {
  my $self = shift;

  if ($self->info && $self->info->{'Criterion'}) {
    return $self->info->{'Criterion'};
  }
  return;
}

no Moose;

1;

__END__


=head1 NAME

  npg_qc::autoqc::role::bcfstats

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 percent_condordance

 Extract the percentage of compared sites which are concordant

=head2 percent_nrd

 Extract the percentage non ref discordant

=head2 criterion

 Pass/Fail criterion

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

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018 GRL

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


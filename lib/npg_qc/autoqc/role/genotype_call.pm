package npg_qc::autoqc::role::genotype_call;

use Moose::Role;

our $VERSION = '0';


sub genotype_call_rate {
  my $self = shift;
  my $rate;
  if( $self->genotypes_attempted && $self->genotypes_called ){
    $rate = sprintf '%.3f', $self->genotypes_called/$self->genotypes_attempted;
  }elsif( $self->genotypes_attempted ){
    $rate = 0;
  }
  return $rate;
}

sub genotype_passed_rate {
  my $self = shift;
  my $rate;
  if( $self->genotypes_attempted && $self->genotypes_passed ){
    $rate = sprintf '%.3f', $self->genotypes_passed/$self->genotypes_attempted;
  }elsif( $self->genotypes_attempted ){
    $rate = 0;
  }
  return $rate;
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

    npg_qc::autoqc::role::genotype_call

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 genotype_call_rate

 Extract the genotypes called rate.

=head2 genotype_passed_rate

 Extract the genotypes called and passed rate.

=head2 criterion

 Extract the criteria for a pass.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2017 GRL

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

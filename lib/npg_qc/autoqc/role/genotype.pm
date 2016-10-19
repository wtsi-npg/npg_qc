package npg_qc::autoqc::role::genotype;

use Moose::Role;
use URI::Escape;

our $VERSION = '0';

sub criterion {
  my $self = shift;
  my $c = q[];
  if($self->expected_sample_name and $self->search_parameters) {
    my $min_common_snps = $self->search_parameters->{'min_common_snps'};
    my $poss_dup_level  = $self->search_parameters->{'poss_dup_level'};
    if ($min_common_snps and $poss_dup_level) {
      my $sn = $self->expected_sample_name;
      $c = qq[Sample name is $sn, number of common SNPs >= $min_common_snps ] .
           qq[and percentage of loosely matched calls > $poss_dup_level] .
            q[% (fail: < 50%)];
    }
  }
  return $c;
}

sub check_name_local {
  my ($self, $name) = @_;
  if($self->snp_call_set) {
    $name = join q{ }, $name, $self->snp_call_set;
  }
  return $name;
}

no Moose;

1;

__END__

=head1 NAME

    npg_qc::autoqc::role::genotype

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 criterion

 Pass/Fail criterion

=head2 check_name_local

 The name of the check modified to include the SNP call set

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item URI::Escape

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Kevin Lewis E<lt>kl2@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2016 GRL

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

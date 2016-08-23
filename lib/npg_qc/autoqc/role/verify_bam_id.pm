package npg_qc::autoqc::role::verify_bam_id;

use Moose::Role;

our $VERSION = '0';

#Fallback string for versions up to v61.1
Readonly::Scalar my $INITIAL_CRITERION =>
  q[snps > 10000, average depth >= 4 and freemix < 0.05];

sub criterion {
  my $self = shift;

  if ($self->info && $self->info->{'Criterion'}) {
    return $self->info->{'Criterion'};
  } else {
    return $INITIAL_CRITERION;
  }
}

no Moose;

1;

__END__


=head1 NAME

  npg_qc::autoqc::role::verify_bam_id

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 criterion

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

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

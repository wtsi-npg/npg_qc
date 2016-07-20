package npg_qc::autoqc::role::sequence_error;

use Moose::Role;
use PDL::Lite;
use PDL::Core qw(pdl);
use PDL::Primitive qw(stats);
use Readonly;

our $VERSION = '0';

Readonly::Scalar our $PERCENT               => 100;

sub forward_average_percent_error {
  my $self = shift;

  my $total_count = $self->forward_count();
  if(!$total_count || ( scalar @{$total_count} == 0 ) ){
    $total_count = $self->forward_aligned_read_count;
  }

  my $error_rate_by_cycle = pdl($self->forward_errors||[])/ pdl( $total_count );
  return _average_percent($error_rate_by_cycle);
}

sub reverse_average_percent_error {
  my $self = shift;

  my $total_count = $self->reverse_count();
  if(!$total_count || ( scalar @{$total_count} == 0 ) ){
    $total_count = $self->reverse_aligned_read_count;
  }

  my $error_rate_by_cycle = pdl($self->reverse_errors||[])/ pdl( $total_count );
  return _average_percent($error_rate_by_cycle);
}

sub _average_percent{
  my $error_rate_by_cycle = shift;
  return sprintf '%.2f',(stats($error_rate_by_cycle))[0]*$PERCENT;
}

sub criterion {
  my $self = shift;
  if ($self->forward_common_cigars && $self->forward_common_cigars->[0]->[0]) {
    return q[Most common cigar (alignment pattern) does not indicate insertions or deletions];
  }
  return;
}

sub subset {
  my $self = shift;
  return $self->sequence_type;
}

sub check_name_local {
  my ($self, $name) = @_;
  $name =~ s{^sequence_error}{sequence mismatch}smx;
  return $name;
}

sub reference_for_title {
  my $self      = shift;
  my $result    = {};

  if ( $self->reference ) {
    my ( $species, $version ) = ( $self->reference =~ /references\/ ([^\/]+) \/ ([^\/]+)/xms );
    $result->{'species'} = $species;
    $result->{'version'} = $version;
  }

  return $result;
}

no Moose;

1;

__END__


=head1 NAME

    npg_qc::autoqc::role::sequence_error

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 check_name_local - check name modifier

=head2 subset - returns the value of the sequence_type attribute

=head2 forward_average_percent_error - forware average percentage of error across all cycle

=head2 reverse_average_percent_error - reverse average percentage of error across all cycles

=head2 criterion

=head2 reference_for_title - Trimmed version of the reference so it can be 
used in a view. Returns a hash reference with keys for species and version.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Readonly

=item PDL::Lite

=item PDL::Core

=item PDL::Primitive

=item npg_qc::autoqc::role::result

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Guoying Qi E<lt>gq1@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2016 Genome Research Ltd

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

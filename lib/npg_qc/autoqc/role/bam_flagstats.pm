#########
# Author:        gq1
# Created:       21 June 2010
#

package npg_qc::autoqc::role::bam_flagstats;

use strict;
use warnings;
use Moose::Role;
use Carp;

with qw(npg_qc::autoqc::role::result);

use Readonly;
our $VERSION = '0';
Readonly::Scalar our $PERCENTAGE   =>100;

sub total_reads {
  my $self = shift;
  if( defined $self->num_total_reads() ) {
      return $self->num_total_reads();
  }elsif(defined $self->unpaired_mapped_reads && defined $self->paired_mapped_reads && defined  $self->unmapped_reads) {
      return ( $self->unpaired_mapped_reads + 2 * $self->paired_mapped_reads +  $self->unmapped_reads );
  }
  return;
}

sub total_mapped_reads {
  my $self = shift;
  if(defined $self->unpaired_mapped_reads && defined $self->paired_mapped_reads){
     return $self->unpaired_mapped_reads + 2 * $self->paired_mapped_reads;
  }
  return;
}

sub total_duplicate_reads {
   my $self = shift;
   if(defined $self->unpaired_read_duplicates && defined $self->paired_read_duplicates ){
     return $self->unpaired_read_duplicates + 2 * $self->paired_read_duplicates;
   }
   return;
}

sub percent_mapped_reads {
  my $self = shift;
  if($self->total_reads && defined $self->total_mapped_reads){
    return $PERCENTAGE * $self->total_mapped_reads / $self->total_reads;
  }
  return;
}

sub percent_duplicate_reads {
  my $self = shift;
  if($self->total_mapped_reads && defined $self->total_duplicate_reads){
    return $PERCENTAGE * $self->total_duplicate_reads / $self->total_mapped_reads;
  }
  return;
}

sub percent_properly_paired {
   my $self = shift;
   if($self->total_reads && defined $self->proper_mapped_pair){
     return $PERCENTAGE * $self->proper_mapped_pair / $self->total_reads;
   }
   return;
}

sub percent_singletons {
   my $self = shift;
   if($self->total_reads && defined $self->unpaired_mapped_reads){
     return $PERCENTAGE * $self->unpaired_mapped_reads / $self->total_reads;
   }
   return;
}

sub check_name {
  my $self = shift;

  my $ref = $self->class_name;
  $ref =~ s/_/ /gsmx;
  if ($self->human_split() && $self->human_split() ne 'all') {
    $ref .= q{ }.$self->human_split();
  }
  return $ref;
}
sub sequence_type {
  my $self = shift;
  if ($self->human_split() && $self->human_split() ne 'all') {
    return $self->human_split();
  }
  return q();
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

=head2 total_duplicate_reads

=head2 total_mapped_reads

=head2 total_reads

=head2 check_name

=head2 sequence_type

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item npg_qc::autoqc::role::result

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Author: Guoying Qi E<lt>gq1@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Guoying Qi

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

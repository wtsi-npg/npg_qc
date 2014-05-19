#########
# Author:        gq1
# Maintainer:    $Author: mg8 $
# Created:       21 June 2009
# Last Modified: $Date: 2014-03-12 09:06:00 +0000 (Wed, 12 Mar 2014) $
# Id:            $Id: bam_flagstats.pm 18173 2014-03-12 09:06:00Z mg8 $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/autoqc/results/bam_flagstats.pm $
#

package npg_qc::autoqc::results::bam_flagstats;

use strict;
use warnings;
use Moose;
use Carp;
use Perl6::Slurp;
use List::Util qw(sum);
use Readonly;

extends qw(npg_qc::autoqc::results::result);
with qw(npg_qc::autoqc::role::bam_flagstats);

our $VERSION = '0';

Readonly::Scalar our $METRICS_FIELD_LIST => [qw(library unpaired_mapped_reads paired_mapped_reads unmapped_reads  unpaired_read_duplicates paired_read_duplicates read_pair_optical_duplicates percent_duplicate library_size)];
Readonly::Scalar our $LIBRARY_SIZE_NOT_AVAILABLE => -1; # picard and biobambam mark duplicates assign this
                                                        # value for aligned data with no mapped paired reads

has '+path'                        => (
                                       required   => 0,
		                                );

has '+id_run'                      => (
                                       required   => 0,
		                                );

has '+position'                    => (
                                       required   => 0,
		                                );

has 'human_split'                  => (
                                       isa            => 'Maybe[Str]',
                                       is             => 'rw',
                                       default        => 'all',
		                                );

has 'library'                      => (
                                       isa            => 'Maybe[Str]',
                                       is             => 'rw',
		                                );

has 'num_total_reads'              => (
                                       isa            => 'Maybe[Int]',
                                       is             => 'rw',
		                                );

has 'unpaired_mapped_reads'        => (
                                       isa            => 'Maybe[Int]',
                                       is             => 'rw',
		                                );

has 'paired_mapped_reads'          => (
                                       isa            => 'Maybe[Int]',
                                       is             => 'rw',
		                               );

has 'unmapped_reads'               => (
                                       isa            => 'Maybe[Int]',
                                       is             => 'rw',
		                                );

has 'percent_duplicate'            => (
                                       isa            => 'Maybe[Num]',
                                       is             => 'rw',
		                                );

has 'unpaired_read_duplicates'     => (
                                       isa            => 'Maybe[Int]',
                                       is             => 'rw',
		                                );

has 'paired_read_duplicates'       => (
                                       isa            => 'Maybe[Int]',
                                       is             => 'rw',
		                                );

has 'read_pair_optical_duplicates' => (
                                       isa            => 'Maybe[Int]',
                                       is             => 'rw',
		                                );

has 'library_size'                 => (
                                       isa            => 'Maybe[Int]',
                                       is             => 'rw',
                                      );

has 'histogram'                    => (
                                       isa            => 'Maybe[HashRef]',
                                       is             => 'rw',
                                       default        => sub { {} },
                                      );

has 'proper_mapped_pair'           => (
                                       isa            => 'Maybe[Int]',
                                       is             => 'rw',
                                      );

has 'mate_mapped_defferent_chr'   =>  (
                                       isa            => 'Maybe[Int]',
                                       is             => 'rw',
                                      );

has 'mate_mapped_defferent_chr_5'  => (
                                       isa            => 'Maybe[Int]',
                                       is             => 'rw',
                                      );

has 'read_pairs_examined'          => (
                                       isa            => 'Maybe[Int]',
                                       is             => 'rw',
                                      );
sub parsing_metrics_file {
  my ($self, $matrics_file) = @_;

  my @file_contents = slurp ( $matrics_file, { irs => qr/\n\n/mxs } );

  my $header = $file_contents[0];
  chomp $header;
  $self->set_info('Picard_metrics_header', $header);

  my ($metrics_source) = $header =~ /(MarkDuplicates | EstimateLibraryComplexity | bammarkduplicates)/mxs;

  my $metrics = $file_contents[1];
  my $histogram  = $file_contents[2];

  my @metrics_lines = split /\n/mxs, $metrics;
  my @metrics_numbers = split /\t/mxs, $metrics_lines[2];

  if(scalar  @metrics_numbers > scalar @{$METRICS_FIELD_LIST} ){
     croak 'MarkDuplicate metrics format is wrong';
  }

  foreach my $field (@{$METRICS_FIELD_LIST}){
     my $field_value = shift @metrics_numbers;
     if($field_value) {
         if($field_value =~/\?/mxs){
            $field_value = undef;
	 } elsif ($field eq 'library_size' && $field_value < 0) {
	    if ($field_value == $LIBRARY_SIZE_NOT_AVAILABLE) {
               $field_value = undef;
	    } else {
               croak "Library size less than $LIBRARY_SIZE_NOT_AVAILABLE";
	    }
	 }
     }
     $self->$field( $field_value );
  }

  $self->read_pairs_examined( $self->paired_mapped_reads() );
  if($metrics_source eq 'EstimateLibraryComplexity'){
     $self->paired_mapped_reads(0)
  }

  if(!$histogram){
     return;
  }

  my @histogram_lines = split /\n/mxs, $histogram;
  my %histogram_hash = map { $_->[0] => $_->[1] } map{ [split /\s/mxs] } grep {/^[\d]/mxs } @histogram_lines;
  $self->histogram(\%histogram_hash);
  return;
}

sub parsing_flagstats {
   my ($self, $samtools_output_fh) = @_;

   while ( my $line = <$samtools_output_fh> ){

      chomp $line;
      my $number = sum $line =~ /^(\d+)\s*\+\s*(\d+)\b/mxs;

       ( $line =~ /properly\ paired/mxs )                                         ? $self->proper_mapped_pair($number)
      :( $line =~ /with\ mate\ mapped\ to\ a\ different\ chr$/mxs )               ? $self->mate_mapped_defferent_chr($number)
      :( $line =~ /with\ mate\ mapped\ to\ a\ different\ chr\ \(mapQ\>\=5\)/mxs ) ? $self->mate_mapped_defferent_chr_5($number)
      :( $line =~ /in\ total/mxs )                                               ? $self->num_total_reads($number)
      : next;
  }
  return;
}

no Moose;

1;

__END__


=head1 NAME

    npg_qc::autoqc::results::bam_flagstats

=head1 VERSION

    $Revision: 18173 $

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SUBROUTINES/METHODS

=head2 parsing_flagstats - parsing Picard MarkDuplicates metrics output file and save the result to the object

=head2 parsing_metrics_file - parsing samtools flagstats output file handler and save the result to the object

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item npg_qc::autoqc::results::result

=item npg_qc::autoqc::role::bam_flagstats

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Author: Guoying Qi E<lt>gq1@sanger.ac.ukE<gt><gt>

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

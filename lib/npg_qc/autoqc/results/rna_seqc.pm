#########
# Author:        Ruben Bautista
# Created:       2015-08-13
#

package npg_qc::autoqc::results::rna_seqc;

use Moose;
use namespace::autoclean;

extends qw(npg_qc::autoqc::results::result);

our $VERSION = '0';

=head1 NAME

npg_qc::autoqc::results::rna_seqc

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 rrna

 rRNA reads are non-duplicate and duplicate reads aligning to rRNA regions as defined in the transcript model definition.

=cut

has 'rrna' => (isa        => 'Maybe[Num]',
               is         => 'rw',
               required   => 0,);

=head2 rrna_rate

 Rate of rRNA per total reads.

=cut

has 'rrna_rate' => (isa        => 'Maybe[Num]',
                    is         => 'rw',
                    required   => 0,);

=head2 exonic_rate

 Fraction mapping within exons.

=cut

has 'exonic_rate' => (isa        => 'Maybe[Num]',
                      is         => 'rw',
                      required   => 0,);

=head2 expression_profiling_efficiency

 Ratio of exon reads to total reads.

=cut

has 'expression_profiling_efficiency' => (isa        => 'Maybe[Num]',
                                          is         => 'rw',
                                          required   => 0,);

=head2 genes_detected

 Number of Genes with at least 5 reads.

=cut
 
has 'genes_detected' => (isa        => 'Maybe[Num]',
                         is         => 'rw',
                         required   => 0,);

=head2 end_1_sense

 Number of End 1 reads that were sequenced in the sense direction.

=cut

has 'end_1_sense' => (isa        => 'Maybe[Num]',
                      is         => 'rw',
                      required   => 0,);

=head2 end_1_antisense

 Number of End 1 reads that were sequenced in the antisense direction.

=cut

has 'end_1_antisense' => (isa        => 'Maybe[Num]',
                          is         => 'rw',
                          required   => 0,);

=head2 end_2_sense

 Number of End 1 reads that were sequenced in the sense direction.

=cut

has 'end_2_sense' => (isa        => 'Maybe[Num]',
                      is         => 'rw',
                      required   => 0,);

=head2 end_2_antisense

 Number of End 2 reads that were sequenced in the antisense direction.

=cut

has 'end_2_antisense' => (isa        => 'Maybe[Num]',
                          is         => 'rw',
                          required   => 0,);

=head2 end_1_pct_sense

 Percentage of intragenic End 1 reads that were sequenced in the sense direction.

=cut

has 'end_1_pct_sense' => (isa        => 'Maybe[Num]',
                          is         => 'rw',
                          required   => 0,);

=head2 end_2_pct_sense

 Percentage of intragenic End 2 reads that were sequenced in the sense direction.

=cut

has 'end_2_pct_sense' => (isa        => 'Maybe[Num]',
                          is         => 'rw',
                          required   => 0,);

=head 2 mean_per_base_cov

 Mean Per Base Coverage of the middle 1000 expressed transcripts determined to have the highest expression levels.

=cut

has 'mean_per_base_cov' => (isa        => 'Maybe[Num]',
                             is         => 'rw',
                             required   => 0,);

=head 2 mean_cv

 Mean Coverage of the middle 1000 expressed transcripts determined to have the highest expression levels.

=cut

has 'mean_cv' => (isa        => 'Maybe[Num]',
                  is         => 'rw',
                  required   => 0,);

=head 2 end_5_norm

 Norm denotes that the end coverage is divided by the mean coverage for that transcript.

=cut

has 'end_5_norm' => (isa        => 'Maybe[Num]',
                     is         => 'rw',
                     required   => 0,);

=head 2 end_3_norm

 Norm denotes that the end coverage is divided by the mean coverage for that transcript.

=cut

has 'end_3_norm' => (isa        => 'Maybe[Num]',
                     is         => 'rw',
                     required   => 0,);

=head 2 end_5_norm

 All remaining RNA-SeQC metrics as a key-values pairs

=cut

has 'other_metrics'  => (isa        => 'HashRef',
                         is         => 'rw',
                         required   => 0,);

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

  npg_qc::autoqc::results::rna_seqc

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item npg_qc::autoqc::results::result

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Ruben E Bautista-Garcia<lt>rb11@sanger.ac.uk<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2016 Genome Research Limited

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

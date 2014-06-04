#########
# Author:        Marina Gourtovaia mg8@sanger.ac.uk
# Created:       2008-11-26
#
#

package npg_qc::autoqc::parse::alignment;

use Moose;
use Carp;
use English qw(-no_match_vars);
use Readonly;
use PDL::Lite;
use PDL::Core qw{pdl};
use Math::Round qw(round);

use npg_tracking::util::types;

our $VERSION = '0';
## no critic (Documentation::RequirePodAtEnd RequireNumberSeparators)

=head1 NAME

npg_qc::autoqc::parse::alignment

=head1 SYNOPSIS

=head1 DESCRIPTION

Parse the result of paired alignment to get insert size 

=head1 SUBROUTINES/METHODS

=cut

Readonly::Scalar our $ISIZE_SAM_POSITION             => 8;
Readonly::Scalar our $MAPPING_QUALITY_SAM_POSITION   => 4;
Readonly::Scalar our $BITWISE_FLAG_SAM_POSITION      => 1;
Readonly::Scalar our $PROPERLY_ALIGN_BIT_NUM         => 2;
Readonly::Scalar our $MIN_MAPPING_QUALITY            => 34;

Readonly::Scalar our $HUNDRED                        => 100;


=head2 files2parse

Forward run fastq file path

=cut
has 'files2parse'     => (isa             => 'ArrayRef[NpgTrackingReadableFile]',
                          is              => 'ro',
                          required        => 1,
                         );

=head2 generate_insert_sizes

Returns a reference to a list of insert sizes

=cut
sub generate_insert_sizes {
  my ($self, $result) = @_;

  my $file_type = $self->files2parse->[0] =~ /\.sam$/smx ? q[sam] : q[bam];
  my $method = join q[_], q[isizes_from], $file_type;
  my $actual_in_sizes = $self->$method($self->files2parse->[0]);
  my $actual_out_sizes = undef;
  if (scalar @{$self->files2parse} > 1 && $self->files2parse->[1]) {
    $actual_out_sizes = $self->$method($self->files2parse->[1]);
  }
  return $self->bin_insert_sizes($result, [$actual_in_sizes, $actual_out_sizes]);
}

=head2 bin_insert_sizes

Bins insert sizes and saves results to the result object

=cut
sub bin_insert_sizes {
  my ($self, $result, $isizes_arrays) = @_;

  if (!$isizes_arrays || !$result || !(ref $result))  { return; }

  my $in = 1;
  my $num_alt_aligned = defined $isizes_arrays->[1] ? scalar @{$isizes_arrays->[1]} : undef;
  my $num_in_aligned  = scalar @{$isizes_arrays->[0]};
  my $num_areads = $num_in_aligned;
  my @sizes = @{$isizes_arrays->[0]};
  if (defined $num_alt_aligned && $num_in_aligned < $num_alt_aligned) {
    $in = 0;
    @sizes = @{$isizes_arrays->[1]};
    $num_areads = $num_alt_aligned;
    $num_alt_aligned = $num_in_aligned;
  }
  $result->paired_reads_direction_in($in);
  $result->num_well_aligned_reads_opp_dir($num_alt_aligned);

  $result->num_well_aligned_reads($num_areads);
  if (!$num_areads) { return; }

  my $p = (pdl \@sizes)->qsort();
  my ($mean,$prms,$median,$min,$max,$adev,$rms) = PDL::Primitive::stats($p);

  ##no critic (ProhibitMagicNumbers)
  my $first  = int 0.25 * $num_areads;
  my $third  = int 0.75 * $num_areads;
  ##use critic
  $result->quartile1(PDL::at($p, $first));
  ##no critic (ProhibitParensWithBuiltins)
  $result->median(int(sclr $median));
  ##use critic
  $result->quartile3(PDL::at($p, $third));

  $max = PDL::at($p, $num_areads-1);
  my $step = int(($max - $min)/$HUNDRED) + 1;
  my $num_bins = int(($max - $min)/$step) + 1;
  my @h = PDL::histogram($p, $step, $min, $num_bins )->list();
  $result->min_isize(sclr $min);
  $result->bin_width($step);

  $result->mean(round(sclr $mean));
  $result->std(round(sclr $adev));

  $result->bins(\@h);

  return $num_areads;
}

=head2 isizes_from_sam

Parses sam file to generate insert sizes

=cut
sub isizes_from_sam {
  my ($self, $file) = @_;

  ## no critic (RequireBriefOpen)
  open my $fh, q[<], $file or croak $ERRNO;
  my $actual_sizes = [];
  while(<$fh>) {
    chomp;
    if ($_ =~ /^@/smx) { next; }
    my @values = split;
    my $bitwise_flag = $values[$BITWISE_FLAG_SAM_POSITION];
    my $insert_size = $values[$ISIZE_SAM_POSITION];
    if (($bitwise_flag & $PROPERLY_ALIGN_BIT_NUM) && $insert_size > 0) {
      push @{$actual_sizes}, $insert_size;
    }
  }
  close $fh or croak $ERRNO;
  return $actual_sizes;
}

=head2 isizes_from_bam

Parses bam file to generate insert sizes

=cut
sub isizes_from_bam {
  my ($self, $file) = @_;

  require Bio::DB::Sam;
  my $sam = Bio::DB::Sam->new(-bam => $file);
  my $bam = $sam->bam;
  my $actual_sizes = [];
  while (my $align = $bam->read1) {
    my $flag = $align->flag;
    my $isize = $align->isize;
    if ($isize && ($flag & $PROPERLY_ALIGN_BIT_NUM)) {
      push @{$actual_sizes}, $isize;
    }
  }
  return $actual_sizes;
}

no Moose;

1;
__END__


=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Carp

=item Readonly

=item Moose

=item Math::Round

=item PDL::Lite

=item npg_tracking::util::types

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Author: Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

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

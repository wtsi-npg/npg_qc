# Author:        Jennifer Liddle
# Created:       2014-02-06
#
#

package npg_qc::autoqc::checks::verify_bam_id;

use strict;
use warnings;
use Moose;
use Carp;
use File::Basename;
use Data::Dumper;
use npg_qc::autoqc::types;
use Readonly;
use FindBin qw($Bin);

extends qw(npg_qc::autoqc::checks::check);
with qw(npg_common::roles::software_location
        npg_tracking::data::snv::find);

our $VERSION = '0';

Readonly::Scalar my $VERIFY_NAME => q[verifyBamID];
Readonly::Scalar our $EXT => q[bam];
Readonly::Scalar my $MIN_SNPS => 10**4;
Readonly::Scalar my $MIN_AVG_DEPTH => 4;
Readonly::Scalar my $MIN_FREEMIX => 0.05;

has '+input_file_ext' => (default => $EXT,);

has 'alignments_in_bam'  => (
	is => 'ro',
	isa => 'Maybe[Bool]',
	lazy_build => 1,
);
sub _build_alignments_in_bam {
	my ($self) = @_;

	return $self->lims->alignments_in_bam;
}

has 'bam_file' => (
  is => 'ro',
  isa => 'Str',
  required => 0,
  lazy_build => 1,
);
sub _build_bam_file {
  my ($self) = @_;
  return $self->input_files->[0];
}

override 'can_run' => sub {
  my $self = shift;

  if ($self->lims->library_type && $self->lims->library_type =~ /(?:cD|R)NA/sxm) {
    $self->_cant_run_ms("library_type is $self->lims->library_type");
    return 0;
  }

  # make sure that the bam file is aligned and a reference genome is defined

  if(!$self->alignments_in_bam) {
    $self->result->add_comment('alignments_in_bam is false');
    return 0;
  }

  if(!defined($self->lims->reference_genome)) {
		$self->result->add_comment('No reference genome specified');
    return 0;
  }

  # we want to run iff there is a VCF file for this organism/strain/bait

  if (!$self->snv_file) {
    $self->result->add_comment(q(Can't find VCF file));
    return 0;
  }

  return 1;
};

override 'execute' => sub {
  my ($self) = @_;
  my $outfile = $self->tmp_path . q(/) . basename($self->bam_file);

  my $cmd_options =
        ' --bam ' . $self->bam_file
      . ' --vcf ' . $self->snv_file
      . ' --self --ignoreRG --minQ 20 --minAF 0.05 --maxDepth 500 --precise'
      . ' --out ' . $outfile;

  if ( !super() ) { return 1; }

  $self->result->set_info('Verifier', $VERIFY_NAME);
  $self->result->set_info('Verify_options', $cmd_options);
  my $cmd = "$VERIFY_NAME $cmd_options";

  if(!$self->can_run()) {
    $self->result->add_comment($self->_cant_run_ms);
    return 1;
  }

  if (system $cmd) {
    croak "Failed to execute $cmd";
  }

  open my $fh, q(<), $outfile.'.selfSM' or croak "Can't open $outfile.selfSM";
  my $line = <$fh>; # burn header line
  $line = <$fh>; my @result = split /\t/smx,$line;
  close $fh or croak "Can't close $outfile.selfSM";
  my $n = 2;
  $self->result->number_of_snps($result[++$n]);
  $self->result->number_of_reads($result[++$n]);
  $self->result->avg_depth($result[++$n]);
  $self->result->freemix($result[++$n]);
  $self->result->freeLK1($result[++$n]);
  $self->result->freeLK0($result[++$n]);
  $self->result->pass(undef);
  if ( ($self->result->number_of_snps > $MIN_SNPS) and ($self->result->avg_depth >= $MIN_AVG_DEPTH) ) {
    if ($self->result->freemix >= $MIN_FREEMIX) { $self->result->pass(0); }
    else                                        { $self->result->pass(1); }
  }
  return 1;
};

####################
# private attributes
####################

no Moose;
__PACKAGE__->meta->make_immutable();


1;

__END__


=head1 NAME

npg_qc::autoqc::checks::verify_bam_id - compare genotype from bam with Sequenom QC results

=head1 SYNOPSIS

    use npg_qc::autoqc::checks::verify_bam_id;

=head1 DESCRIPTION


=head1 SUBROUTINES/METHODS

=head2 new

    Moose-based.

=head1 DIAGNOSTICS

    None.

=head1 CONFIGURATION AND ENVIRONMENT

=head1 INCOMPATIBILITIES

    None known.

=head1 BUGS AND LIMITATIONS

=head1 DEPENDENCIES

=head1 AUTHOR

    Jennifer Liddle <js10@sanger.ac.uk>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014 GRL, by Jennifer Liddle

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

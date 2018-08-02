package npg_qc::autoqc::checks::bcfstats;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use File::Spec::Functions qw(catfile);
use Carp;
use JSON;
use Readonly;
use IO::All;
use Try::Tiny;
use List::Util qw(sum0);

extends qw(npg_qc::autoqc::checks::check);

with qw(npg_tracking::data::geno_refset::find
        npg_common::roles::software_location
        npg_qc::utils::genotype_calling);

our $VERSION = '0';

Readonly::Scalar my $DEFAULT_FAIL_NRD => 2;
Readonly::Scalar my $DEFAULT_CMD_SEP  => q[ ; ];
Readonly::Scalar my $VCF_HEADER       => q[CHROM];
Readonly::Scalar my $BCFSTATS_COLS    => 11;
Readonly::Scalar my $BCFSTATS_RESULTS => q[GCsS];
Readonly::Array  my @CALLING_METRICS  => qw[genotypes_attempted genotypes_called genotypes_passed];
Readonly::Scalar my $BCFSTATS_HEADER  => q[#-GCsS-[2]id-[3]sample-[4]non-reference-discordance-rate-[5]RR-Hom-matches-[6]RA-Het-matches-[7]AA-Hom-matches-[8]RR-Hom-mismatches-[9]RA-Het-mismatches-[10]AA-Hom-mismatches-[11]dosage-r-squared];

has '+file_type' => (default => 'cram',);

has 'alignments_in_bam'  => (
	is      => 'ro',
	isa     => 'Maybe[Bool]',
	lazy    => 1,
  builder => q[_build_alignments_in_bam],
);
sub _build_alignments_in_bam {
  my ($self) = @_;
  return $self->lims->alignments_in_bam;
}

has 'calling_metrics_fields' => (
  is       => q[ro],
  isa      => 'ArrayRef[Str]',
  default  => sub { \@CALLING_METRICS },
  init_arg => undef,
);

has 'fail_percent_nrd' => (
  is      => q[ro],
  isa     => q[Str],
  lazy    => 1,
  builder => q[_build_fail_percent_nrd],
);
sub _build_fail_percent_nrd{
  my ($self) = shift;
  return $self->genotype_info->{'fail_percent_nrd'} // $DEFAULT_FAIL_NRD;
}

has 'genotype_info' => (
  is       => q[ro],
  isa      => q[HashRef],
  lazy     => 1,
  builder  => q[_build_genotype_info],
  init_arg => undef,
);
sub _build_genotype_info {
  my ($self) = shift;
  my $info = {};
  if($self->geno_refset_info_path){
     $info = decode_json(io($self->geno_refset_info_path)->slurp);
  }
  return $info;
}

has 'annotation_path' => (
  is       => q[ro],
  isa      => q[Str | Undef],
  lazy     => 1,
  builder  => q[_build_annotation_path],
  init_arg => undef,
);
sub _build_annotation_path {
  my $self = shift;
  return $self->geno_refset_annotation_path;
}

has 'ploidy_path' => (
  is       => q[ro],
  isa      => q[Str | Undef],
  lazy     => 1,
  builder  => q[_build_ploidy_path],
  init_arg => undef,
);
sub _build_ploidy_path {
  my $self = shift;
  return $self->geno_refset_ploidy_path;
}

has 'bcfstats_outfile' => (
  is      => q[ro],
  isa     => q[Str],
  lazy    => 1,
  builder => q[_build_bcfstats_outfile],
);
sub _build_bcfstats_outfile {
  my ($self) = @_;
  return catfile($self->output_dir,
    $self->result->filename_root .q[.bcfstats])
}


override 'can_run' => sub {
  my $self = shift;

  if($self->lims->gbs_plex_name){
    $self->result->add_comment('bcfstats skipped for gbs libraries.');
    return 0;
  }

  if(!$self->annotation_path) {
    $self->result->add_comment('No geno refset annotation is found');
    return 0;
  }

  if(!$self->geno_refset_bcfdb_path) {
    $self->result->add_comment('No geno refset bcf db is found');
    return 0;
  }

  if(!$self->alignments_in_bam) {
     $self->messages->push('alignments_in_bam is false');
     return 0;
  }

  if (!$self->lims->sample_name) {
    $self->result->add_comment('Can only run on a single sample');
    return 0;
  }
  return 1;
};

override 'execute' => sub {
  my ($self) = @_;

  super();

  if(!$self->can_run()) {
    return 1;
  }

  $self->result->set_info('Caller',$self->bcftools);
  $self->result->geno_refset_name($self->geno_refset_name);
  $self->result->geno_refset_path($self->annotation_path);
  $self->result->expected_sample_name($self->expected_sample_name);
  $self->result->set_info('Criterion',q[NRD % < ]. $self->fail_percent_nrd);

  try {
    $self->run_calling;
    if ($self->_sample_id_refset_bcfdb) {
      $self->_run_comparison;
      (!$self->result->genotypes_nrd_divisor ||
       $self->result->percent_nrd < $self->fail_percent_nrd) ?
       $self->result->pass(1) : $self->result->pass(0);
    } else {
      $self->result->add_comment
          ('No bcfstats comparison as no refset genotypes exist.');
    }
    1;
  } catch {
    croak qq[ERROR running bcfstats : $_];
  };

  $self->result->add_comment(join q[ ], $self->messages->messages);

  return 1;
};


####################
# private attributes
####################

has '_vcftobcf_command' => (
  is       => q[ro],
  isa      => q[Str],
  lazy     => 1,
  builder  => q[_build_vcftobcf_command],
  init_arg => undef,
);
sub _build_vcftobcf_command {
  my ($self) = shift;
  return $self->bcftools . q[ view --output-file ]. $self->_temp_bcf
    .q[ --output-type b ] . $self->vcf_outfile;
}

has '_indexbcf_command' => (
  is       => q[ro],
  isa      => q[Str],
  lazy     => 1,
  builder  => q[_build_indexbcf_command],
  init_arg => undef,
);
sub _build_indexbcf_command {
  my ($self) = shift;
  return $self->bcftools . q[ index ]. $self->_temp_bcf;
}

has '_bcfstats_command' => (
  is       => q[ro],
  isa      => q[Str],
  lazy     => 1,
  builder  => q[_build_bcfstats_command],
  init_arg => undef,
);
sub _build_bcfstats_command {
  my ($self) = shift;
  my $bcfstats_cmd =
      $self->bcftools . q[ stats --verbose].
      q[ --collapse snps].
      q[ --apply-filters PASS].
      q[ --samples ]. $self->expected_sample_name.
      q[ ]. $self->geno_refset_bcfdb_path.
      q[ ]. $self->_temp_bcf;

  return $bcfstats_cmd;
}

has '_refset_header_command' => (
  is       => q[ro],
  isa      => q[Str],
  lazy     => 1,
  builder  => q[_build_refset_header_command],
  init_arg => undef,
);
sub _build_refset_header_command {
  my ($self) = shift;
  return $self->bcftools . q[ view ].
    q[ --header-only ].
    q[ --force-samples].
    q[ --samples ]. $self->expected_sample_name.
    q[ ]. $self->geno_refset_bcfdb_path;
}


has '_temp_bcf' => (
  is      => q[ro],
  isa     => q[Str],
  lazy    => 1,
  builder => q[_build_temp_bcf],
);
sub _build_temp_bcf {
  my ($self) = @_;
  return catfile($self->tmp_path(),
    $self->result->filename_root . q[.bcf]);
}

#####################
# private subroutines
#####################

sub _run_comparison {
  my $self = shift;

  my $bcfstats_cmd = $self->_generate_bcfstats_cmd;

  my $bcfstats_results;
  open my $f, q{-|}, qq{$bcfstats_cmd} or croak q[Failed to run bcfstats];
  while(<$f>){ $bcfstats_results .= $_ };
  close $f or croak q[Failed to close check];

  $self->write_output($self->bcfstats_outfile,$bcfstats_results);
  $self->_parse_bcfstats($bcfstats_results);

  return;
}

sub _sample_id_refset_bcfdb {
  my $self = shift;

  my $header;
  open my $f, q{-|}, $self->_refset_header_command or croak q[Failed to run header cmd];
  while(<$f>){ $header .= $_;};
  close $f or croak q[Failed to close header cmd];

  my @results =  grep { $_ =~ /^\#$VCF_HEADER/smx } split m/\n/smx , $header;
  if (@results != 1) { croak q[Unexpected number of vcf header lines]; }
  my @nline = split m/[\t]/smx, $results[0];
  return pop @nline eq $self->expected_sample_name;
}

sub _generate_bcfstats_cmd {
  my $self = shift;

  my $cmd = join $DEFAULT_CMD_SEP, $self->_vcftobcf_command,
      $self->_indexbcf_command, $self->_bcfstats_command;
  return $cmd;
}

sub _parse_bcfstats {
  my ($self,$bcfstats_results) = @_;

  my @nheader =  grep { $_ =~ /^\#\s$BCFSTATS_RESULTS\s/smx } split m/\n/smx , $bcfstats_results;
  $nheader[0] =~ s/\s+/\-/smxg;
  if (@nheader != 1 || $nheader[0] ne $BCFSTATS_HEADER) {
    croak q[Unexpected genotype concordance header line in bcfstats];
  }

  my @nresults =  grep { $_ =~ /^$BCFSTATS_RESULTS/smx } split m/\n/smx , $bcfstats_results;
  if (@nresults != 1) {
    croak q[Unexpected number of genotype concordance lines in bcfstats];
  }
  my @nline = split m/[\t]/smx, $nresults[0];
  if (scalar  @nline != $BCFSTATS_COLS) {
    croak  q[Unexpected number of genotype concordance fields in bcfstats results];
  }

  ##no critic (ProhibitMagicNumbers)
  $self->result->genotypes_compared(sum0 @nline[4..9]);
  $self->result->genotypes_concordant(sum0 @nline[4..6]);
  $self->result->genotypes_nrd_dividend(sum0 @nline[7..9]);
  $self->result->genotypes_nrd_divisor(sum0 @nline[5..9]);

  return;
}


__PACKAGE__->meta->make_immutable();

1;

__END__


=head1 NAME

    npg_qc::autoqc::checks::bcfstats

=head1 SYNOPSIS

    use npg_qc::autoqc::checks::bcfstats;

=head1 DESCRIPTION

    Call genotypes and run bcftools stats

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

=over

=item Moose

=item MooseX::StrictConstructor

=item namespace::autoclean

=item File::Spec::Functions

=item Carp

=item JSON

=item Readonly

=item IO::All

=item Try::Tiny

=item List::Util

=item npg_tracking::data::geno_refset::find

=item npg_common::roles::software_location

=item npg_qc::utils::genotype_common

=back

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


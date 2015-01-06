# Author:        Kevin Lewis
# Created:       2011-09-29
#
#

package npg_qc::autoqc::checks::genotype;

use strict;
use warnings;
use Moose;
use Carp;
use File::Basename;
use File::Spec::Functions qw(catfile catdir);
use List::MoreUtils qw { any };
use JSON;
use Data::Dumper;
use npg_qc::utils::bam_genotype;
use npg_qc::utils::iRODS;
use npg_qc::autoqc::types;
use Readonly;
use FindBin qw($Bin);

extends qw(npg_qc::autoqc::checks::check);
with qw(npg_tracking::data::reference::find
        npg_common::roles::software_location
       );

our $VERSION = '0';

Readonly::Scalar our $HUMAN_REFERENCES_DIR => q[Homo_sapiens];
Readonly::Scalar my $GENOTYPE_DATA => 'sgd';
Readonly::Scalar my $SAMTOOLS_NAME => q[samtools_irods];
Readonly::Scalar my $BCFTOOLS_NAME => q[bcftools];
Readonly::Scalar our $EXT => q[bam];
Readonly::Scalar my $SEQUENOM_QC_PLEX => q[W30467];
Readonly::Scalar my $DEFAULT_QC_PLEX => q[sequenom_fluidigm_combo];
Readonly::Scalar my $DEFAULT_SNP_CALL_SET => q[W30467];
Readonly::Scalar my $DEFAULT_MIN_COMMON_SNPS => 21;
Readonly::Scalar my $DEFAULT_RELIABLE_READ_DEPTH => 5;
Readonly::Scalar my $DEFAULT_POSS_DUP_LEVEL => 95;
Readonly::Scalar my $DEFAULT_MIN_SAMPLE_CALL_RATE => 95;
Readonly::Scalar my $MATCH_PASS_THRESHOLD => 0.95;
Readonly::Scalar my $MATCH_FAIL_THRESHOLD => 0.50;
Readonly::Scalar my $MAX_ALT_MATCHES => 4;

has '+input_file_ext' => (default => $EXT,);
has '+aligner'        => (default => 'fasta',);
has '+id_run' => (required => 0, );
has '+position' => (isa => 'Maybe[NpgTrackingLaneNumber]', required => 0, );

# Human references repository - look under this directory for human genome reference files
has 'human_references_repository' => (
	isa =>'NPG_TRACKING_REFERENCE_REPOSITORY',
	is => 'ro',
	lazy_build => 1,
);
sub _build_human_references_repository {
	my $self = shift;
	return catdir($self->ref_repository, $HUMAN_REFERENCES_DIR);
}

# you can override the executable name. May be useful for variants like "samtools_irods"
has 'samtools_name' => (
	is => 'ro',
	isa => 'Str',
	default => $SAMTOOLS_NAME,
);

has 'samtools' => (
        is => 'ro',
        isa => 'NpgCommonResolvedPathExecutable',
        lazy_build => 1,
        coerce => 1,
);
sub _build_samtools {
	my ($self) = @_;
	return $self->samtools_name;
}

# you can override the executable name. May be useful for variants like "samtools_irods"
has 'bcftools_name' => (
	is => 'ro',
	isa => 'Str',
	default => $BCFTOOLS_NAME,
);

has 'bcftools' => (
        is => 'ro',
        isa => 'NpgCommonResolvedPathExecutable',
        lazy_build => 1,
        coerce => 1,
);
sub _build_bcftools {
	my ($self) = @_;
	return $self->bcftools_name;
}

has 'genotype_executables_path' => (
	is => 'ro',
	isa => 'Str',
	default => sub { return $Bin },
);

# sequenom_plex - this specifies the source of the genotype data
has 'sequenom_plex' => (
	is => 'ro',
	isa => 'Str',
	default => $DEFAULT_QC_PLEX,
);

# snp_call_set - this specifies the set of loci to be called. This may be
#  the same for different sequenom_plex data sets. It is used to construct
#  the name of some information files (positions, alleles, etc)
has 'snp_call_set' => (
	is => 'ro',
	isa => 'Str',
	default => $DEFAULT_SNP_CALL_SET,
);

has 'aix_file' => (
	is => 'ro',
	isa => 'Str',
	lazy_build => 1,
);
sub _build_aix_file {
	my $self = shift;
	return $self->gt_db . q{.aix};
}

has 'gt_db' => (
	is => 'ro',
	isa => 'Str',
	lazy_build => 1,
);
sub _build_gt_db {
	my $self = shift;
	return catfile($self->genotypes_repository, $self->gt_db_base);
}

has 'gt_db_base' => (
	is => 'ro',
	isa => 'Str',
	lazy_build => 1,
);
sub _build_gt_db_base {
	my $self = shift;
	return sprintf q[%s_%s], $self->sequenom_plex, ${GENOTYPE_DATA};
}

has 'reliable_read_depth' => (
	is => 'ro',
	isa => 'NpgTrackingNonNegativeInt',
	default => $DEFAULT_RELIABLE_READ_DEPTH,
);

has 'poss_dup_level' => (
	is => 'ro',
	isa => 'NpgTrackingNonNegativeInt',
	default => $DEFAULT_POSS_DUP_LEVEL,
);

has 'min_sample_call_rate' => (
	is => 'ro',
	isa => 'NpgTrackingNonNegativeInt',
	default => $DEFAULT_MIN_SAMPLE_CALL_RATE,
);

has 'gt_pack_cmd' => (
	is => 'ro',
	isa => 'Str',
	lazy_build => 1,
);
sub _build_gt_pack_cmd {
	my ($self) = @_;
	return $self->genotype_executables_path() . q{/gt_pack};
}

has 'gt_pack_flags' => (
	is => 'ro',
	isa => 'Str',
	lazy_build => 1,
);
sub _build_gt_pack_flags {
	my ($self) = @_;

	return q{ -o - -s 1 -f 1 -P } . $self->aix_file() . q{ };
}

has 'gt_pack_args' => (
	is => 'ro',
	isa => 'Str',
	default => ' - ',
);

has 'find_gt_match_cmd' => (
	is => 'ro',
	isa => 'Str',
	lazy_build => 1,
);
sub _build_find_gt_match_cmd {
	my ($self) = @_;
	return $self->genotype_executables_path() . q{/find_gt_match};
}

has 'find_gt_match_flags' => (
	is => 'ro',
	isa => 'Str',
	lazy_build => 1,
);
sub _build_find_gt_match_flags {
	my ($self) = @_;
	return q{ -m } . $self->min_common_snps() . q{ -p -j -n "} . $self->sample_name . q{" -r } . $self->reliable_read_depth . q{ -d } . $self->poss_dup_level . q{ -s } . $self->min_sample_call_rate;
}

has 'find_gt_match_args' => (
	is => 'ro',
	isa => 'Str',
	lazy_build => 1,
);
sub _build_find_gt_match_args {
	my ($self) = @_;
	return q{ - } . $self->gt_db();
}

has 'min_common_snps' => (
	is => 'ro',
	isa => 'NpgTrackingNonNegativeInt',
	default => $DEFAULT_MIN_COMMON_SNPS,
);

has 'sample_name'  => (
	is => 'ro',
	isa => 'Maybe[Str]',
	lazy_build => 1,
);
sub _build_sample_name {
	my ($self) = @_;

	return $self->lims->sample_name;
}

has 'reference_fasta' => (
	is => 'ro',
	isa => 'Maybe[Str]',
	required => 0,
	lazy_build => 1,
);
sub _build_reference_fasta {
	my ($self) = @_;

	return $self->refs->[0];
}

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
	lazy_build => 1,
);
sub _build_bam_file {
	my ($self) = @_;
	return $self->input_files->[0];
}

has 'bam_file_md5' => (
	is => 'ro',
	isa => 'Str',
	lazy_build => 1,
);
sub _build_bam_file_md5 {
	my ($self) = @_;
	my $bam_file = $self->bam_file;
	my $md5 = q{};

	if($bam_file) {
		my $md5_file = "${bam_file}.md5";

		if(-r $md5_file) {
			open my $f, '<', $md5_file or croak "$md5_file readable, but open fails";

			$md5 = <$f>;

			close $f or croak "Failed to close $md5_file";
		}
	}

	return $md5;
}

has 'input_files_md5' => (
	is => 'ro',
	isa => 'Str',
	lazy_build => 1,
);
sub _build_input_files_md5 {
	my ($self) = @_;
	my $md5 = q{};
	Readonly::Scalar my $IRODS_PREFIX_LEN_IS_THIS_READABLE_ENOUGH => 6;

	my @md5_vals = ();
	for my $input_file (@{$self->input_files}) {
		if($input_file =~ /^irods:/smx) {
			my $irods_filename = substr $input_file, $IRODS_PREFIX_LEN_IS_THIS_READABLE_ENOUGH;  # strip leading "irods:"

			$md5 = npg_qc::utils::iRODS->new->get_file_md5($irods_filename);

			$md5 ||= '0000000000000000';

			push @md5_vals, $md5;
		}
		else {
			my $md5_file = "${input_file}.md5";

			$md5 = q{};
			if(-r $md5_file) {
				open my $f, '<', $md5_file or croak "$md5_file readable, but open fails";

				$md5 = <$f>;

				close $f or croak "Failed to close $md5_file";

			}
			$md5 ||= '0000000000000000';
			push @md5_vals, $md5;
		}

	}

	return join q[;], @md5_vals;
}

#####################################################################################################################
# pos_snpname_map_fn should be either specified at instantiation or implied by the Sequenom plex and reference genome
#####################################################################################################################
has 'pos_snpname_map_fn' => (
        is => 'ro',
        isa => 'NpgTrackingReadableFile',
	lazy_build => 1,
);
sub _build_pos_snpname_map_fn {
	my ($self) = @_;
	my $genotypes_repository = $self->genotypes_repository;
	my $human_references_repository = $self->human_references_repository;
	my $reference = $self->reference_fasta;
	my $ref_to_snppos_suffix_map = $self->_ref_to_snppos_suffix_map;

	my $chrconv_suffix = $ref_to_snppos_suffix_map->{$reference};

	if(!defined $reference || !defined $chrconv_suffix) {
		return;
	}

	my $fn = sprintf '%s_chrpos_snpname_map_%s.tsv', $self->snp_call_set, $chrconv_suffix;
	my $pos_snpname_map_fn = catfile($genotypes_repository, $fn);

	return $pos_snpname_map_fn;
}

##############################################################################################
# report_aux_data tells bam_genotype to include read depth and genotype likelihood information
##############################################################################################
has 'report_aux_data' => (
	is => 'ro',
	isa => 'Bool',
	default => 1,
);

has 'bam_genotype' => (
	is => 'ro',
	isa => 'npg_qc::utils::bam_genotype',
	handles => { tsv_genotype => 'genotype', json_genotype => 'json_genotype', },
	lazy_build => 1,
);
sub _build_bam_genotype {
	my ($self) = @_;

	my %bg_params = (sample_name => $self->sample_name, plex => $self->sequenom_plex, reference => $self->reference_fasta, pos_snpname_map_filename => $self->pos_snpname_map_fn, report_aux_data => $self->report_aux_data, samtools => $self->samtools, samtools_name => $self->samtools_name, bcftools => $self->bcftools, bcftools_name => $self->bcftools_name, );

	$bg_params{bam_file_list} = $self->input_files;

	return npg_qc::utils::bam_genotype->new(%bg_params);
}

override 'can_run' => sub {
	my $self = shift;

	# make sure that a sample name has been supplied and that the bam file is aligned with one of the recognised human references

	if(!defined $self->sample_name) {
		$self->_cant_run_ms('No sample name specified');
		return 0;
	}

	if(!$self->alignments_in_bam) {
		$self->_cant_run_ms('alignments_in_bam is false');
		return 0;
	}

	if(!defined($self->reference_fasta) || (! -r $self->reference_fasta)) {
		$self->_cant_run_ms('Reference genome missing or unreadable');
		return 0;
	}

	if(! any { $_ =~ $self->reference_fasta; } (keys %{$self->_ref_to_snppos_suffix_map})) {
		$self->_cant_run_ms('Specified reference genome may be non-human');
		return 0;
	}

	return 1;
};

override 'execute' => sub {
	my ($self) = @_;

	return 1 if super() == 0;

	if(!$self->can_run()) {
		$self->result->add_comment($self->_cant_run_ms);
		return 1;
	}

# run check
	my $gt_check_cmd = sprintf
			q{set -o pipefail && printf "%s" | %s %s %s | %s %s %s},
			$self->tsv_genotype,
			$self->gt_pack_cmd(),
			$self->gt_pack_flags(),
			$self->gt_pack_args,
			$self->find_gt_match_cmd(),
			$self->find_gt_match_flags(),
			$self->find_gt_match_args()
		;

	open my $f, q{-|}, qq{$gt_check_cmd} or croak 'Failed to execute check';

	my $json_results = <$f>;

	close $f or croak 'Failed to close check';

	if(!$json_results) {
		croak 'No results from check';
	}

	my $result = from_json($json_results);

	my $gt_caller_info = $self->current_version($self->samtools);
	$self->result->set_info('Caller', $self->samtools);
	$self->result->set_info('Caller_version', $gt_caller_info);

	$self->result->genotype_data_set($result->{genotype_data_set});

	$self->result->snp_call_set($self->snp_call_set);

	my $bam_file_leaves = join q[;], (map { basename($_); } @{$self->input_files});
	$self->result->bam_file($bam_file_leaves);    # name of result attribute should probably be changed to reflect the possibility of more than one bam file; check qc db

	$self->result->bam_file_md5($self->input_files_md5);

	my $reference_leaf = fileparse($self->reference_fasta);
	$self->result->reference($reference_leaf);

	$self->result->bam_call_count($self->json_genotype->{number_of_calls});

	my $bam_call_string = join q{}, map { $_->{call}; } @{$self->json_genotype->{calls}}{sort keys %{$self->json_genotype->{calls}}};
	$self->result->bam_call_string($bam_call_string);

	my $bam_gt_depths_string = join q{;}, map { defined $_->{depth}? $_->{depth}: q{0}; } @{$self->json_genotype->{calls}}{sort keys %{$self->json_genotype->{calls}}};
	$self->result->bam_gt_depths_string($bam_gt_depths_string);

	my $bam_gt_likelihood_string = join q{;}, map { defined $_->{gt_pl}? $_->{gt_pl}: q{0}; } @{$self->json_genotype->{calls}}{sort keys %{$self->json_genotype->{calls}}};
	$self->result->bam_gt_likelihood_string($bam_gt_likelihood_string);

	$self->result->expected_sample_name($self->sample_name);
	$self->result->search_parameters($result->{params});
	$self->result->sample_name_match((grep { $_->{match_type} eq 'SampleNameMatch'; } @{$result->{comp_results}})[0]);
	$self->result->sample_name_relaxed_match((grep { $_->{match_type} eq 'RM_SampleNameMatch'; } @{$result->{comp_results}})[0]);

	my @high_concordant_pos_dups = grep { $_->{match_type} eq 'HIGHconcordantPosDupDnaDiff' and $_->{matched_sample_name} ne $self->sample_name; } @{$result->{comp_results}};
	@high_concordant_pos_dups = reverse sort { $a->{match_pct} <=> $b->{match_pct}; } @high_concordant_pos_dups;
	my $top_idx;
	$top_idx = _cap_range(\@high_concordant_pos_dups, $MAX_ALT_MATCHES);
	if ($top_idx > 0) {
		@high_concordant_pos_dups = @high_concordant_pos_dups[0..$top_idx];
	}
	if(@high_concordant_pos_dups) {
		$self->result->alternate_matches([@high_concordant_pos_dups]);
	}

	$self->result->alternate_match_count(0);
	if(defined $self->result->alternate_matches) {
		$self->result->alternate_match_count(scalar @{$self->result->alternate_matches});
	}

	my @rm_high_concordant_pos_dups = grep { $_->{match_type} eq 'RM_HIGHconcordantPosDupDnaDiff' and $_->{matched_sample_name} ne $self->sample_name; } @{$result->{comp_results}};
	@rm_high_concordant_pos_dups = reverse sort { $a->{match_pct} <=> $b->{match_pct}; } @rm_high_concordant_pos_dups;
	$top_idx = _cap_range(\@rm_high_concordant_pos_dups, $MAX_ALT_MATCHES);
	if($top_idx > 0) {
		@rm_high_concordant_pos_dups = @rm_high_concordant_pos_dups[0..$top_idx];
	}
	if(@rm_high_concordant_pos_dups) {
		$self->result->alternate_relaxed_matches([@rm_high_concordant_pos_dups]);
	}

	$self->result->alternate_relaxed_match_count(0);
	if(defined $self->result->alternate_relaxed_matches) {
		$self->result->alternate_relaxed_match_count(scalar @{$self->result->alternate_relaxed_matches()});
	}

	if(defined $self->result->sample_name_relaxed_match and $self->result->sample_name_relaxed_match->{common_snp_count} >= $DEFAULT_MIN_COMMON_SNPS) {
		if($self->result->sample_name_relaxed_match->{match_pct} > $MATCH_PASS_THRESHOLD) {
			$self->result->pass(1);
		}
		elsif($self->result->sample_name_relaxed_match->{match_pct} < $MATCH_FAIL_THRESHOLD) {
			$self->result->pass(0);
		}
	}

	return 1;
};

sub _cap_range {
	my ($arr_ref, $max_value) = @_;
	my $top_value;

	$top_value = $#{$arr_ref};
	if($top_value >= $max_value) {
		$top_value = $max_value - 1;
	}

	return $top_value;
}

####################
# private attributes
####################

###############################################################################################################
# For each recognised human reference, _ref_to_snppos_suffix hashref indicates the chromosome naming convention
# with a value of either 'GRCh37' (meaning chr1, chr2, ...) or '1000Genomes' (meaning 1, 2, 3)
###############################################################################################################
has '_ref_to_snppos_suffix_map' => (
	isa => 'HashRef',
	is => 'ro',
	lazy_build => 1,
);
sub _build__ref_to_snppos_suffix_map {
	my ($self) = @_;
	my $human_references_repository = $self->human_references_repository;
	Readonly::Scalar my $NO_CHR_SUFFIX => '1000Genomes';
	Readonly::Scalar my $USE_CHR_SUFFIX => 'GRCh37';

	my $ref_to_snppos_suffix_map = {
		"$human_references_repository/1000Genomes/all/fasta/human_g1k_v37.fasta" => $NO_CHR_SUFFIX,
		"$human_references_repository/1000Genomes_hs37d5/all/fasta/hs37d5.fa" => $NO_CHR_SUFFIX,
		"$human_references_repository/CGP_GRCh37.NCBI.allchr_MT/all/fasta/Homo_sapiens.GRCh37.NCBI.allchr_MT.fa" => $NO_CHR_SUFFIX,
		"$human_references_repository/GRCh37_53/all/fasta/Homo_sapiens.GRCh37.dna.all.fa" => $USE_CHR_SUFFIX,
		"$human_references_repository/NCBI36/all/fasta/Homo_sapiens.NCBI36.48.dna.all.fa" => $NO_CHR_SUFFIX,
	};

	return $ref_to_snppos_suffix_map;
}

no Moose;
__PACKAGE__->meta->make_immutable();


1;

__END__


=head1 NAME

npg_qc::autoqc::checks::genotype - compare genotype from bam with Sequenom QC results

=head1 SYNOPSIS

    use npg_qc::autoqc::checks::genotype;

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

    Kevin Lewis, kl2

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2011 GRL, by Kevin Lewis

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

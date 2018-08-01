# Author:        Kevin Lewis
# Created:       2011-12-07
#
#

package npg_qc::utils::bam_genotype;

use strict;

use Carp;
use File::Basename;
use File::Spec::Functions qw(catfile catdir);
use JSON;
use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use Moose::Util::TypeConstraints;
use Readonly;

use npg_common::roles::software_location;

our $VERSION = '0';

##no critic
Readonly::Scalar my $SAMTOOLS_NAME => 'samtools';
Readonly::Scalar my $BCFTOOLS_NAME => 'bcftools';

subtype '_bamgt_ReadableFile'
      => as Str
      => where { -f $_ and -r $_ };

subtype '_bamgt_Dir'
      => as Str
      => where { -d $_ };

subtype '_bamgt_Executable'
      => as Str
      => where { -f $_ and -x $_ };

#############################
# "public" attributes/methods
#############################

has 'sample_name' => (
	is => 'ro',
	isa => 'Str',
	required => 0,
);

has 'reference' => (
	is => 'ro',
	isa => '_bamgt_ReadableFile',
	required => 1,
);

has 'plex' => (
	is => 'ro',
	isa => 'Str',
	required => 1,
);

has 'bam_file_list' => (
	is => 'ro',
	isa => 'ArrayRef',
        lazy_build => 1,
);
sub _build_bam_file_list {
	my $self = shift;

	if($self->bam_file) {
		carp q[specified bam_file added to bam_file_list, but use of attribute bam_file is deprecated];
		return [ $self->bam_file ];
	}

	croak q[Attribute bam_file_list required, or attribute bam_file must be specified (deprecated)];
}

has 'bam_file' => (
	is => 'ro',
	isa => 'Str',
	required => 0,
);

has 'pos_snpname_map_filename' => (
	is => 'ro',
	isa => '_bamgt_ReadableFile',
	required => 1,
);

has 'report_aux_data' => (
	is => 'ro',
	isa => 'Bool',
	default => 0,
);

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

has 'genotype' => (
        is => 'ro',
        isa => 'Str',
        lazy_build => 1,
);
sub _build_genotype {
        my ($self) = @_;
	my $f;
	my $gt = '';
	my $sample_name = $self->sample_name;

	$sample_name ||= "NO_SN";

	my $json_genotype = $self->json_genotype;

	#####################################################################################################################
	# convert the JSON data into tab-delimited format (where report_aux_dat is true, call data is CALL:DEPTH:LIKELIHOODS)
	# e.g.:
	# SampleName   rs111   rs222    ...
	# FOO_STDY01    AT:21:128,0,97    GG:32:0,121,150
	#####################################################################################################################
	my @assays = sort keys %{$json_genotype->{calls}};
	$gt .= sprintf "SampleName\t%s\n", join("\t", @assays);
	$gt .= $sample_name;
	for my $assay (@assays) {
		my $call_data = '';
		my $elem = $json_genotype->{calls}->{$assay};
		if($self->report_aux_data) {
			$call_data = join(":", ($elem->{'call'}, (defined $elem->{'depth'}? $elem->{'depth'}:'0'), (defined $elem->{'gt_pl'}? $elem->{'gt_pl'}:'0')));
		}
		else {
			$call_data = $elem->{'call'};
		}
		$gt .= "\t$call_data";
	}
	$gt .= "\n";

	return $gt;
}

has 'json_genotype' => (
        is => 'ro',
        isa => 'HashRef',
        lazy_build => 1,
);
sub _build_json_genotype {
        my ($self) = @_;
	my ($f, %calls, $json_genotype);
	my $pos_snpname_map = $self->_pos_snpname_map;	# maps positions to SNP names
	my $call_gt_cmd = $self->_call_gt_cmd;

	for my $chrpos (keys %$pos_snpname_map) { $calls{$pos_snpname_map->{$chrpos}}->{call} = 'NN'; }	# initialise all calls to 'NN'

	open $f, q{-|}, $call_gt_cmd or croak "Failed to open filter";
	while(<$f>) {
		next if(/^#/);

		my ($chrom, $pos, $ref, $alt, $info, $call_data_format, $call_data) = (split)[0,1,3,4,7,8,9];

		next if($info =~ /indel/i);
		my @alleles=($ref, (split(",", $alt)));
		my %h;
		@h{(split(':', $call_data_format))} = (split(':', $call_data)); # parse call_data (genotype results) fields
		my @gt=(0,0);   # default genotype (homozygote reference)
		my $pl = '0';   # default likelihood (for homozygote reference)
		if(defined $h{'GT'}) {
			@gt = (split('/', $h{'GT'})); # here, call should be either '0/1' (het) or '1/1' (hom non-ref) - if call was '0/0' (hom ref), there should be no 'GT'
			$pl = $h{'PL'};         # likelihoods in order homozgote reference, heterozygote, homozgote non-reference
		}

		my $depth;
		if($self->report_aux_data) {
			$info =~ /DP=(\d+)/;
			$depth = $1;
			$depth ||= 0;
		}

		my $key = "$chrom $pos";

		my $snp_name = $pos_snpname_map->{$key};

		next unless($snp_name);

		$calls{$snp_name}->{call} = join("", @alleles[@gt]);
		if($self->report_aux_data) {
			$calls{$snp_name}->{depth} = ${depth};
			$calls{$snp_name}->{gt_pl} = $pl;
		}
	}
	close($f) or croak 'Error calling genotype from bam file';

	$json_genotype->{bam} = $self->bam_file_list->[0];
	$json_genotype->{reference} = $self->reference;
	$json_genotype->{number_of_calls} = grep { $_->{call} ne 'NN'; } (values %calls);
	$json_genotype->{calls} = \%calls;

	return $json_genotype;
}

##############################
# "private" attributes/methods
##############################

has '_psd' => (
        is => 'ro',
        isa => 'ArrayRef',
        lazy_build => 1,
);
sub _build__psd {
        my ($self) = @_;
	my ($f);
	my $psmfn = $self->pos_snpname_map_filename;

	open $f, "$psmfn" or croak "Failed to open pos_snpname_map file $psmfn";
	my @psd = (<$f>);
	close $f;
	chomp @psd;

	return \@psd;
}

has '_pos_list' => (
        is => 'ro',
        isa => 'ArrayRef',
        lazy_build => 1,
);
sub _build__pos_list {
        my ($self) = @_;

	my @poslist = map { (split "\t")[0]; } @{$self->_psd};    # preserve order in file

	return \@poslist;
}

has '_pos_snpname_map' => (
        is => 'ro',
        isa => 'HashRef',
        lazy_build => 1,
);
sub _build__pos_snpname_map {
        my ($self) = @_;
	my $psd = $self->_psd;

	my %pos_snpname_map = map { (split("\t"));  } @$psd;

	return \%pos_snpname_map;
}

has '_regions_string' => (
        is => 'ro',
        isa => 'Str',
        lazy_build => 1,
);
sub _build__regions_string {
        my ($self) = @_;

	my $regions_string = join(' ', (map { my ($chr, $pos)= (split); sprintf "%s:%d-%d", $chr, $pos, $pos+1; } @{$self->_pos_list}));

	return $regions_string;
}

# _call_gt_cmd is not of type '_bamgt_Executable' because it isn't just a simple command
has '_call_gt_cmd' => (
        is => 'ro',
        isa => 'Str',
        lazy_build => 1,
);
sub _build__call_gt_cmd {
        my ($self) = @_;
	my $cmd;
	my $bam_file_list = $self->bam_file_list;

	if(@{$bam_file_list} == 1) {
		$cmd = sprintf q{bash -c 'set -o pipefail && %s view -b %s %s 2>/dev/null}, $self->samtools, $bam_file_list->[0], $self->_regions_string;
	}
	else {
		$cmd = sprintf q{bash -c 'set -o pipefail && %s merge -- - }, $self->samtools;
		for my $bam_file (@{$bam_file_list}) {
			$cmd .= sprintf q{<(%s view -b %s %s) }, $self->samtools, $bam_file, $self->_regions_string;
		}
	}
  $cmd .=  sprintf q{ | %s sort -l 0 - 2>/dev/null | %s mpileup -l %s -f %s -g - 2>/dev/null | %s call -c -O v - 2>/dev/null'}, $self->samtools, $self->samtools, $self->pos_snpname_map_filename, $self->reference, $self->bcftools;

	return $cmd;
}

__PACKAGE__->meta->make_immutable();

1;

__END__


=head1 NAME

npg_qc::utils::bam_genotype - check for adapter sequences in fastq files.

=head1 SYNOPSIS

    use npg_qc::utils::bam_genotype;

	Attributes required at construction:
		sample_name
		reference
		plex
		bam_file
		pos_snpname_map_filename - full path to this file (see "Auxilary Files Description"
			for more info)

	Optional attributes:
		report_aux_data - boolean - if true, report depths and likelihoods
		samtools_path - path to samtools executable (default: 
		samtools_name - name of samtools executable (default: samtools)
		bcftools_path - path to bcftools executable (default:bcftools)
		bcftools_name - name of bcftools executable (default: bcftools)


	Examples:
		my $bam_genotype =
			npg_qc::autoqc::checks::adapter->new(
				sample_name => 'UK10L_ALSPAC001',
				reference => 'refs/human_g1k_v37.fasta',
				plex => 'W30467', 
				bam_file => '4321_2#1.bam',
				pos_snpname_map_filename => 'W30467_chrpos_snpname_map_1000Genomes.tsv'
			);

		my $bam_genotype =
			npg_qc::autoqc::checks::adapter->new(
				sample_name => 'UK10L_ALSPAC001',
				reference => '/data/refs/human_g1k_v37.fasta',
				plex => 'W30467', 
				bam_file => '4321_2#1.bam',
				pos_snpname_map_filename => 'W30467_chrpos_snpname_map_1000Genomes.tsv'
			);

	Auxilary Files Description
	reference - reference genome
	
	pos_snpname_map_filename - a map of chromosome positions to SNP names, one per line: <chr> <pos>\t<rsname>.
	For example:

		1 74941293	rs649058
		1 169676486	rs1131498
		2 49189921	rs6166
		3 183818416	rs7627615
		4 38776491	rs11096957
		7 45932669	rs4619
		20 39797465	rs753381

##############################################################
    
=head1 DESCRIPTION

    Call genotype for a set of SNPs from a bam file


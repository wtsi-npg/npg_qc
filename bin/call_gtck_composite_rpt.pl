#!/usr/bin/env perl

# Author:        Kevin Lewis
# Created:       2013-02-15
#

#
# script which uses the qc genotype check module to call genotypes for the W30467 Sequenom QC set of loci
#  from a set of one or more bam files stored in iRODS.
# Flags:
#  -h : help
#  -r <rpt_list> : [REQUIRED] specify a list of run, position, and (optionally) tag_index values which determine the bam file set.
#     rpt_list should be in the format <id_run>:<lane>[:tag];... These values are then used to construct the bam file name:
#     Example: 9213:6:40;8213:1:4 yields ("irods:/seq/9213/9213_6#40.bam", "irods:/seq/8213/8213_1#4.bam")
#  -s : <sample_name>. [OPTIONAL] It is assumed, though not required, that all the bam files are for one particular sample.
#  -p <poss_dup_level> : [OPTIONAL] specify match level between genotypes considered to be a possible duplicate for the sample
#  -j : [OPTIONAL] Output in JSON format (default is an easier-to-read but non-standard text format
#  -o <output_file> : [OPTIONAL] Specify output file name (default is stdout)
#

use strict;
use warnings;
use FindBin qw($Bin);
use lib ( -d "$Bin/../lib/perl5" ? "$Bin/../lib/perl5" : "$Bin/../lib" );

use Getopt::Std;

use Data::Dumper;
use Carp;
use Readonly;

use Moose::Meta::Class;
use npg_tracking::illumina::run::short_info;
use npg_tracking::illumina::run::folder;
use npg_tracking::illumina::run::long_info;
use npg_qc::autoqc::checks::genotype;

##no critic
our $VERSION = '0';

my %opts;
getopts('hr:s:p:jo:g:m:a:x:c', \%opts);

##########
# rpt key list should be in the format <id_run>:<lane>[:tag];... These values are then used to construct the bam file names:
# Example:
#  If the run is still on the staging area: 9213:6:40;8213:1:4 yields ("<Latest_Summary_path_for_run9213>/archive/lane6/9213_6#40.bam", "<Latest_Summary_path_for_run8213>/archive/lane1/8213_1#4.bam")
#  otherwise, look in iRODS archive: 9213:6:40;8213:1:4 yields ("irods:/seq/9213/9213_6#40.bam", "irods:/seq/8213/8213_1#4.bam")
##########
my @bam_file_list;
my $ext = $opts{c}? q[cram]: q[bam];
if($opts{r}) {
	@bam_file_list = map { my ($r, $p, $t) = (split ":", $_); find_runlanefolder($r, $p, $t, $ext) or sprintf "irods:/seq/%d/%d_%d%s.%s", $r, $r, $p, $t? "#$t": "", $ext; } (split ";", $opts{r});

	carp qq[bam_file_list:\n\t], join("\n\t", @bam_file_list), "\n";
}

#######################################################
# find locations of repositories with npg_tracking role
#######################################################
my $ref_repos = Moose::Meta::Class->create_anon_class(roles => [qw/npg_tracking::data::reference::list/])->new_object()->ref_repository;
my $gt_repos = Moose::Meta::Class->create_anon_class(roles => [qw/npg_tracking::data::reference::list/])->new_object()->genotypes_repository;


my $sample_name = $opts{s};
my $plex_name = $opts{a};	# "a" for assays
my $poss_dup_level = $opts{p};
my $json_gt = $opts{j};
my $output_file = $opts{o};
my $reference_genome = $opts{g};
my $pos_snpname_map_filename = $opts{m};

my $gt_exec_path = $opts{x};

$sample_name ||= 'NO_SN';
$plex_name ||= q[sequenom_fluidigm_combo];	# standard Sequenom+Fluidigm QC plex
$reference_genome ||= $ref_repos . q[/Homo_sapiens/1000Genomes/all/fasta/human_g1k_v37.fasta];
my $chr_name_set = ($reference_genome =~ m{/GRCh38}? q[GRCh38]: ($reference_genome =~ m{/GRCh37}? q[GRCh37]: q[1000Genomes]));

die "Usage: call_gtck_composite_rpt.pl [-h] -r <rpt_list> -s <sample_name> -p <poss_dup_level> -j -o <output_file> -g <fasta_reference> -m <pos_snpname_map_file> -a <plex_name> -c\n" unless(@bam_file_list and $sample_name and $reference_genome and !$opts{h});

my $of;
if($output_file) {
	open $of, ">$output_file" or croak "Failed to open $output_file for output\n";
}
else {
	$of = *STDOUT;
}

my %attribs = (
	sample_name => $sample_name,
	alignments_in_bam => 1,
	reference_fasta => $reference_genome,
	input_files => [ (@bam_file_list) ],
	path => q[.],
);
if(defined $plex_name) {
	$attribs{sequenom_plex} = $plex_name;

	$pos_snpname_map_filename ||= $gt_repos . q[/] . $plex_name . q[_chrpos_snpname_map_] . $chr_name_set . q[.tsv];
}
if(defined $pos_snpname_map_filename) {
	$attribs{pos_snpname_map_fn} = $pos_snpname_map_filename;
}
if(defined $poss_dup_level) {
	$attribs{poss_dup_level} = $poss_dup_level;
}
if(defined $gt_exec_path) {
	$attribs{genotype_executables_path} = $gt_exec_path;
}

my $gtck= npg_qc::autoqc::checks::genotype->new(%attribs);

exit 0 unless($gtck->can_run);

my $ret=$gtck->execute;

my $result_string;
if($json_gt) {
	$result_string = $gtck->result->freeze;
}
else {
	$result_string = Dumper($gtck->result);
}

print $of $result_string;

sub find_runlanefolder {
	my ($id_run, $lane, $tag_index, $ext) = @_;

	# the methods hash ref passed to create_anon_class looks peculiar, but seems to be necessary to create a new object
	#  from an anonymous class in this way
        my $runfolder = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_tracking::illumina::run::short_info
                       npg_tracking::illumina::run::folder
                       npg_tracking::illumina::run::long_info/],
          methods => { runfolder_path => sub {}})
	  ->new_object({id_run => $id_run});

	my $rf;
	eval {
		$rf = $runfolder->runfolder_path;
	};
	if($rf) {
		my $ls = $rf . q[/Latest_Summary];
		die qq[Latest_summary link $ls not found] unless(-l $ls);

		my $full_path =  sprintf "%s/archive/", $ls;
		if($tag_index) {
			$full_path .= sprintf "lane%d/%d_%d#%d.%s", $lane, $id_run, $lane, $tag_index, $ext;
		}
		else {
			$full_path .= sprintf "%d_%d.%s", $id_run, $lane, $ext;
		}

		return $full_path;
	}

	return;
}


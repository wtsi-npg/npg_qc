# Author:        Kevin Lewis
# Maintainer:    $Author$
# Created:       2013-11-14
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$
#
#

package npg_qc::autoqc::checks::tags_reporters;

use strict;
use warnings;
use Moose;
use Carp;
use Data::Dumper;
use File::Basename;
use File::Slurp;
use File::Spec::Functions qw(catfile catdir);
use List::MoreUtils qw { any };
use JSON;
use npg_qc::utils::iRODS;
use npg_qc::autoqc::types;
use Readonly;
use FindBin qw($Bin);

extends qw(npg_qc::autoqc::checks::check);
with qw(npg_tracking::data::reference::find
        npg_common::roles::software_location
       );

our $VERSION = do { my ($r) = q$Revision$ =~ /(\d+)/mxs; $r; };

# Readonly::Scalar my $SAMTOOLS_NAME => q[samtools_irods];
Readonly::Scalar my $SAMTOOLS_NAME => q[/software/solexa/npg/bin/samtools_irods];
Readonly::Scalar our $EXT => q[bam];
Readonly::Scalar my $TAGS_LIST_FILENAME => q[tag_group_6.tags];
Readonly::Scalar my $REPORTERS_LIST_FILENAME => q[tag_group_42.tags];
Readonly::Scalar my $DB_LOOKUP_DEFAULT => 1;

has '+input_file_ext' => (default => $EXT,);

##############################################################################
# Input/output paths
#  By default, the pipeline supplies the archive path under the Latest_Summary
#  directory (the path attribute value is set via the qc_in value). This is
#  used to lazy-build the input output paths below
##############################################################################

#############################################################
# in_dir: 
#############################################################
has 'in_dir'  => ( isa        => 'Str',
                          is         => 'ro',
                          lazy_build  => 1,
                        );
sub _build_in_dir {
	my $self = shift;

	my $ip = $self->path;

	return $ip;
}

########################################
# out_dir: 
########################################
has 'out_dir'  => ( isa        => 'Str',
                          is         => 'ro',
                          lazy_build  => 1,
                        );
sub _build_out_dir {
	my $self = shift;

	my $op = $self->path;

	return $op;
}

####################################################
# tag_sets_repos: tag set files should be found here
####################################################
has 'tag_sets_repos'  => ( isa        => 'Str',
                          is         => 'ro',
                          lazy_build  => 1,
                        );
sub _build_tag_sets_repos {
	my $self = shift;

	my $repos = Moose::Meta::Class->create_anon_class(roles => [qw/npg_tracking::data::reference::list/])->new_object()->tag_sets_repository;

	return $repos;
}

#######################################################
# lane_path: Directory containing the lane bam file.
#  By default, currently two directories above supplied
#   path
#######################################################
has 'lane_path'  => ( isa        => 'Str',
                          is         => 'ro',
                          lazy_build  => 1,
                        );
sub _build_lane_path {
	my $self = shift;

	my $lp = $self->in_dir;

	return $lp;
}

##############################################################################
# tag0_bam_file (input data)
#  type should be something like 'NpgTrackingReadableFile', but that currently
#   doesn't cope with iRODS paths
##############################################################################
has 'lane_bam_file'  => ( isa        => 'Str',
                          is         => 'ro',
                          lazy_build  => 1,
                        );
sub _build_lane_bam_file {
	my $self = shift;

	my $lane_path = $self->lane_path;
	## no critic qw(ControlStructures::ProhibitUnlessBlocks)
	unless($lane_path =~ m{/$}smx) {
		$lane_path .= q[/];
	}
	## use critic
	my $basefilename = sprintf q[%s_%s.bam], $self->id_run, $self->position;

	my $file = $lane_path . $basefilename;

	if(! -f $file) {
		carp q[Failed to find ], $file, q[, looking in irods for bam file];

		$file = sprintf q[irods:/seq/%s/%s], $self->id_run, $basefilename;
	}

	return $file;
}

#################################################################################
# tags_filename (default: tag_group_6.tags, in the NPG repository under tag_sets)
#################################################################################
has 'tags_filename'  => ( isa        => 'NpgTrackingReadableFile',
                          is         => 'ro',
                          required   => 0,
                          lazy_build  => 1,
                        );
sub _build_tags_filename {
    my $self = shift;
    my $repos = $self->tag_sets_repos;

    return File::Spec->catfile($repos, $TAGS_LIST_FILENAME);
}

has 'tags_ids' => (
        isa => 'HashRef',
        is => 'ro',
        lazy_build => 1,
);
sub _build_tags_ids {
        my ($self) = @_;

	my $tags_file = $self->tags_filename;

	my @a = read_file($tags_file);

	my $ret = { map { (split) } @a };

	return $ret;
}

has 'reporters_ids' => (
        isa => 'HashRef',
        is => 'ro',
        lazy_build => 1,
);
sub _build_reporters_ids {
        my ($self) = @_;

	my $reporters_file = $self->reporters_filename;

	my @a = read_file($reporters_file);

	my $ret = { map { (split) } @a };

	return $ret;
}

#######################################################################################
# reporters_filename (default: tag_group_42.tags, in the NPG repository under tag_sets)
#######################################################################################
has 'reporters_filename'  => ( isa        => 'NpgTrackingReadableFile',
                          is         => 'ro',
                          required   => 0,
                          lazy_build  => 1,
                        );
sub _build_reporters_filename {
    my $self = shift;
    my $repos = $self->tag_sets_repos;

    return File::Spec->catfile($repos, $REPORTERS_LIST_FILENAME);
}

has 'maskflags_name'   => ( is      => 'ro',
                         isa     => 'NpgCommonResolvedPathExecutable',
                         coerce  => 1,
                         default => 'bammaskflags',
                       );

has 'maskflags_cmd'   => ( is      => 'ro',
                         isa     => 'Str',
                         lazy_build  => 1,
                       );
sub _build_maskflags_cmd {
	my $self = shift;

	return $self->maskflags_name . q[ maskneg=107];
}

has 'reads_from_bam_cmd'   => ( is      => 'ro',
                         isa     => 'Str',
                         lazy_build  => 1,
                       );
sub _build_reads_from_bam_cmd {
	my $self = shift;

	return sprintf q[%s view %s ], $self->samtools_name, $self->lane_bam_file;
}

########################################################################################
# you can override the executable name. May be useful for variants like "samtools_irods"
########################################################################################
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

override 'can_run' => sub {
	my $self = shift;

	if(defined $self->tag_index) {
		return 0;
	}

	if(! -f $self->lane_bam_file) {
		return 0;
	}

	return 1;
};

override 'execute' => sub {
	my ($self) = @_;
	my ($r, $n, %c, %tc, %rc);
	my ($fwd, $rev);
	my ($tag_seq, $tag_index, $tag_id, $reporters_id);

#	return 1 if super() == 0;

	if(!$self->can_run()) {
		return 1;
	}

	if(! -d $self->in_dir) {
		carp q[Warning: input directory "], $self->in_dir, q[" not found; iRODS, qcdb and possibly Latest_Summary will be used as input sources];
	}

	my $tags_ids = $self->tags_ids;
	my $reporters_ids = $self->reporters_ids;

	my $command = $self->reads_from_bam_cmd;

	##################
	#  collate results
	##################
	## no critic (ProhibitTwoArgOpen InputOutput::RequireBriefOpen Variables::ProhibitPunctuationVars)
	open my $fh, "$command |" or croak qq[Cannot fork "$command". $?];
	## use critic

	Readonly::Scalar my $FLAGS_FLD => 1;
	Readonly::Scalar my $REV_COMP_BIT => 16;
	Readonly::Scalar my $FIRST_FRAG_BIT => 64;
	Readonly::Scalar my $SEQ_FLD => 9;

	## no critic (ControlStructures::ProhibitUnlessBlocks ControlStructures::ProhibitPostfixControls)
	while(my $ln=<$fh>) {
		my $splitch = qq[\t];
		my @f = (split $splitch, $ln);
		if($f[1] & $FIRST_FRAG_BIT) {
			$fwd=$f[$SEQ_FLD];
			if($f[$FLAGS_FLD] & $REV_COMP_BIT) {
				$fwd=~tr/[ACGT]/[TGCA]/;
				$fwd=reverse $fwd;
			}
			if($ln=~m/\tBC:Z:(\S+)\t/smx) {
				$tag_seq=$1;
			}
			if($ln=~m/\tRG:Z:1\#(\d+)/smx) {
				$tag_index=$1;
			}
		}
		else {
			$rev=$f[$SEQ_FLD];
			unless($f[$FLAGS_FLD] & $REV_COMP_BIT) {
				$rev=~tr/[ACGT]/[TGCA]/;
				$rev=reverse $rev;
			}
			next unless ($tag_index && exists($tags_ids->{$tag_seq}) && exists($reporters_ids->{$fwd}) && exists($reporters_ids->{$rev}) && $reporters_ids->{$fwd}==$reporters_ids->{$rev});
			$tag_id=$tags_ids->{$tag_seq};
			$reporters_id=$reporters_ids->{$fwd};
			$tc{$tag_id}++;
			$rc{$reporters_id}++;
			$n++;
			$c{$tag_id}->{$reporters_id}++;
		}
	}
	## use critic

#	close $fh or croak qq[Cannot close "$command". $?];

	################
	#  store results
	################

	## no critic (ValuesAndExpressions::ProhibitMagicNumbers)

	$self->result->tag_list([ (sort {$a<=>$b} keys %tc) ]);

	my @amp_rows = ();
        for my $reporter_id (sort {$a<=>$b} keys %rc) {
		my %amp_row;
		$amp_row{reporter_id} = $reporter_id;
		my @counts = ();
                my $rc=0;
                for my $tag_id (sort {$a<=>$b} keys %tc) {
                        my $c=(exists($c{$tag_id}->{$reporter_id}) ? $c{$tag_id}->{$reporter_id} : 0);
                        $rc += $c;
			push @counts, $c;
		}
		$amp_row{counts} = \@counts;
                $amp_row{amp_total}=$rc;
                $amp_row{amp_percentage} = 100.0*($rc/$n);

		push @amp_rows, \%amp_row;
        }
	$self->result->amp_rows(\@amp_rows);

	my @tag_totals = ();
	my @tag_totals_pct = ();
	for my $tag_id (sort {$a<=>$b} keys %tc) {
		my $tc=0;
		for my $reporter_id (sort {$a<=>$b} keys %rc) {
			my $c=(exists($c{$tag_id}->{$reporter_id}) ? $c{$tag_id}->{$reporter_id} : 0);
			$tc += $c;
		}
		push @tag_totals, $tc;
		push @tag_totals_pct, 100.0*$tc/$n;
	}
	$self->result->tag_totals(\@tag_totals);
	$self->result->tag_totals_pct(\@tag_totals_pct);
	## use critic

#	$self->result->pass = 1;  # no pass/fail criterion yet, so leave undef

	return 1;
};

################
# auxiliary subs
################


####################
# private attributes
####################

no Moose;
__PACKAGE__->meta->make_immutable();


1;

__END__


=head1 NAME

npg_qc::autoqc::checks::tags_reporters 

=head1 VERSION

    $Revision$

=head1 SYNOPSIS

    use npg_qc::autoqc::checks::tags_reporters;

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

Copyright (C) 2013 GRL, by Kevin Lewis

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

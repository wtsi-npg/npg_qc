package npg_qc::autoqc::checks::rna_seqc;

use Moose;
use namespace::autoclean;
use English qw( -no_match_vars );
use Carp;
use npg::api::run;
use Readonly;
use DateTime;
use npg_tracking::util::types;

extends qw(npg_qc::autoqc::checks::check);

with qw(npg_tracking::data::reference::find 
        npg_common::roles::software_location
        npg_tracking::data::transcriptome::find
       );

our $VERSION = '0';

Readonly::Scalar our $EXT => q[bam];
Readonly::Scalar my $RNASEQC_JAR_NAME       => q[RNA-SeQC_v1.1.8.jar];
Readonly::Scalar my $RNASEQC_JAR_VERSION    => q[1.1.8];
Readonly::Scalar my $RNASEQC_GTF_TTYPE_COL  => 2;
Readonly::Scalar my $RNASEQC_GTF_DIRECTORY  => q[RNA-SeQC];
Readonly::Scalar my $RNASEQC_OUTDIR         => q[rna_seqc];
Readonly::Scalar my $JAVA_MAX_HEAP_SIZE     => q[4000m];
Readonly::Scalar my $JAVA_GC_TYPE           => q[+UseSerialGC];
Readonly::Scalar my $JAVA_USE_PERF_DATA     => q[-UsePerfData];
Readonly::Scalar my $CHILD_ERROR_SHIFT      => 8;

has '+file_type' => (default => $EXT,);

has '+aligner' => (default => q[fasta],);

has '_java_max_heap_size'     => (is      => 'ro',
                                  isa     => 'Str',
                                  default => $JAVA_MAX_HEAP_SIZE,
                                  init_arg => undef,);

has '_java_gc_type'           => (is      => 'ro',
                                  isa     => 'Str',
                                  default => $JAVA_GC_TYPE,
                                  init_arg => undef,);

has '_java_use_perf_data'     => (is      => 'ro',
                                  isa     => 'Str',
                                  default => $JAVA_USE_PERF_DATA,
                                  init_arg => undef,);

has '_java_jar_path'          => (is      => 'ro',
                                  isa     => 'NpgCommonResolvedPathJarFile',
                                  coerce  => 1,
                                  default => $RNASEQC_JAR_NAME,
                                  init_arg => undef,);

has '_ttype_gtf_column' => (is      => 'ro',
                            isa     => 'Int',
                            default => $RNASEQC_GTF_TTYPE_COL,
                            init_arg => undef,);


has '_alignments_in_bam' => (is         => 'ro',
                             isa        => 'Maybe[Bool]',
                             lazy_build => 1,
                             init_arg => undef,);

sub _build__alignments_in_bam {
    my ($self) = @_;
    return $self->lims->alignments_in_bam;
}

has 'qc_out'     => (is         => 'ro',
                     isa        => 'NpgTrackingDirectory',
                     required   => 1,);

has '_input_str' => (is => 'ro',
                     isa        => 'Str',
                     lazy_build => 1,
                     init_arg => undef,);

sub _build__input_str {
    my ($self) = @_;
    my $sample_id = $self->lims->sample_id;
    my $library_name = $self->lims->library_name // $sample_id;
    my @library_names = split q[ ], $library_name;
    my $input_file = $self->_bam_file;
    return qq["$library_names[0]|$input_file|$sample_id"];
}

has '_reference_fasta' => (is => 'ro',
                           isa => 'Maybe[Str]',
                           lazy_build => 1,
                           init_arg => undef,);

sub _build__reference_fasta {
    my ($self) = @_;
    return $self->refs->[0];
}

has '_bam_file' => (is         => 'ro',
                    isa        => 'Str',
                    lazy_build => 1,
                    init_arg => undef,);

sub _build__bam_file {
    my $self = shift;
    return $self->input_files->[0];
}

has '_annotation_gtf' => (is         => 'ro',
                          isa        => 'Maybe[Str]',
                          lazy_build => 1,
                          init_arg => undef,);

sub _build__annotation_gtf {
    my $self = shift;
    my $trans_gtf = $self->rnaseqc_gtf_file;
    return $trans_gtf;
}

sub _command {
    my ($self) = @_;
    my $single_end_option=q[];
    if(!npg::api::run->new({id_run => $self->id_run})->is_paired_read()){
        $single_end_option=q[-singleEnd];
    }
    my $command = $self->java_cmd. sprintf q[ -Xmx%s -XX:%s -XX:%s -jar %s -s %s -o %s -r %s -t %s -ttype %d %s],
                                           $self->_java_max_heap_size,
                                           $self->_java_gc_type,
                                           $self->_java_use_perf_data,
                                           $self->_java_jar_path,
                                           $self->_input_str,
                                           $self->qc_out,
                                           $self->_reference_fasta,
                                           $self->_annotation_gtf,
                                           $self->_ttype_gtf_column,
                                           $single_end_option;
    return $command;
}

override 'can_run' => sub {
    my $self = shift;
    my $l = $self->lims;
    my $can_run = 1;
    my @comments;
    if(! $self->_alignments_in_bam) {
        push @comments, q[Alignments_in_bam is false];
        $can_run = 0;
    }
    if ((! $l->library_type || $l->library_type !~ /(?:cD|R)NA/sxm) && $l->library_type ne q[Pre-quality controlled]) {
        push @comments, join q[ ], q[Not RNA library type: ], $l->library_type;
        $can_run = 0;
    }
    if (! $l->reference_genome) {
        push @comments, q[No reference genome available];
        $can_run = 0;
    }
    if (! $self->transcriptome_index_name()) {
        push @comments, q[Not transcriptome set so not a splice junction alignment (e.g. Tophat)];
        $can_run = 0;
    }
    if (! $can_run) {
        my $can_run_message = join q[, ], @comments;
        $self->result->add_comment($can_run_message);
        carp qq[Skipping RNA-SeQC check because: $can_run_message];
    }
    return $can_run;
};

override 'execute' => sub {
    my ($self) = @_;
    if (super() == 0) {
    	return 1;
    }
    if ($self->messages->count) {
        $self->result->add_comment(join q[ ], $self->messages->messages);
    }
    if (!$self->can_run()) {
    	return 1;
    }
    $self->result->set_info('Jar', qq[RNA-SeqQC $RNASEQC_JAR_NAME]);
    $self->result->set_info('Jar_version', $RNASEQC_JAR_VERSION);
    my $command = $self->_command();
    $self->result->set_info('Command', $command);
    carp qq[EXECUTING $command time ]. DateTime->now();
    if (system $command) {
        my $error =  printf "Child %s exited with value %d\n", $command, $CHILD_ERROR >> $CHILD_ERROR_SHIFT;
        carp "Failed to execute $command";
    }
    return 1;
};

__PACKAGE__->meta->make_immutable();

1;

__END__


=head1 NAME

npg_qc::autoqc::checks::rna_seqc 

=head1 SYNOPSIS

=head1 DESCRIPTION

QC check that runs Broad Institute's 'RNA-SeQC software over an RNA-Seq sample.
Files generated by RNA-SeQC are overwriten everytime it's executed and except
for the directory where the metrics are stored (named after Sample ID) all use
the same names. The user must consider this when passing the value of qc_out. 

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

=item namespace::autoclean

=item English

=item Carp

=item npg::api::run
 
=item Readonly

=item DateTime

=item npg_qc::autoqc::checks::check

=item npg_tracking::data::reference::find

=item npg_common::roles::software_location

=item npg_tracking::data::transcriptome::find

=back

=head1 AUTHOR

Ruben E Bautista-Garcia<lt>rb11@sanger.ac.ukE<gt>

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

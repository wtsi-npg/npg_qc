package npg_qc::autoqc::checks::rna_seqc;

use Moose;
use namespace::autoclean;
use English qw( -no_match_vars );
use Carp;
use Readonly;
use DateTime;
use IO::File;
use npg_tracking::util::types;
use File::Spec;
use File::Path qw( make_path );
use Scalar::Util qw(looks_like_number);

extends qw(npg_qc::autoqc::checks::check);

with qw(npg_tracking::data::reference::find
        npg_common::roles::software_location
        npg_tracking::data::transcriptome::find
       );

our $VERSION = '0';

Readonly::Scalar our $EXT => q[bam];

Readonly::Scalar my $RNASEQC_JAR_NAME  => q[RNA-SeQC.jar];
Readonly::Scalar my $CHILD_ERROR_SHIFT => 8;
Readonly::Scalar my $MAX_READS         => 100;
Readonly::Scalar my $MIN_READS         => 1000;
Readonly::Scalar my $PAIRED_FLAG       => 0x1;
Readonly::Scalar my $RRNA_ALIGNER      => q[bwa0_5];
Readonly::Scalar my $RRNA_ALIGNER_IDX  => q[bwa];
Readonly::Scalar my $RRNA_STRAIN       => q[default_rRNA];
Readonly::Scalar my $METRICS_FILE_NAME => q[metrics.tsv];
Readonly::Scalar my $QUANT_FILE_NAME   => q[quant.genes.sf];
Readonly::Scalar my $MINUS_ONE         => -1;
Readonly::Scalar my $COL_QUANT_TPM     => 3;
Readonly::Scalar my $COL_QUANT_GENEID  => 0;
Readonly::Scalar my $COL_GENEID        => 0;
Readonly::Scalar my $COL_GENENAME      => 1;
Readonly::Scalar my $GLOBIN_METRIC_NAME=> q[Globin % TPM];
Readonly::Scalar my $MT_METRIC_NAME    => q[Mitochondrial % TPM];
Readonly::Scalar my $TEN_THOUSAND      => 10_000;

# Globin metric is not part of RNA-SeQC, its name is arbitrary and has been
# added to the hash to be treated the same way as selected RNA-SeQC results
Readonly::Hash   my %RNASEQC_METRICS_FIELDS_MAPPING => {
    '3\' Norm'                              => 'end_3_norm',
    '5\' Norm'                              => 'end_5_norm',
    'End 1 % Sense'                         => 'end_1_pct_sense',
    'End 1 Antisense'                       => 'end_1_antisense',
    'End 1 Sense'                           => 'end_1_sense',
    'End 2 % Sense'                         => 'end_2_pct_sense',
    'End 2 Antisense'                       => 'end_2_antisense',
    'End 2 Sense'                           => 'end_2_sense',
    'Exonic Rate'                           => 'exonic_rate',
    'Expression Profiling Efficiency'       => 'expression_profiling_efficiency',
    'Genes Detected'                        => 'genes_detected',
    'Mean CV'                               => 'mean_cv',
    'Mean Per Base Cov.'                    => 'mean_per_base_cov',
    'rRNA'                                  => 'rrna',
    'rRNA rate'                             => 'rrna_rate',
    $GLOBIN_METRIC_NAME                     => 'globin_pct_tpm',
    $MT_METRIC_NAME                         => 'mt_pct_tpm',
};

has '+file_type' => (default => $EXT,);

has '+aligner' => (default => 'fasta',
                   is => 'ro',
                   writer => '_set_aligner',);

has 'rna_seqc_report_path' => (is       => 'ro',
                               isa      => 'Str',
                               lazy     => 1,
                               builder  => '_build_rna_seqc_report_path',);

sub _build_rna_seqc_report_path {
    my ($self) = @_;
    my $qc_out_path = $self->qc_out;
    my $rna_seqc_report_path = File::Spec->catdir($qc_out_path, $self->result->filename_root . q[_rna_seqc]);
    return $rna_seqc_report_path;
}

has '_java_jar_path' => (is       => 'ro',
                         isa      => 'NpgCommonResolvedPathJarFile',
                         coerce   => 1,
                         default  => $RNASEQC_JAR_NAME,
                         init_arg => undef,);

has '_ttype_gtf_column' => (is      => 'ro',
                            isa     => 'Int',
                            default => 2,);

has '_alignments_in_bam' => (is      => 'ro',
                             isa     => 'Bool',
                             lazy    => 1,
                             builder => '_build_alignments_in_bam',);

sub _build_alignments_in_bam {
    my $self = shift;
    my $aligned = 0;
    my $command = $self->samtools_cmd . ' view -H ' . $self->_bam_file . ' |';
    my $ph = IO::File->new($command) or croak qq[Cannot fork '$command', error $ERRNO];
    while (my $line = <$ph>) {
        if (!$aligned && $line =~ /^\@SQ/smx) {
            $aligned = 1;
        }
    }
    $ph->close();
    return $aligned;
}

has '_reads_in_bam' => (is      => 'ro',
                        isa     => 'Bool',
                        lazy    => 1,
                        builder => '_build_reads_in_bam',);

sub _build_reads_in_bam {
    my ($self) = @_;
    my $read_lines = 0;
    # count mapped reads only
    my $view_command = $self->samtools_cmd. q[ view -c -F 260 ]. $self->_bam_file. q[ 2>/dev/null | ];
    my $ph = IO::File->new($view_command) or croak "Error viewing bam: $OS_ERROR\n";
    my $count = $ph->getline;
    $ph->close();
    return $count >= $MIN_READS ? 1 : 0;
}

has '_is_paired_end' => (is      => 'ro',
                         isa     => 'Bool',
                         lazy    => 1,
                         builder => '_build_is_paired_end',);

sub _build_is_paired_end {
    my ($self) = @_;
    my $paired = 0;
    my $flag;
    my $num_reads = 0;
    my $view_command = $self->samtools_cmd. q[ view ]. $self->_bam_file. q[ 2>/dev/null | ];
    my $ph = IO::File->new($view_command) or croak "Error viewing bam: $OS_ERROR\n";
    while (my $line = <$ph>) {
        next if $line =~ /^\@/ismx;
        my @read = split /\t/smx, $line;
        $flag = $read[1];
        if ($flag & $PAIRED_FLAG){
            $paired = 1;
        }
        $num_reads += 1;
        # if enough reads have been read and none is PAIRED
        # assume it isn't and stop reading file
        last if ($num_reads >= $MAX_READS || $paired);
    }
    $ph->close();
    return $paired;
}

has '_is_rna_alignment' => (is      => 'ro',
                            isa     => 'Bool',
                            lazy    => 1,
                            builder => '_build_is_rna_alignment',);

sub _build_is_rna_alignment {
    my ($self) = @_;
    my $rna_alignment = 0;
    my $command = $self->samtools_cmd . ' view -H ' . $self->_bam_file . ' |';
    my $ph = IO::File->new($command) or croak qq[Cannot fork '$command', error $ERRNO];
    while (my $line = <$ph>) {
        if (!$rna_alignment && $line =~ /^\@PG\s+.*TopHat|STAR/smx) {
            $rna_alignment = 1;
        }
    }
    $ph->close();
    return $rna_alignment;

}

has '_input_str' => (is       => 'ro',
                     isa      => 'Str',
                     lazy     => 1,
                     builder  => '_build_input_str',
                     init_arg => undef,);

sub _build_input_str {
    my ($self) = @_;
    my $sample_id = $self->lims->sample_id;
    my $sample_name = $self->lims->sample_name // $sample_id;
    my @sample_names = split q[ ], $sample_name;
    my $input_file = $self->_bam_file;
    return qq["$sample_names[0]|$input_file|$sample_id"];
}

has 'ref_genome' => (is       => 'ro',
                      isa      => 'Str',
                      lazy     => 1,
                      builder  => '_build_ref_genome',);

sub _build_ref_genome {
    my ($self) = @_;
    my $reference_fasta = $self->refs->[0] // q[];
    return $reference_fasta;
}

has '_bam_file' => (is      => 'ro',
                    isa     => 'NpgTrackingReadableFile',
                    lazy    => 1,
                    builder => '_build_bam_file',);

sub _build_bam_file {
    my $self = shift;
    return $self->input_files->[0];
}

has 'annotation_gtf' => (is       => 'ro',
                          isa      => 'Str',
                          lazy     => 1,
                          builder  => '_build_annotation_gtf',);

sub _build_annotation_gtf {
    my $self = shift;
    my $trans_gtf = $self->rnaseqc_gtf_file // q[];
    return $trans_gtf;
}

has 'ref_rrna' => (is       => 'ro',
                    isa      => 'Str',
                    lazy     => 1,
                    builder  => '_build_ref_rrna',);

sub _build_ref_rrna {
    my $self = shift;
    my ($organism, $strain, $transcriptome) = $self->parse_reference_genome($self->lims->reference_genome);
    $self->_set_aligner($RRNA_ALIGNER_IDX);
    $self->_set_strain($RRNA_STRAIN);
    $self->_set_species($organism);
    my $ref_rrna = $self->refs->[0] // q[];
    return $ref_rrna;
}

has 'bwa_rrna' => (is            => 'ro',
                   isa           => 'NpgCommonResolvedPathExecutable',
                   coerce        => 1,
                   lazy          => 1,
                   builder       => '_build_bwa_rrna',
                   documentation => q[Old version of bwa for rRNA alignments as downsampled bam not name sorted],);

sub _build_bwa_rrna{
  my $self = shift;
  return $RRNA_ALIGNER;
}

has 'quant_file' => (is       => 'ro',
                     isa      => 'Str',
                     lazy     => 1,
                     builder  => '_build_quant_file',);

sub _build_quant_file {
    my $self = shift;
    my $qc_in_path = $self->qc_in;
    my $quant_file = File::Spec->catfile($qc_in_path, $self->result->filename_root . q[.] . $QUANT_FILE_NAME);
    return $quant_file;
}

has 'globin_genes_csv' => (is       => 'ro',
                           isa      => 'Str',
                           lazy     => 1,
                           builder  => '_build_globin_genes_csv',);

sub _build_globin_genes_csv {
    my $self = shift;
    my $globin_file = $self->globin_file // q[];
    return $globin_file;
}

has 'mt_genes_csv' => (is       => 'ro',
                       isa      => 'Str',
                       lazy     => 1,
                       builder  => '_build_mt_genes_csv',);

sub _build_mt_genes_csv {
    my $self = shift;
    my $mt_file = $self->mt_file // q[];
    return $mt_file;
}

has '_results' => (traits  => ['Hash'],
                   isa     => 'HashRef',
                   is      => 'ro',
                   default => sub { {} },
                   handles => {
                       _set_result    => 'set',
                       _get_result    => 'get',
                       _delete_result => 'delete',
                   },);

sub _command {
    my ($self) = @_;
    my $ref_rrna_option = q[];
    my $single_end_option = q[];
    if(!$self->_is_paired_end){
        $single_end_option = q[-singleEnd];
    }
    if($self->ref_rrna){
        $ref_rrna_option = q[-bwa ] . $self->bwa_rrna . q[ -BWArRNA ]. $self->ref_rrna;
    }
    my $command = $self->java_cmd. sprintf q[ -Xmx4000m -XX:+UseSerialGC -XX:-UsePerfData -jar %s -s %s -o %s -r %s -t %s -ttype %d %s %s],
                                           $self->_java_jar_path,
                                           $self->_input_str,
                                           $self->rna_seqc_report_path,
                                           $self->ref_genome,
                                           $self->annotation_gtf,
                                           $self->_ttype_gtf_column,
                                           $single_end_option,
                                           $ref_rrna_option;
    return $command;
}

override 'can_run' => sub {
    my $self = shift;
    if (! $self->annotation_gtf) {
        $self->result->add_comment(q[No GTF annotation available]);
        return 0;
    }
    return 1;
};

override 'execute' => sub {
    my $self = shift;

    super();

    my @comments;
    my $can_execute = 1;
    $self->result->set_info('Jar', qq[RNA-SeqQC $RNASEQC_JAR_NAME]);
    if($self->_reads_in_bam) {
        if (! $self->ref_genome) {
            push @comments, q[No reference genome available];
            $can_execute = 0;
        }
        if(! $self->_alignments_in_bam) {
            push @comments, q[BAM file is not aligned];
            $can_execute = 0;
        }
        if (! $self->_is_rna_alignment) {
            push @comments, q[BAM file is not RNA alignment];
            $can_execute = 0;
        }
    } else {
        push @comments, q[BAM file has too few or no usable reads];
        $can_execute = 0;
    }

    if (! $can_execute || ! $self->can_run()) {
        my $can_run_message = join q[; ], @comments;
        $self->result->add_comment($can_run_message);
        return 1;
    }
    # gene metrics:
    $self->_parse_quant_file();
    # RNA-SeQC metrics:
    my $command = $self->_command();
    carp qq[EXECUTING $command time ]. DateTime->now();
    if (system $command) {
        my $error = $CHILD_ERROR >> $CHILD_ERROR_SHIFT;
        croak sprintf "Child %s exited with value %d\n", $command, $error;
    } else {
        $self->_parse_rna_seqc_metrics();
    };

    $self->_save_results();
    return 1;
};

sub _parse_rna_seqc_metrics {
    my $self = shift;
    my $filename = File::Spec->catfile($self->rna_seqc_report_path, $METRICS_FILE_NAME);
    if (! -e $filename) {
        croak qq[No such file $filename: cannot parse RNA-SeQC metrics];
    }
    my $fh = IO::File->new($filename, 'r');
    my @lines;
    if (defined $fh){
        @lines = $fh->getlines();
    }
    $fh->close();
    my @keys = split /\t/smx, $lines[0];
    my @values = split /\t/smx, $lines[1], $MINUS_ONE;
    if (scalar @keys != scalar @values) {
        croak q[Mismatch in number of keys and values];
    }
    my $i = 0;
    foreach my $key (@keys){
        chomp $values[$i];
        chomp $key;
        $self->_set_result($key => $values[$i]);
        $i++;
    }
    return;
};

sub _parse_quant_file {
    my $self = shift;
    my $quant_file = $self->quant_file;
    if (! -e $quant_file) {
        $self->result->add_comment(qq[No such file $quant_file: Cannot parse quant metrics]);
        return;
    }
    my $globin_genes = {};
    my $mt_genes = {};
    # globin genes metric:
    if ($self->globin_genes_csv) {
        $self->_read_genes_file($self->globin_genes_csv, $globin_genes);
    }
    # mitochondrial genes metric:
    if ($self->mt_genes_csv) {
        $self->_read_genes_file($self->mt_genes_csv, $mt_genes);
    }
    my %quant_genes = ('globin_sum' => 0, 'mt_sum' => 0);
    my $fh = IO::File->new($quant_file, 'r');
    while (my $line = $fh->getline) {
        my @quant_record = split /\t/smx, $line;
        if (exists $globin_genes->{$quant_record[$COL_QUANT_GENEID]}){
            if (looks_like_number($quant_record[$COL_QUANT_TPM])) {
                $quant_genes{'globin_sum'} += $quant_record[$COL_QUANT_TPM];
            }
        }
        if (exists $mt_genes->{$quant_record[$COL_QUANT_GENEID]}){
            if (looks_like_number($quant_record[$COL_QUANT_TPM])) {
                $quant_genes{'mt_sum'} += $quant_record[$COL_QUANT_TPM];
            }
        }
    }
    $fh->close();
    $self->_set_result($GLOBIN_METRIC_NAME => sprintf '%.2f', $quant_genes{'globin_sum'} / $TEN_THOUSAND);
    $self->_set_result($MT_METRIC_NAME => sprintf '%.2f', $quant_genes{'mt_sum'} / $TEN_THOUSAND);
    return;
}

sub _read_genes_file {
    my ($self, $genes_file, $genes_list) = @_;
    my $fh = IO::File->new($genes_file, 'r');
    while (my $line = $fh->getline) {
        chomp $line;
        my @gene_record = split /,/smx, $line;
        $genes_list->{$gene_record[$COL_GENEID]} = $gene_record[$COL_GENENAME];
    }
    $fh->close();
    return;
}

sub _save_results {
    my $self = shift;
    foreach my $key (keys %RNASEQC_METRICS_FIELDS_MAPPING) {
        my $value = $self->_get_result($key);
        if (defined $value) {
            my $attr_name = $RNASEQC_METRICS_FIELDS_MAPPING{$key};
            if ($value eq q[NaN]) {
                carp qq[Value of $attr_name is 'NaN', skipping...];
            } else {
                $self->result->$attr_name($value);
            }
        }
        $self->_delete_result($key);
    }
    $self->result->other_metrics($self->_results);
    $self->result->rna_seqc_report_path($self->rna_seqc_report_path);
    return;
}
__PACKAGE__->meta->make_immutable();

1;

__END__


=head1 NAME

npg_qc::autoqc::checks::rna_seqc

=head1 SYNOPSIS

=head1 DESCRIPTION

QC check that runs Broad Institute's RNA-SeQC; a java program which computes a
series of quality control metrics for RNA-seq data. The output consists of
HTML reports and tab delimited files of metrics data from which a selection of
them are extracted to generate an autoqc result. The output directory is
created by default using the sample's filename root.

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

=item Readonly

=item DateTime

=item IO::File

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

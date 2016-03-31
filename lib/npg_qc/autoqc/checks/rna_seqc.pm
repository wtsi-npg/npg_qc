package npg_qc::autoqc::checks::rna_seqc;

use Moose;
use namespace::autoclean;
use English qw( -no_match_vars );
use Carp;
use Readonly;
use DateTime;
use IO::File;
use npg_tracking::util::types;

extends qw(npg_qc::autoqc::checks::check);

with qw(npg_tracking::data::reference::find 
        npg_common::roles::software_location
        npg_tracking::data::transcriptome::find
       );

our $VERSION = '0';

Readonly::Scalar our $EXT => q[bam];
Readonly::Scalar my $RNASEQC_JAR_NAME       => q[RNA-SeQC.jar];
Readonly::Scalar my $CHILD_ERROR_SHIFT      => 8;
Readonly::Scalar my $MAX_READS              => 100;
Readonly::Scalar my $PAIRED_FLAG            => 0x1;

has '+file_type' => (default => $EXT,);

has '+aligner' => (default => q[fasta],);

has '_java_jar_path'          => (is      => 'ro',
                                  isa     => 'NpgCommonResolvedPathJarFile',
                                  coerce  => 1,
                                  default => $RNASEQC_JAR_NAME,
                                  init_arg => undef,);

has '_ttype_gtf_column' => (is      => 'ro',
                            isa     => 'Int',
                            default => 2,);

has '_alignments_in_bam' => (is         => 'ro',
                             isa        => 'Maybe[Bool]',
                             lazy_build => 1,);

sub _build__alignments_in_bam {
    my $self = shift;
    my $aligned = 0;
    my $command = $self->samtools_irods_cmd . ' view -H ' . $self->_bam_file . ' |';
    my $ph = IO::File->new($command) or croak qq[Cannot fork '$command', error $ERRNO];
    while (my $line = <$ph>) {
        if (!$aligned && $line =~ /^\@SQ/smx) {
            $aligned = 1;
        }
    }
    $ph->close();
    return $aligned;
}

has '_is_paired_end' => (is         => 'ro',
                         isa        => 'Maybe[Bool]',
                         lazy_build => 1,);

sub _build__is_paired_end {
    my ($self) = @_;
    my $paired = 0;
    my $flag;
    my $num_reads = 0;
    my $view_command = $self->samtools_irods_cmd. q[ view ]. $self->_bam_file. q[ 2>/dev/null | ];
    my $ph = IO::File->new($view_command) or croak "Error viewing bam: $OS_ERROR\n";
    while (my $line = <$ph>) {
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

has '_is_rna_alignment' => (is         => 'ro',
                            isa        => 'Maybe[Bool]',
                            lazy_build => 1,);

sub _build__is_rna_alignment {
    my ($self) = @_;
    my $rna_alignment = 0;
    my $command = $self->samtools_irods_cmd . ' view -H ' . $self->_bam_file . ' |';
    my $ph = IO::File->new($command) or croak qq[Cannot fork '$command', error $ERRNO];
    while (my $line = <$ph>) {
        if (!$rna_alignment && $line =~ /^\@PG\s+.*tophat/ismx) {
            $rna_alignment = 1;
        }
    }
    $ph->close();
    return $rna_alignment;

}

has 'qc_out'     => (is         => 'ro',
                     isa        => 'NpgTrackingDirectory',
                     required   => 1,);

has '_input_str' => (is         => 'ro',
                     isa        => 'Str',
                     lazy_build => 1,
                     init_arg   => undef,);

sub _build__input_str {
    my ($self) = @_;
    my $sample_id = $self->lims->sample_id;
    my $library_name = $self->lims->library_name // $sample_id;
    my @library_names = split q[ ], $library_name;
    my $input_file = $self->_bam_file;
    return qq["$library_names[0]|$input_file|$sample_id"];
}

has '_reference_fasta' => (is         => 'ro',
                           isa        => 'Maybe[Str]',
                           lazy_build => 1,);

sub _build__reference_fasta {
    my ($self) = @_;
    my $reference_fasta = $self->refs->[0] // q[];
    return $reference_fasta;
}

has '_bam_file' => (is         => 'ro',
                    isa        => 'Str',
                    lazy_build => 1,);

sub _build__bam_file {
    my $self = shift;
    return $self->input_files->[0];
}

has '_annotation_gtf' => (is         => 'ro',
                          isa        => 'Maybe[Str]',
                          lazy_build => 1,);

sub _build__annotation_gtf {
    my $self = shift;
    my $trans_gtf = $self->rnaseqc_gtf_file // q[];
    return $trans_gtf;
}

sub _command {
    my ($self) = @_;
    my $single_end_option=q[];
    if(!$self->_is_paired_end){
        $single_end_option=q[-singleEnd];
    }
    my $command = $self->java_cmd. sprintf q[ -Xmx4000m -XX:+UseSerialGC -XX:-UsePerfData -jar %s -s %s -o %s -r %s -t %s -ttype %d %s],
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
    if (! $self->_annotation_gtf) {
        $self->result->add_comment(q[No GTF annotation available]);
        return 0;
    }
    return 1;
};

override 'execute' => sub {
    my ($self) = @_;
    my @comments;
    my $can_execute = 1;
    if (super() == 0) {
    	return 1;
    }
    $self->result->set_info('Jar', qq[RNA-SeqQC $RNASEQC_JAR_NAME]);
    if (! $self->_reference_fasta) {
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
    if (! $can_execute || ! $self->can_run()) {
        my $can_run_message = join q[; ], @comments;
        $self->result->add_comment($can_run_message);
        return 1;
    }
    my $command = $self->_command();
    $self->result->set_info('Command', $command);
    carp qq[EXECUTING $command time ]. DateTime->now();
    if (system $command) {
        my $error = $CHILD_ERROR >> $CHILD_ERROR_SHIFT;
        croak sprintf "Child %s exited with value %d\n", $command, $error;
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

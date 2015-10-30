package npg_qc::autoqc::checks::rna_seqc;

use Moose;
use namespace::autoclean;
use English qw( -no_match_vars );
use Carp;
use File::Spec::Functions qw( catdir );
use File::Basename;
use npg_qc::autoqc::types;
#use npg::api::run;
use Readonly;
use Try::Tiny;
use npg_tracking::util::types;

extends qw(npg_qc::autoqc::checks::check
           npg_pipeline::base
);

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

has '+file_type' => (default => $EXT,);

has '+aligner' => (default => q[fasta],);

has 'java_max_heap_size'     => (is      => 'ro',
                                 isa     => 'Str',
                                 default => $JAVA_MAX_HEAP_SIZE,);

has 'java_gc_type'           => (is      => 'ro',
                                 isa     => 'Str',
                                 default => $JAVA_GC_TYPE,);

has 'java_use_perf_data'     => (is      => 'ro',
                                 isa     => 'Str',
                                 default => $JAVA_USE_PERF_DATA,);

has 'java_jar_path'          => (is      => 'ro',
                                 isa     => 'NpgCommonResolvedPathJarFile',
                                 coerce  => 1,
                                 default => $RNASEQC_JAR_NAME,);

has 'transcript_type' => (is      => 'ro',
                          isa     => 'Int',
                          default => $RNASEQC_GTF_TTYPE_COL,);


has 'alignments_in_bam' => (is         => 'ro',
                            isa        => 'Maybe[Bool]',
                            lazy_build => 1,);

sub _build_alignments_in_bam {
    my ($self) = @_;
    return $self->lims->alignments_in_bam;
}

has 'qc_out'     => (is         => 'ro',
                     isa        => 'NpgTrackingDirectory',
                     required   => 1,);

has 'input_str' => (is => 'ro',
                    isa        => 'Str',
                    lazy_build => 1,);

sub _build_input_str {
    my ($self) = @_;
    my $sample_id = $self->lims->sample_id;
    my $notes = $self->lims->library_name // $sample_id;
    my $input_file = $self->bam_file;
    return qq["$sample_id|$input_file|$notes"];
}

has 'reference_fasta' => (is => 'ro',
                          isa => 'Maybe[Str]',
                          lazy_build => 1,);

sub _build_reference_fasta {
    my ($self) = @_;
    return $self->refs->[0];
}

has 'bam_file' => (is         => 'ro',
                   isa        => 'Str',
                   lazy_build => 1,);

sub _build_bam_file {
    my $self = shift;
    return $self->input_files->[0];
}

has 'transcriptome' => (is         => 'ro',
                        isa        => 'Maybe[Str]',
                        lazy_build => 1,);

sub _build_transcriptome {
    my $self = shift;
    my $trans_gtf = $self->rnaseqc_gtf_file;
    return $trans_gtf;
}

sub _command {
    my ($self, $dir_out) = @_;

    my $single_end_option=q[];
    if(!npg::api::run->new({id_run => $self->id_run})->is_paired_read()){
        $single_end_option=q[-singleEnd];
    }
    my $command = $self->java_cmd. sprintf q[ -Xmx%s -XX:%s -XX:%s -jar %s -s %s -o %s -r %s -t %s -ttype %d %s],
                                           $self->java_max_heap_size,
                                           $self->java_gc_type,
                                           $self->java_use_perf_data,
                                           $self->java_jar_path,
                                           $self->input_str,
                                           $dir_out,
                                           $self->reference_fasta,
                                           $self->transcriptome,
                                           $self->transcript_type,
                                           $single_end_option;
    return $command;
}

has 'config_file_loc' => (is         => 'ro',
                          isa        => 'Str',
                          lazy_build => 1,);

override 'can_run' => sub {
    my $self = shift;
    my $l = $self->lims;
    if(!$self->alignments_in_bam) {
        $self->messages->push('alignments_in_bam is false');
        return 0;
    }
    if (!$l->library_type || $l->library_type !~ /(?:cD|R)NA/sxm) {
        $self->messages->push('Not RNA library type');
        return 0;
    }
    if((not $l->reference_genome) or (not $l->reference_genome =~ /Homo_sapiens|Mus_musculus/smx)){
        $self->messages->push('Not human or mouse (so skipping RNA-SeQC analysis for now');
        return 0;
    }
    if(not $self->transcriptome_index_name()){
        $self->messages->push('Not transcriptome set so no splice junction alignment');
        return 0;
    }
    return 1;
};

override 'execute' => sub {
    my ($self) = @_;
    
    if (super() == 0) {
    	return 1;
    }

    if ($self->messages->count) {
        $self->result->add_comment(join q[ ], $self->messages->messages);
    }

    my $can_run = $self->can_run();

    if (!$can_run) {
    	return 1;
    }
    
    my $rna_seqc_dir = join q[_], $self->id_run, $self->position;
    if (defined $self->tag_index) {
      $rna_seqc_dir .= $self->tag_label;
    }
    $rna_seqc_dir = join q[/], $self->qc_out, $rna_seqc_dir;
    if (!-e $rna_seqc_dir) {
      if (!mkdir $rna_seqc_dir) {
         #catch $_, exit 
      }
    } 

    #TODO: Directory making lines might be deleted in the future
    #      if it's decided they should go to the same place tileviz
    #      is created (npg_pipeline::base).
    #---------------------------------------------------------------------------------------------
    # check existence of rna_seqc directory
    # create if it doesn't
    #if ( ! -d $rna_seqc_dir) {
    #    my $mk_rna_seqc_dir_cmd = qq{mkdir -p $rna_seqc_dir};
    #    my $return = qx{$mk_rna_seqc_dir_cmd};
    #    if ( $CHILD_ERROR ) {
    #        croak $rna_seqc_dir . qq{ does not exist and unable to create: $CHILD_ERROR\n$return};
    #    }
    #}
    #TODO: delete up to here ---------------------------------------------------------------------

    $self->result->set_info('Jar', qq[RNA-SeqQC $RNASEQC_JAR_NAME]);
    $self->result->set_info('Jar_version', $RNASEQC_JAR_VERSION);
    $self->result->set_info('Command', $self->command);

    my $command = $self->_command($rna_seqc_dir);

    if (system $command) {
        carp "Failed to execute $command";
    }

    #TODO: Call to _parse_metrics(<metrics.tsv file handler>)
    #      my $results = $self->_parse_metrics($fh);
    #$self->result->rnaseqc_metrics_path($self->output_dir);

    return 1;
};


#TODO: Parse metrics file. No need to parse the output or RNA-SeQC. 
#      Leave a half-baked stub for future use.
#sub _parse_metrics {
#    my ($self, $fh) = @_;
#
#    if (!$fh) {
#        croak q[File handle is not available, cannot parse rna-seqc metrics];
#    }
#
#    my @lines = ();
#
#    while (my $line = <$fh>) {
#        chomp $line;
#        push @lines, $line;
#    }
#
#    close $fh or croak qq[Cannot close pipe in __PACKAGE__ : $ERRNO, $CHILD_ERROR];
#
#    my @keys = split /\t/smx, $lines[0];
#    my @values = split /\t/smx, $lines[1];
#    my $num_keys = scalar @keys;
#    my $num_values = scalar @values;
#    if ($num_keys != $num_values) {
#        croak qq[Mismatch in number of keys and values, $num_keys agains $num_values];
#    }
#
#    my $results = {};
#    my $i = 0;
#    while ($i < $num_keys) {
#        if ($keys[$i]) {
#            my $value = $values[$i] || undef;
#            $results->{$keys[$i]} = $value;
#    }
#        $i++;
#    }
#
#    return $results;
#}


__PACKAGE__->meta->make_immutable();

1;

__END__


=head1 NAME

npg_qc::autoqc::checks::rna_seqc - a QC check that runs RNA-SeQC software over an RNA-Seq sample 

=head1 SYNOPSIS

=head1 DESCRIPTION


=head1 SUBROUTINES/METHODS

=head2 new

    Moose-based.

=head2 alignments_in_bam

=head2 java_max_heap_size

=head2 rnaseqc_jar_path

=head2 rnaseqc_command

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

=item File::Spec

=item File::Basename

=item npg_qc::autoqc::types

=item npg::api::run
 
=item Readonly

=item Try::Tiny

=item npg_tracking::data::reference::find

=item npg_common::roles::software_location

=item npg_tracking::data::transcriptome::find

=back

=head1 AUTHOR

Ruben E Bautista-Garcia<lt>rb11@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2012 GRL, by Ruben Bautista

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

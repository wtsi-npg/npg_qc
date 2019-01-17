package npg_qc::autoqc::checks::mapd;

use Moose;
use Carp;
use DateTime;
use English qw( -no_match_vars );
use File::Path qw( make_path );
use File::Spec;
use File::Share ':all';
use IPC::Run3 qw(run3);
use Readonly;
use npg_tracking::util::types;

extends qw(npg_qc::autoqc::checks::check);

our $VERSION = '0';

Readonly::Scalar our $EXT => q[cram];
Readonly::Scalar our $EXIT_CODE_SHIFT => 8;

Readonly::Scalar my $ZERO => 0;
Readonly::Scalar my $TWO => 2;
Readonly::Scalar my $THREE => 3;
Readonly::Scalar my $FIVE => 5;
Readonly::Scalar my $MINUS_ONE => -1;
Readonly::Scalar my $SAM_SEQ_COLUMN_INDEX => 9;
Readonly::Scalar my $MAPD_OUTPUT_DIR => '_MAPD_%s';
Readonly::Scalar my $BIN_COUNTS_FILE => '%s_%d_mappable_%dbases.count';
Readonly::Scalar my $LOGR_SEGMENTS_FILE => '%s-logr_segmentation-%d_%dbases_%dgamma.txt';
Readonly::Scalar my $MAPD_RESULTS_FILE => '%s-mapd_results-%d_%dbases_%.1fthreshold.txt';
Readonly::Scalar my $RSCRIPTS_DIR => 'rscripts';
Readonly::Scalar my $LOGR_RSCRIPT_FILE => 'LogR.R';
Readonly::Scalar my $MAPD_RSCRIPT_FILE => 'MAPD.R';
Readonly::Scalar my $THRESHOLD_SCORE_HUMAN => 0.3;
Readonly::Scalar my $THRESHOLD_SCORE_MOUSE => 0.6;
Readonly::Array my @BIN_COUNTS_HEADER => qw/chromosome start end mappable size test ref/;
Readonly::Hash my %MAPD_RESULTS_FIELDS_MAPPING => {
    'MAPD' => 'mapd_score',
};

has '+file_type' => (default => $EXT,);

has 'bin_size' => (
    isa => 'Num',
    is => 'ro',
    required => 1,
);

has 'read_length' => (
    isa => 'Num',
    is => 'ro',
    required => 0,
    lazy_build => 1,
);

has 'mappable_bins_file' => (
    isa => 'NpgTrackingReadableFile',
    is => 'ro',
    required => 0,
    lazy_build => 1,
);

has 'mappable_bins_bed_file' => (
    isa => 'NpgTrackingReadableFile',
    is => 'ro',
    required => 0,
    lazy_build => 1,
);

has 'bam_file' => (
    is => 'ro',
    isa => 'NpgTrackingReadableFile',
    lazy_build    => 1,
);

has 'gamma' => (
    isa => 'Num',
    is => 'ro',
    required => 0,
    default => 25,
);

has 'threshold' => (
    isa => 'Num',
    is => 'ro',
    required => 0,
    lazy_build => 1,
);

has '_mapd_output_dir' => (
    isa => 'Str',
    is => 'ro',
    required => 0,
    lazy_build => 1,
);

has '_bin_counts_file' => (
    isa => 'Str',
    is => 'ro',
    required => 0,
    lazy_build => 1,
);

has '_logr_segmentation_file' => (
    isa => 'Str',
    is => 'ro',
    required => 0,
    lazy_build => 1,
);

has '_mapd_results_file' => (
    isa => 'Str',
    is => 'ro',
    required => 0,
    lazy_build => 1,
);

has '_rscripts_path' => (
    isa => 'Str',
    is => 'ro',
    required => 0,
    lazy_build => 1,
);

has '_sample_name' => (
    is => 'ro',
    isa => 'Str',
    lazy_build => 1,
    init_arg => undef,
);

has '_results' => (
    traits  => ['Hash'],
    isa     => 'HashRef',
    is      => 'ro',
    default => sub { {} },
    handles => {
        _set_result    => 'set',
        _get_result    => 'get',
        _delete_result => 'delete',},
);

with 'npg_common::roles::software_location' => {tools => [qw/Rscript coverageBed samtools/]};

with 'npg_tracking::data::mapd::find';

override 'can_run' => sub {
    my $self = shift;
    if (! defined $self->threshold) {
        $self->result->add_comment(q[No threshold score defined for this species]);
        return 0;
    }
    if (! $self->coverageBed_cmd) {
        $self->result->add_comment(q[coverageBed command cannot be executed]);
        return 0;
    }
    if (! $self->_logr_cmd) {
        $self->result->add_comment(q[LogR command cannot be executed]);
        return 0;
    }
    if (! $self->_mapd_cmd) {
        $self->result->add_comment(q[MAPD command cannot be executed]);
        return 0;
    }
    return 1;
};

override 'execute' => sub {
    my $self = shift;
    super();
    if (! $self->can_run) {
        my $can_run_message = q[MAPD score cannot be obtained for this bam file];
        $self->result->add_comment($can_run_message);
        return 1;
    }
    return 1 if !$self->_run_make_path($self->_mapd_output_dir);
    # Process input bam to generate
    # counts per mappable bin:
    $self->_generate_bin_counts;
    # Run LogR with bin counts file
    $self->_run_logr;
    # Run MAPD with LogR output
    if ($self->_run_mapd) {
        $self->_parse_mapd_results();
    };
    $self->_save_results();
    return 1;
};

sub _build_read_length {
    my $self = shift;
    my $read_length;
    my $command = $self->samtools_cmd . ' view '. $self->bam_file . ' 2>/dev/null |';
    my $ph = IO::File->new($command) or croak qq[Cannot fork '$command', error $ERRNO];
    my $line = $ph->getline;
    my @components = split /\t/smx, $line;
    $read_length = length $components[$SAM_SEQ_COLUMN_INDEX];
    $ph->close();
    return $read_length;
}

sub _build_mappable_bins_file {
    my $self = shift;
    return $self->mappability_file;
}

sub _build_mappable_bins_bed_file {
    my $self = shift;
    return $self->mappability_bed_file;
}

sub _build_bam_file {
    my $self = shift;
    return $self->input_files->[0];
}

sub _build_threshold {
    my $self = shift;
    my ($organism, $strain) = $self->parse_reference_genome($self->lims->reference_genome);
    if ($organism =~ /Homo_sapiens/smx) {
        return $THRESHOLD_SCORE_HUMAN;
    } elsif ($organism =~ /Mus_musculus/smx) {
        return $THRESHOLD_SCORE_MOUSE;
    }
    return;
}

sub _build__mapd_output_dir {
    my $self = shift;
    my $dir_name = sprintf $MAPD_OUTPUT_DIR, $self->result->filename_root;
    my $output_dir = File::Spec->catdir($self->qc_out, $dir_name);
    return $output_dir;
};

sub _build__bin_counts_file {
    my $self = shift;
    my $file_name = sprintf $BIN_COUNTS_FILE, $self->_sample_name, $self->bin_size, $self->read_length;
    return File::Spec->catfile($self->_mapd_output_dir, $file_name);
}

sub _build__logr_segmentation_file {
    my $self = shift;
    my $file_name = sprintf $LOGR_SEGMENTS_FILE, $self->_sample_name, $self->bin_size, $self->read_length, $self->gamma;
    return File::Spec->catfile($self->_mapd_output_dir, $file_name);
}

sub _build__mapd_results_file {
    my $self = shift;
    my $file_name = sprintf $MAPD_RESULTS_FILE, $self->_sample_name, $self->bin_size, $self->read_length, $self->threshold;
    return File::Spec->catfile($self->_mapd_output_dir, $file_name);
}

sub _build__rscripts_path {
    my $self = shift;
    my $share_dir = dist_dir(__PACKAGE__);
    my $rscripts_path = File::Spec->catdir($share_dir, $RSCRIPTS_DIR);
    return $rscripts_path;
}

sub _build__sample_name {
    my $self = shift;
    my $sample_id = $self->lims->sample_id;
    my $sample_name = $self->lims->sample_name // $sample_id;
    my @sample_names = split q[ ], $sample_name;
    return $sample_names[0];
}

sub _run_make_path {
    my $self = shift;
    my $path = shift;
    if (! -d $path ) {
        eval {
            make_path($path) or croak qq[cannot make_path $path: $CHILD_ERROR];
            1;
        } or do {
            carp qq[cannot make_path $path: $EVAL_ERROR];
            return 0;
        };
    }
    return 1;
}

sub _chrom_sort {
    my @a = split /\t/smx, $a;
    my @b = split /\t/smx, $b;
    my $number_a;
    my $letter_a = $a[0];
    my $number_b;
    my $letter_b = $b[0];
    if ($a[0] =~ /^\d+$/smx) {
        $number_a = $a[0];
    }
    if ($b[0] =~ /^\d+$/smx) {
        $number_b = $b[0];
    }
    # Compare and return
    if (defined $number_a && defined $number_b){
        return $number_a <=> $number_b || $a[1] <=> $b[1];
    } elsif (defined $letter_a && defined $letter_b) {
        return $letter_a cmp $letter_b || $a[1] <=> $b[1];
    }
    return;
}

sub _generate_bin_counts {
    my $self = shift;
    my $reads = 0;
    #--------------------
    # get unique hits
    my $view_cmd = $self->samtools_cmd. q[ view -F 3332 -q 20 ]. $self->bam_file. q[ | ];
    carp q[EXECUTING ]. $view_cmd. q[ time ]. DateTime->now();
    my $ph = IO::File->new($view_cmd) or croak qq[Cannot fork '$view_cmd', error $ERRNO];
    my @view_out;
    while (my $line = <$ph>) {
        if ($line !~ /XA:Z/smx) {
            my @read = split /\t/smx, $line;
            my $rname = $read[$TWO];
            my $pos = $read[$THREE];
            push @view_out, (join qq[\t], $rname, $pos, $pos). qq[\n];
            $reads += 1;
        }
    }
    $ph->close();
    #--------------------
    # run bin coverage
    my $bed_cmd = [$self->coverageBed_cmd, q[-a], q[-], q[-b], $self->mappable_bins_bed_file];
    my @bed_out;
    carp q[EXECUTING ]. (join q[ ], @{$bed_cmd}). q[ time ]. DateTime->now();
    run3 $bed_cmd, \@view_out, \@bed_out;
    #--------------------
    # sort by chromosome
    my @sorted = sort _chrom_sort @bed_out;
    my $fh = IO::File->new($self->_bin_counts_file, 'w');
    print {$fh} (join qq[\t], @BIN_COUNTS_HEADER). qq[\n]; ## no critic (RequireCheckedSyscalls)
    foreach my $sort_line (@sorted) {
        my @rec = split /\t/smx, $sort_line;
        print {$fh} (join qq[\t], @rec[0..$FIVE], $ZERO). qq[\n]; ## no critic (RequireCheckedSyscalls)
    }
    $fh->close();
    return $reads;
}

sub _find_rscript {
    my ($self, $file) = @_;
    my $rscripts_path = $self->_rscripts_path;
    my (@files, $rscript_file);
    if ($rscripts_path) {
        @files = glob $rscripts_path . q[/*.R];
    }
    if (-d $rscripts_path) {
        if (scalar @files == 0) {
            $self->messages->push(q[Directory ]. $rscripts_path.
                                  q[ exists, but no *.R files exist]);
            return;
        } else {
            $rscript_file = File::Spec->catfile($self->_rscripts_path, $file);
            if (! -e $rscript_file) {
                $self->messages->push(q[Rscript file ]. $rscript_file.
                                      q[ not found in ]. $rscripts_path);
                return;
            }
        }
    }
    return $rscript_file;
}

sub _logr_cmd {
    my $self = shift;
    my $rscript_executable = $self->Rscript_cmd();
    my $rscript_file = $self->_find_rscript($LOGR_RSCRIPT_FILE);
    my $command = $rscript_executable.
                  sprintf q[ %s ].
                          q[--mappable_bins %s ].
                          q[--sample_bin_counts %s ].
                          q[--output_dir %s ].
                          q[--rscripts_dir %s ]. # where to find auxiliary R scripts
                          q[--chromosomes %s ].
                          q[--bin_size %d ].
                          q[--sample_name %s ].
                          q[--read_length %d ].
                          q[--gamma %d],
                          $rscript_file,
                          $self->mappable_bins_file,
                          $self->_bin_counts_file,
                          $self->_mapd_output_dir,
                          $self->_rscripts_path,
                          $self->chromosomes_file,
                          $self->bin_size,
                          $self->_sample_name,
                          $self->read_length,
                          $self->gamma;
    return $command;
}

sub _run_logr {
    my $self = shift;
    my $logr_cmd = $self->_logr_cmd;
    carp qq[EXECUTING $logr_cmd time ]. DateTime->now();
    if (system $logr_cmd) {
        my $error = $CHILD_ERROR >> $EXIT_CODE_SHIFT;
        croak sprintf "Child %s exited with value %d\n", $logr_cmd, $error;
    }
    return 1;
}

sub _mapd_cmd {
    my $self = shift;
    my $rscript_executable = $self->Rscript_cmd();
    my $rscript_file = $self->_find_rscript($MAPD_RSCRIPT_FILE);
    my $command = $rscript_executable.
                  sprintf q[ %s ].
                          q[--logr_segmentation_file %s ].
                          q[--output_dir %s ].
                          q[--chromosomes %s ].
                          q[--threshold %.1f ].
                          q[--bin_size %d ].
                          q[--sample_name %s ].
                          q[--read_length %d],
                          $rscript_file,
                          $self->_logr_segmentation_file,
                          $self->_mapd_output_dir,
                          $self->chromosomes_file,
                          $self->threshold,
                          $self->bin_size,
                          $self->_sample_name,
                          $self->read_length;
    return $command;
}

sub _run_mapd {
    my $self = shift;
    my $mapd_cmd = $self->_mapd_cmd;
    carp qq[EXECUTING $mapd_cmd time ]. DateTime->now();
    if (system $mapd_cmd) {
        my $error = $CHILD_ERROR >> $EXIT_CODE_SHIFT;
        croak sprintf "Child %s exited with value %d\n", $mapd_cmd, $error;
    }
    return 1;
}

sub _parse_mapd_results {
    my $self = shift;
    my $filename = $self->_mapd_results_file;
    if (! -e $filename) {
        croak qq[No such file $filename: cannot parse MAPD results];
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

sub _save_results {
    my $self = shift;
    foreach my $key (keys %MAPD_RESULTS_FIELDS_MAPPING) {
        my $value = $self->_get_result($key);
        if (defined $value) {
            my $attr_name = $MAPD_RESULTS_FIELDS_MAPPING{$key};
            if ($value eq q[NaN]) {
                carp qq[Value of $attr_name is 'NaN', skipping...];
            } else {
                $self->result->$attr_name($value);
            }
        }
        $self->_delete_result($key);
    }
    return;
}


__PACKAGE__->meta->make_immutable();

1;

__END__

=head1 NAME

npg_qc::autoqc::checks::mapd

=head1 SYNOPSIS

=head1 DESCRIPTION

Generate MAPD value for sample input file

=head1 SUBROUTINES/METHODS

=head2 read_length

=head2 mappable_bins_file

=head2 mappable_bins_bed_file

=head2 bam_file

=head2 gamma

Gamma, penalty parameter used during logR and copy number calculations. For
lower binsize e.g. 50kb, 100kb, suggested gamma parameter is 25 (preferred)
or more and for higher binsize e.g. 250kb, 500kb suggested gamma parameter
is 15, 10 or lower. Please choose the best gamma parameter fitting to your
data.

=head2 threshold

Used in the MAPD process. Suggested values are 0.3 for human and 0.6 for mouse.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Carp

=item DateTime

=item English

=item File::Path

=item File::Spec

=item File::Share

=item IPC::Run3

=item Readonly

=item npg_tracking::util::types

=item npg_qc::autoqc::checks::check

=item npg_tracking::data::reference::find

=item npg_tracking::data::mapd::find

=item npg_common::roles::software_location

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Ruben E Bautista-Garcia<lt>rb11@sanger.ac.uk<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2019 Genome Research Limited

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

#########
# Author:        Aylwyn Scally
# Created:       2008-11-26
#
#

package npg_qc::autoqc::checks::gc_bias;

use strict;
use warnings;
use Moose;
use Carp;
use English qw(-no_match_vars);
use Fatal qw(open close);
use File::Basename;
use List::Util qw(max);
use Readonly;
use Try::Tiny;

use npg_tracking::util::types;

our $VERSION = '0';

extends qw(npg_qc::autoqc::checks::check);
with qw(npg_tracking::data::reference::find
        npg_common::roles::software_location);

Readonly::Scalar my $MINIMUM_WINDOW_SIZE        =>     100;
Readonly::Scalar my $TARGET_WINDOW_COUNT        => 150_000;
Readonly::Scalar my $SHIFT_EIGHT                => 8;
Readonly::Scalar my $SAM_FILE_NUM_COLUMNS       => 11;
Readonly::Scalar my $SAM_FILE_SEQ_COLUMN_INDEX  => 9;
Readonly::Scalar my $SIG_PIPE_FATAL_ERROR       => 141;

Readonly::Scalar our $EXT                => 'bam';


has '+input_file_ext' => (default    => $EXT,);
has '+aligner'        => (default    => q[fasta],);

has 'r_executable'  =>      ( is         => 'ro',
                              isa        => 'NpgCommonResolvedPathExecutable',
                              required   => 0,
                              coerce     => 1,
                              default    => q[R],
                            );

has 'bam_file'       => ( is         => 'ro',
                          isa        => 'NpgTrackingReadableFile',
                          lazy_build => 1,
);
sub _build_bam_file {
    my $self = shift;
    return $self->input_files->[0];
}

has 'stats_file'     => ( is         => 'ro',
                          isa        => 'Maybe[Str]',
                          lazy_build => 1,
);
sub _build_stats_file {
    my $self = shift;
    my $filename = $self->bam_file;
    $filename =~ s/\.bam/_F0x900.stats/smx;
    return $filename;
}


has 'reference_base' => ( is         => 'ro',
                          isa        => 'Maybe[Str]',
                          lazy_build => 1,
);
sub _build_reference_base {
    my $self = shift;
    return $self->refs->[0];
}

has 'read_length'    => (is         => 'ro',
                         isa        => 'Maybe[Int]',
                         lazy_build => 1,
			);

sub _build_read_length {
    my $self = shift;

    ## no critic (ProhibitTwoArgOpen ErrorHandling::RequireCheckingReturnValueOfEval)
    my $read_length;
    my $bfile = $self->bam_file;
    my $command = q[/bin/bash -c "set -o pipefail && ] . $self->samtools_cmd . qq[ view $bfile | head -n 1" | ];
    open my $ph, $command or croak qq[Cannot fork '$command', error $ERRNO];
    my $line = <$ph>;
    if ($line) {
        my @components = split /\t/smx, $line;
        if(scalar @components < $SAM_FILE_NUM_COLUMNS) {
            croak qq[First read "$line" of $bfile does not have correct number of records];
	}
        $read_length = length $components[$SAM_FILE_SEQ_COLUMN_INDEX];
    }
    eval { close $ph; };
    #The exit status of the pipe is always 141 since the head command exits before samtools
    my $child_error = $CHILD_ERROR >> $SHIFT_EIGHT;
    if ($child_error != 0 && $child_error != $SIG_PIPE_FATAL_ERROR) {
        croak qq[Error in pipe "$command": $child_error];
    }
    return $read_length;
}

override 'execute' => sub {
    my ($self) = @_;

    return 1 if super() == 0;

    if (!$self->read_length) {
        $self->result->add_comment('Bam file has no reads.');
        return 1;
    }

    if ( !-e $self->stats_file ) {
        $self->result->add_comment(q[No stats file ] . $self->stats_file);
        return 1;
    }


    my $gcpercent = [];
    my $pc_us = [];
    my $pc_10 = [];
    my $pc_25 = [];
    my $pc_50 = [];
    my $pc_75 = [];
    my $pc_90 = [];

    open my $fh, q{<}, $self->stats_file;
    while (<$fh>) {
        chomp;
        my @row = split /\t/;
        if ($row[0] eq 'GCD') {
            if ($row[2] > 0.1 and $row[2] < 99.9) {
                push $gcpercent, $row[1];
                push $pc_us, $row[2];
                push $pc_10, $row[3];
                push $pc_25, $row[4];
                push $pc_50, $row[5];
                push $pc_75, $row[6];
                push $pc_90, $row[7];
            }
        }
    }
    close $fh;
    $self->result->gcpercent($gcpercent);
    $self->result->pc_us($pc_us);
    $self->result->pc_10($pc_10);
    $self->result->pc_25($pc_25);
    $self->result->pc_50($pc_50);
    $self->result->pc_75($pc_75);
    $self->result->pc_90($pc_90);

    return 1;
};

no Moose;
__PACKAGE__->meta->make_immutable();

1;
__END__


=head1 NAME

npg_qc::autoqc::checks::gc_bias - assess the degree of gc_bias in reads
    aligned to the reference.

=head1 SYNOPSIS

    use npg_qc::autoqc::checks::gc_bias;


=head1 DESCRIPTION


=head1 SUBROUTINES/METHODS

=head2 find_R_library

    To avoid additional configuration steps (usually creating ~/.Rprofile) the
    R library is included with the perl modules. Find it by traversing up the
    path to this module until the directory 'lib' is found, then descend to
    'R/gc_bias_data.R'.

=head1 DIAGNOSTICS

    None.

=head1 CONFIGURATION AND ENVIRONMENT

=head1 INCOMPATIBILITIES

    None known.

=head1 BUGS AND LIMITATIONS

=head1 DEPENDENCIES

=head1 AUTHOR

    John O'Brien, jo3

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by John O'Brien

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

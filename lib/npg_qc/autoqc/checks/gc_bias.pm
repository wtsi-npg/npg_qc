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
use File::Slurp;
use List::Util qw(max);
use MIME::Base64::Perl;
use Perl6::Slurp;
use POSIX qw(WIFEXITED);
use Readonly;

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

has 'window_depth_cmd'  =>  ( is         => 'ro',
                              isa        => 'NpgCommonResolvedPathExecutable',
                              required   => 0,
                              coerce     => 1,
                              default    => q[window_depth],
                            );

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

has 'reference_base' => ( is         => 'ro',
                          isa        => 'Maybe[Str]',
                          lazy_build => 1,
);
sub _build_reference_base {
    my $self = shift;
    return $self->refs->[0];
}

has 'window_size'    => ( is         => 'ro',
                          isa        => 'Int',
                          lazy_build => 1,
);
sub _build_window_size {
    my $self = shift;
    my $reference_size = -s $self->reference_base();
    return $self->_select_window_size($reference_size);
}

has '_bam_is_aligned'=> (is          => 'ro',
                         isa         => 'Bool',
                         lazy_build => 1,
                        );
sub _build__bam_is_aligned {
    my $self = shift;

    ## no critic (ProhibitTwoArgOpen ErrorHandling::RequireCheckingReturnValueOfEval)
    my $command = $self->samtools_cmd . ' view -H ' . $self->bam_file . ' |';
    open my $ph, $command or croak qq[Cannot fork '$command', error $ERRNO];
    my $aligned = 0;
    while (my $line = <$ph>) {
      if (!$aligned && $line =~ /^\@SQ/smx) {
	$aligned = 1;
      }
    }
    eval { close $ph; };
    my $child_error = $CHILD_ERROR >> $SHIFT_EIGHT;
    if ($child_error != 0) {
        croak qq[Error in pipe "$command": $child_error];
    }
    return $aligned;
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

has 'gcn_file'       => ( is         => 'ro',
                          isa        => 'Str',
                          lazy_build => 1,
);
sub _build_gcn_file {
    my $self = shift;
    my $reference_gcn = $self->reference_base();
    $reference_gcn =~ s{/fasta/}{/npgqc/}msx;
    $reference_gcn .= q{.gcn} . $self->window_size();
    return $reference_gcn;
}

override 'execute' => sub {
    my ($self) = @_;

    return 1 if super() == 0;

    if (!$self->read_length) {
        $self->result->add_comment('Bam file has no reads.');
        return 1;
    }

    if (!$self->_bam_is_aligned) {
        $self->result->add_comment('Bam file is not aligned.');
        return 1;
    }

    if ( !-e $self->gcn_file ) {
        $self->result->add_comment(q[No gcn file ] . $self->gcn_file);
        return 1;
    }

    $self->result->window_size($self->window_size);

    my $tempdir         = $self->tmp_path();
    my ($bam_name, $xpath, $xsuffix) = fileparse($self->bam_file);
    my $output_basename = $tempdir . q{/} . $bam_name;
    my $plot_png        = $output_basename . q{-gc_bias.png};
    my $parameter_file  = $output_basename . q{-gcdepth.txt};
    my $depth_out       = $output_basename . q{.depth};

    my $depth_command = $self->samtools_cmd . q{ view } . $self->bam_file() . q{ | } . $self->window_depth_cmd
                      .  q{ } . $self->reference_base . q{ -b=} . $self->window_size()
                      .  q{ -g=} . $self->gcn_file()
                      . qq{ > $depth_out};

    croak 'window depth failed' if !WIFEXITED( system $depth_command );

    $self->_create_gc_bias_graph($depth_out, $tempdir, $bam_name );

    # Because of building this module around inherited code we're using R to
    # calculate the various parameters for the plot, which are then being
    # written to a text file. We now have to read them from that text file.
    # This is a bit crap, and we should try to have perl calculate the
    # parameters itself.

    if ( !-r $parameter_file ) {
        $self->result->add_comment('R script failed. Data output not found.');
        return 1;
    }
    if ( !-r $plot_png ) {
        $self->result->add_comment('R script failed. Plot output not found.');
        return 1;
    }

    my $r_output = slurp $parameter_file;
    my $png_data = read_file( $plot_png, binmode => ':raw' );

    my ($max_y)        = $r_output =~ m/ DEPMAX:      \s+(.*?)\n /msx;
    my ($window_count) = $r_output =~ m/ WINDOW_COUNT:\s+(.*?)\n /msx;
    my ($bin_count)    = $r_output =~ m/ BIN_COUNT:   \s+(.*?)\n /msx;
    my ($polygon_x)    = $r_output =~ m/ POLYGON_X:   \s+(.*?)\n /msx;
    my ($polygon_y)    = $r_output =~ m/ POLYGON_Y:   \s+(.*?)\n /msx;
    my ($gc_tickmark)  = $r_output =~ m/ GC_TICKMARK: \s+(.*?)\n /msx;
    my ($main_plot_x)  = $r_output =~ m/ MAIN_PLOT_X: \s+(.*?)\n /msx;
    my ($main_plot_y)  = $r_output =~ m/ MAIN_PLOT_Y: \s+(.*?)\n /msx;
    my ($lower_poiss)  = $r_output =~ m/ LOWER_POISS: \s+(.*?)\n /msx;
    my ($upper_poiss)  = $r_output =~ m/ UPPER_POISS: \s+(.*?)\n /msx;

    $self->result->max_y(        $max_y        + 0 );
    $self->result->window_count( $window_count + 0 );
    $self->result->bin_count(    $bin_count    + 0 );
    $self->result->actual_quantile_x(    [ split m/,/msx, $polygon_x ] );
    $self->result->actual_quantile_y(    [ split m/,/msx, $polygon_y ] );
    $self->result->gc_lines(             [ split m/,/msx, $gc_tickmark ] );
    $self->result->plot_x(               [ split m/,/msx, $main_plot_x ] );
    $self->result->plot_y(               [ split m/,/msx, $main_plot_y ] );
    $self->result->ideal_lower_quantile( [ split m/,/msx, $lower_poiss ] );
    $self->result->ideal_upper_quantile( [ split m/,/msx, $upper_poiss ] );
    $self->result->cached_plot( encode_base64($png_data) );

    return 1;
};

sub _select_window_size {
    my ( $self, $reference_size ) = @_;

    my $window_size = max( $self->read_length,
                           $MINIMUM_WINDOW_SIZE,
                           $reference_size / $TARGET_WINDOW_COUNT );
    return _up_nearest($window_size);
}

sub _up_nearest {
    my ($number) = @_;
    $number = 0 + $number;
    return 0 if !$number;

    my $factor = $number <=> 0;
    $number = abs $number;

    ## no critic (ValuesAndExpressions::ProhibitMagicNumbers)
    while ( $number >= 10 ) { $number /= 10; $factor *= 10; }
    while ( $number <   1 ) { $number *= 10; $factor /= 10; }

    ## use critic
    return ( int($number) == $number ? $number : ( int($number) + 1 ) )
           * $factor;
}

sub _create_gc_bias_graph {
    my ( $self, $bindepth_file, $output_path, $plot_name) = @_;

    local $ENV{R_PROFILE_USER} = $ENV{HOME} . q{/.Rprofile};

    my $r_file      = $bindepth_file . q{.R};
    $output_path = $output_path . q[/];
    my $r_lib = $self->find_R_library();

    # Create the R script and run the command.
    open my $fh, q{>}, $r_file;

    print {$fh} qq[source('$r_lib')\n],
                qq[depdat = read.depth('$bindepth_file')\n],
                qq[gcdepth(depdat, plot_name = '$plot_name', depmax = NULL,],
                 q[        nbins = 30, plotdev = bitmap, binned = TRUE,],
                qq[        path = '$output_path', make_plot = TRUE)\n]
        || croak $OS_ERROR;

    close $fh;

    my $plot_command = qq{cat $r_file | } . $self->r_executable . q{ --slave --no-save --no-site-file --no-restore};

    croak "Calculate plot data failed: $OS_ERROR"
        if !WIFEXITED( system $plot_command );

    unlink $r_file;

    return;
}

sub find_R_library {    ## no critic (NamingConventions::Capitalization)
    my ($self) = @_;

    my @path_bits = split m{/}msx, dirname(__FILE__);

    while ( scalar @path_bits > 0 ) {
        last if $path_bits[-1] eq 'lib';
        pop @path_bits;
    }

    if ( scalar @path_bits == 0 ) {
        $self->result->add_comment('Parent \'lib/R\' directory not found for R script');
    }

    my $path_to_R_lib = join q{/}, @path_bits; ## no critic (NamingConventions::Capitalization)
    $path_to_R_lib .= q{/R/gc_bias_data.R};

    return $path_to_R_lib;
}

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

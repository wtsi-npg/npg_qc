package npg_qc::autoqc::checks::ref_match;

use Moose;
use Carp;
use English qw(-no_match_vars);
use File::Basename qw(fileparse);
use File::Spec::Functions qw(catfile);
use DateTime;
use namespace::autoclean;
use List::Util qw(shuffle);
use Readonly;

use npg_tracking::util::abs_path qw(abs_path);
use npg_common::extractor::fastq qw/generate_equally_spaced_reads split_reads/;
extends 'npg_qc::autoqc::checks::check';
with    qw/npg_tracking::data::reference::list
           npg_common::roles::software_location
          /;

our $VERSION = '0';

Readonly::Scalar my $UNMAPPED_FLAG      =>      4;
Readonly::Scalar my $SAMPLE_READ_LENGTH =>     37;
Readonly::Scalar my $MIN_SAMPLE_READ_LENGTH => 28;
Readonly::Scalar my $SAMPLE_READ_COUNT  => 10_000;
Readonly::Hash   my %ALIGNER_OPTIONS    => (
    bowtie => q{--quiet --sam --sam-nohead %ref% %reads%},
    smalt  => q{map -f sam %ref% %reads%},
);

has 'aligner' => (
    is            => 'ro',
    isa           => 'Str',
    default       => 'bowtie',
);

has 'aligner_cmd' => (
    is            => 'ro',
    isa           => 'Str',
    lazy_build    => 1,
);
sub _build_aligner_cmd {
  my $self = shift;
  my $attr = join q[_], $self->aligner, q[cmd];
  return $self->$attr;
}

has 'aligner_options' => (
    is            => 'ro',
    isa           => 'Str',
    lazy_build    => 1,
);
sub _build_aligner_options {
    my ($self) = @_;
    my $aligner = $self->aligner();
    return ( exists $ALIGNER_OPTIONS{$aligner} )
        ? $ALIGNER_OPTIONS{$aligner}
        : q{};
}

has read1_fastq => (
    is            => 'ro',
    isa           => 'Str',
    lazy_build    => 1,
);

sub _build_read1_fastq {
    my ($self) = @_;
    return $self->input_files->[0];
}

has 'temp_fastq'  => (
    is            => 'rw',
    isa           => 'Str',
    lazy_build    => 1,
);

sub _build_temp_fastq {
    my ($self) = @_;
    return catfile( $self->tmp_path(), q[temp.fastq] );
}


has 'sample_read_length' => (
    is            => 'ro',
    isa           => 'Int',
    default       => $SAMPLE_READ_LENGTH,
);


has 'sample_read_count'  => (
    is            => 'ro',
    isa           => 'Int',
    default       => $SAMPLE_READ_COUNT,
);


has 'request_list' => (
    is            => 'rw',
    isa           => 'ArrayRef[Str]',
    default       => sub { return []; },
    documentation => 'Use these organisms - *if* we have the aligner index.',
);

has 'organism_list' => (
    is            => 'rw',
    isa           => 'ArrayRef[Str]',
    init_arg      => undef,
    documentation => 'The list of organisms that will actually be checked.',
    lazy_build    => 1,
);

sub _build_organism_list {
    my ($self) = @_;
    $self->_scan_repository();
    return $self->organism_list();
}

has [ 'index_base', 'reference_version' ] => (
    is            => 'rw',
    isa           => 'HashRef[Str]',
    init_arg      => undef,
    lazy_build    => 1,
);

sub _build_index_base {
    my ($self) = @_;
    $self->_scan_repository();
    return $self->index_base();
}

sub _build_reference_version {
    my ($self) = @_;
    $self->_scan_repository();
    return $self->reference_version();
}


sub BUILD {
    my $self = shift;
    if ($self->sample_read_length < $MIN_SAMPLE_READ_LENGTH) {
        croak q[Sample read length ] . $self->sample_read_length .
              qq[ is below $MIN_SAMPLE_READ_LENGTH (lowest acceptable value)];
    }
    return;
}

# We need to know a few things about the organisms we're going to screen.
sub _scan_repository {
    my ($self) = @_;

    my $aligner = $self->aligner;
    my @request_list      = @{ $self->request_list() };
    my $have_request_list = scalar @request_list;

    my ( @organism_list, %version, %index_basename );

    my $root = $self->ref_repository();

    foreach my $organism ( @{ $self->organisms() } ) {
        next if $organism eq 'NPD_Chimera' or $organism eq 'Chlorocebus_aethiops';  # Chlorocebus_aethiops temporarily excluded (possible Strep contamination of reference)

        # Skip symlinks like 'Dog', 'Human', etc.
        my $base = catfile( $root, $organism );
        next if -l $base;

        next if $have_request_list
            && !( grep { m/^ $organism $/imsx } @request_list );

        # Only consider the 'default' version/strain.
        my $default = catfile( $base, 'default' );
        next if !-e $default;

        # Get the name of the version/strain.
        my $version = readlink $default;
        $version =~ s{/*$}{}msx;

        # Make sure the fasta directory exists.
        my $fasta_dir = abs_path(catfile( $default, 'all', 'fasta' ));
        next if !-d $fasta_dir;

        # It should contain a fasta file.
        my $fasta_path = ( glob $fasta_dir . '/*.{fasta,fa,fna}' )[0];
        next if !defined $fasta_path;

        # The name of the fasta file is the basename of the aligner index.
        my $fasta_base = fileparse($fasta_path);

        # Make sure the aligner index directory exists.
        my $aligner_dir = $fasta_dir;
        $aligner_dir =~ s{/fasta}{ q(/) . $aligner }emsx;
        next if !-d $aligner_dir;

        # Construct the basename of the index files - don't check for the
        # files, there can be multiple and it gets complicated. The aligner
        # will find out.
        my $index_base = catfile( $aligner_dir, $fasta_base );

        # Remember some details.
        $version{$organism}        = $version;
        $index_basename{$organism} = $index_base;
        push @organism_list, $organism;
    }

    @organism_list= sort @organism_list;

    $self->reference_version( \%version );
    $self->index_base( \%index_basename );
    $self->organism_list( \@organism_list );

    return;
}

override 'execute' => sub {
    my ($self) = @_;
    return 1 if !super();

    if (!$self->_create_sample_fastq()) {
        return 1;
    }

    my $count = 1;
    my @list = @{ $self->organism_list() };
    # now randomise list to avoid weird Lustre client cache slowness problem when multiple jobs on the same node read the same file at the same time
    @list = shuffle @list;
    my $num_orgs = scalar @list;

    my $report = {};

    foreach my $organism ( @list ) {
        my $command = $self->_align_command($organism);
        carp qq[EXECUTING $command, reference No $count out of $num_orgs, time ] . DateTime->now();

        local $SIG{CHLD} = sub {
            ## no critic (ProhibitMagicNumbers)
            my $child_exit_status = $CHILD_ERROR >> 8;
            ## use critic
            if ($child_exit_status != 0) {
                croak qq[Child process "$command" exited with status $child_exit_status $ERRNO];
	    }
        };

        ## no critic (ProhibitTwoArgOpen)
        open my $fh, "$command |" or croak qq[Cannot fork "$command". $ERRNO];
        ## use critic

        $report->{$organism} = $self->_parse_output($fh);
        close $fh or croak qq[Cannot close bad pipe to command "$command", error $ERRNO] ;
        $count++;
    }

    $self->result->reference_version( $self->reference_version() );
    $self->result->aligner_version($self->current_version( $self->aligner_cmd()) || q[unknown]);
    $self->result->aligned_read_count( $report );
    $self->result->set_info( 'Aligner', $self->aligner_cmd );
    if($self->aligner_options()){
      $self->result->set_info( 'Aligner_options', $self->aligner_options() );
    }

    return;
};

sub _get_read_length {
    my ($self, $fname) = @_;

    open my $fh, q[<], $fname or croak qq[Cannot open $fname for reading];
    my $err = qq[Cannot close filehandle to $fname];
    my $lane = <$fh>;
    if (!$lane) {
        close $fh or croak $err;
        croak qq[First line empty in $fname];
    }
    $lane = <$fh>;
    if (!$lane) {
        close $fh or croak $err;
        croak qq[Second line empty in $fname];
    }
    close $fh or croak $err;
    chomp $lane;
    return length $lane;
}

sub _create_sample_fastq {
    my ($self) = @_;

    my $length = $self->sample_read_length();
    my $output = $self->temp_fastq();

    my $intermediate = catfile($self->tmp_path(), q[equally_spaced_reads.fastq]);
    my $wrote = generate_equally_spaced_reads([$self->read1_fastq()], [$intermediate], $self->sample_read_count());
    if (!$wrote) {
        $self->result->add_comment($self->read1_fastq() . ' is empty');
        return 0;
    }

    # Some runs are short, as short as 18
    eval {
        split_reads($intermediate, [$length], [$output]);
        1;
    } or do {
        my $error = $EVAL_ERROR;
            if ($error !~ /is\ too\ short/smx) {
            croak $EVAL_ERROR;
        }

        $length = $self->_get_read_length($intermediate);
        if ($length <  $MIN_SAMPLE_READ_LENGTH) {
            $self->result->add_comment(qq[Read length of $length is below minimally required $MIN_SAMPLE_READ_LENGTH]);
	    return 0;
        }

        split_reads($intermediate, [$length], [$output]);
    };

    $self->result->sample_read_length($length);
    $self->result->sample_read_count($wrote);

    return $wrote;
}

sub _align_command {
    my ( $self, $organism ) = @_;

    my $options   = $self->aligner_options();
    my $reference = $self->index_base->{$organism};
    my $input     = $self->temp_fastq();

    $options =~ s/ %ref%   /$reference/msx;
    $options =~ s/ %reads% /$input/msx;
    return join q[ ], $self->aligner_cmd, $options;
}

sub _parse_output {
    my ( $self, $aln_fh) = @_;

    if (!$aln_fh) { croak q[Write handle undefined.]; }
    my $match  = 0;
    while (<$aln_fh>) {
        next if m/^ [@] /msx;    # Skip header lines.
        my ( $read, $flag ) = split;
        next if $flag & $UNMAPPED_FLAG;
        $match++;
    }
    return $match;
}

__PACKAGE__->meta->make_immutable();

1;

__END__

=head1 NAME

npg_qc::autoqc::checks::ref_match - do a contamination check
based on a sample of the sequence reads rather than the reference genomes.

=head1 SYNOPSIS

qc --position     $lane
   --archive_path $archive
   --qc_path      $qc_dir
   --check        ref_match

There are defaults for everything else, but you can override them.

qc --position           $lane
   --archive_path       $archive
   --qc_path            $qc_dir
   --check              ref_match
   --aligner            bwa
   --aligner_options    '-q 15 -t 2'
   --request_list       [ 'Homo_sapiens', 'Danio_rerio' ],
   --ref_repository     '/custom/ref/collection',
   --sample_read_count  100_000
   --sample_read_length 50

The argument '--request_list' is a list of what the user would like to align
against, but if an aligner index file for a reference in the list is not found
in the repository that reference will be silently ignored. Symlinks are
ignored at the organism level, but only the target of the 'default' symlink
will be used at the 'version/strain' level.

NPD_Chimera will always be ignored.

If the list is not supplied all references (with aligner index files) in the
repository will be used.

See the BUGS AND LIMITATIONS section for overriding the aligner.

=head1 DESCRIPTION

Takes a sample of the first N bases of a selection of M reads and aligns them
to all reference genomes in a reference genome collection.

=head1 SUBROUTINES/METHODS

=head2 execute

The main part of class. Call the other methods in the required order.

=head2 BUILD

The last method called by new() before returning a reference to a new object. Does some sanity checking.

=head1 CONFIGURATION AND ENVIRONMENT

Needs up to 2.5Gb of Memory reserved when submitted to LSF.

-M2500000 -R'select[mem>2500] rusage[mem=2500]'

=head1 INCOMPATIBILITIES

=head1 DIAGNOSTICS

=head1 DEPENDENCIES

=over

=item namespace::autoclean

=back

=head1 BUGS AND LIMITATIONS

Currently only bowtie and smalt have been tested for reliable use as aligners.

The hash %ALIGNER_OPTIONS has placeholders for the fastq files, the reference
index, and the output file. Really new entries should be added for any other
aligners required, though using a different aligner should work if
--aligner_options is specified correctly. Use of bwa will be problematic as
it's a two-step process and will require dedicated code.

=head1 AUTHOR

John O'Brien, E<lt>jo3@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2016 GRL

This program is free software: you can redistribute it and/or modify
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

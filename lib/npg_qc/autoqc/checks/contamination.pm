#########
# Author:        Original copied from /software/pathogen/projects/protocols/lib/perl5/Protocols/QC/SlxQC.pm
# Maintainer:    $Author: mg8 $
# Created:       24 September 2009
# Last Modified: $Date: 2009-10-27 09:19:10 +0000 (Tue, 27 Oct 2009) $
# Id:            $Id: contamination.pm 16882 2013-03-25 13:55:06Z mg8 $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/npg_qc/autoqc/checks/contamination.pm $

package npg_qc::autoqc::checks::contamination;

use strict;
use warnings;
use Moose;
use Carp;
use English qw(-no_match_vars);
use File::Basename;
use File::Spec::Functions qw(catfile);
use File::Glob qw(:globally :nocase);
use Perl6::Slurp;
use DateTime;
use Readonly;

use npg_common::extractor::fastq qw/read_count/;
extends qw(npg_qc::autoqc::checks::check);
with qw/npg_tracking::data::reference::find
        npg_common::roles::software_location
       /;


our $VERSION = do { my ($r) = q$Revision: 16882 $ =~ /(\d+)/smx; $r; };

Readonly::Scalar my $COMPOUND_ORGANISM_NAME => q[NPD_Chimera];
Readonly::Scalar my $PERCENT => 100;
Readonly::Scalar my $UNMAPPED_FLAG => 4;


has indexed_ref_base  => ( is            => 'ro',
                           isa           => 'Str',
                           writer        => '_set_indexed_ref_base',
);


has readme            => ( is            => 'ro',
                           isa           => 'Str',
                           writer        => '_set_readme',
);


has read1_fastq       => ( is            => 'ro',
                           isa           => 'Str',
                           lazy_build    => 1,
);
sub _build_read1_fastq {
    my $self = shift;
    return $self->input_files->[0];
}

has aligner_path      => ( is            => 'ro',
                           isa           => 'Str',
                           lazy_build    => 1,
);
sub _build_aligner_path { my $self = shift; return $self->bowtie_cmd; }

has aligner_options   => ( is            => 'ro',
                           isa           => 'Str',
                           default       =>sub {return q{--quiet --sam};},
);


override 'execute' => sub {
    my ($self) = @_;
    if (!super()) {return 1;}

    my $read_count = read_count($self->read1_fastq);
    if (!$read_count) {
        $self->result->add_comment($self->read1_fastq() . ' is empty');
        return 1;
    }

    $self->result->read_count($read_count);

    # Extrapolate a few details from the reference directory path.
    $self->reference_details();

    # Parse reference README to get genome correction factors.
    my $genome_factor = $self->parse_readme();

    my $command = join q[ ], $self->aligner_path, $self->aligner_options,
                             $self->indexed_ref_base, $self->read1_fastq;
    carp qq[EXECUTING $command, time ] . DateTime->now();

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

    my $contam = $self->parse_alignment($fh);
    close $fh or croak qq[Cannot close bad pipe to command "$command", error $ERRNO] ;

    $self->result->genome_factor($genome_factor);
    $self->result->contaminant_count($contam);
    foreach my $organism (keys %{$genome_factor}) {
        if (!exists $self->result->contaminant_count->{$organism}) {
            $self->result->contaminant_count->{$organism} = 0;
	}
    }
    $self->result->set_info( 'Aligner_options', $self->aligner_options() );

    return;
};


# The reference fasta itself is not used, but various other bits of
# information are derived from it. We use the directory rather than the fasta
# file itself to allow a 'default' symlink to be used as the default value
# that way no code changes are required when the current link is changed.
sub reference_details {
    my ($self) = @_;

    my $root = catfile($self->ref_repository, $COMPOUND_ORGANISM_NAME, $self->strain);

    # This is something that could be generalised.
    my $aligner_path = $self->aligner_path();
    my ($aligner_name) = $aligner_path =~ m{([^/]+)$}msx;

    my %extension = ( bowtie => q{.1.ebwt}, );

    my $fasta_dir = catfile($root, $self->subset, q[fasta] ) . q[/];
    my $fasta = ( glob $fasta_dir . '*.{fasta,fa,fna}' )[0];
    my $indexed_base = $fasta;

    my ($basename) = fileparse( $fasta, qr/[.]f(?:ast|n)?a/imsx );
    $self->result->reference_version($basename);

    $indexed_base =~ s{fasta/}{ $aligner_name . q(/) }emsx;
    $self->_set_indexed_ref_base($indexed_base);

    my $readme = catfile($root, q{README});
    croak "Could not read reference README: $readme" if !-r $readme;
    $self->_set_readme($readme);

    return;
}


sub parse_readme {
    my ($self) = @_;

    my $genome_correction = {};

    my $readme = $self->readme();
    my @lines  = slurp $readme, { chomp => 1 };

    shift @lines;

    foreach my $line (@lines) {
        my ( $organism, $source, $numbers ) = split m/\s+/msx, $line;

        $organism =~ s/^>//msx;

        my ( $genome_size, $reference_size ) = $numbers =~ m{(\d+)/(\d+)}msx;
        croak "Zero size reference for $organism" if $reference_size == 0;

        $genome_correction->{$organism} = sprintf '%0.2f', $genome_size / $reference_size;
    }
    return $genome_correction;
}


sub parse_alignment {
    my ($self, $map_fh) = @_;

    if (!$map_fh) { croak q[Write handle undefined.]; }
    my $contaminant_count = {};
    while (<$map_fh>) {
        if (m/^[@]PG/msx) {
            my ($aligner) = $_ =~ m/ID:(\w+)/msx;
            my ($version) = $_ =~ m/VN:(\S+)/msx;
            $self->result->aligner_version( $aligner . q{ } . $version );
            $self->result->set_info( 'Aligner', $aligner );
            $self->result->set_info( 'Aligner_version', $version );
            next;
        }

        next if m/^[@]/msx;

        my ( $read, $flag, $organism ) = split;
        next if $flag & $UNMAPPED_FLAG;

        $contaminant_count->{$organism}++;
    }
    return $contaminant_count;
}

no Moose;
__PACKAGE__->meta->make_immutable();


1;


__END__


=head1 NAME

npg_qc::autoqc::checks::contamination - check fastq reads against various
genomes

=head1 VERSION

    $Revision: 16882 $

=head1 SYNOPSIS

    C<<use npg_qc::autoqc::checks::contamination;>>

    The path to the fastq files must be specified along with the lane
    position.

    C<<my $contamination_check = npg_qc::autoqc::checks::contamination
                                          ->new( path     = '/some/fastq/dir',
                                                 position = 3, );>>

    The default location of the reference repository is taken from
    npg_tracking::data::reference::find. The alignment
    is performed against a compound reference which is listed under
    an organism named NPD_Chimera. A README file describing the reference
    is required if the default strain subdirectory for NPD_Chimera path.
    The location of the repository can be changed; see documentation
    for  npg_tracking::data::reference::find.

=head1 DESCRIPTION

    Carry out a contamination check on a fastq file (and pair) by aligning
    to a composite reference sequence comprised of sequences from various
    organisms.

    Currently the class uses the bowtie aligner.

=head1 SUBROUTINES/METHODS

=head2 new

    A constractor

=head2 execute

    Over-ride the parent execute subroutine. Check the fastq file(s) are readable, count the
    number of reads, read and parse the reference file's README, perform the
    alignment, count the contaminants, correct for the fastq size and for the
    representation of the contaminant's genome in the reference sequence.

=head2 reference_details

    Given a directory path, find the location of a referenced index for the
    aligner and check that it is readable. Get the reference version string.
    Find the README file that gives details of the sequences in the reference
    file.

=head2 parse_readme

    Parse the README file for the reference sequence. Store the version string
    for the sequence, and also a hash giving a correction factor for each
    genome represented. This is the total genome size divided by the length of
    the sequence from that genome in the reference.

    Also initialize a hash of the number of contaminant reads found per
    organism. That way each organism will show up with a count of at least 0
    and the end user knows that we have checked for it.

=head2 parse_alignment

    Read the output file from the alignment and get a raw count of the number
    of reads mapping to each organism in the reference sequence.

=head1 DIAGNOSTICS

    None.

=head1 CONFIGURATION AND ENVIRONMENT

    An arbitrary reference sequence may be supplied, but the class expects it
    to conform to the conventions of the reference repository. See the
    description in F</nfs/repository/d0031/references/README>. I.e. ideally
    the reference should B<actually be> in the repository.

=head1 DEPENDENCIES

=over

=item Moose

=item Carp

=item English

=item DateTime

=item Perl6::Slurp

=item File::Spec::Functions

=item File::Basename

=item npg_common::extractor::fastq

=item npg_tracking::data::reference::find

=item npg_common::roles::software_location

=item Readonly

=back

=head1 INCOMPATIBILITIES

    None known.

=head1 BUGS AND LIMITATIONS

    The corrected contamination estimates can be over 100%, even a lot over.
    Along with the usual limitations of sampling, using single-end alignments
    removes a constraint that would give a more accurate count. Also
    correcting for the genome representation by a simple multiplier based on
    size isn't an accurate correction either - really it should be based on
    something like proportion of unique sequence.

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

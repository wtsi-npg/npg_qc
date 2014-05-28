#!/usr/bin/env perl
#########
# Author:        nf2
# Created:       18 Nov 2011
#

#########################
# This script checks a bam file's tag sequences
# It should find the observed tags, and map them to tagsets and the expected tags
##########################

use strict;
use warnings;
use Carp;
use Getopt::Long;

our $VERSION = '0';

## no critic (NamingConventions::Capitalization)

## no critic (RegularExpressions::ProhibitUnusedCapture RegularExpressions::RequireLineBoundaryMatching RegularExpressions::ProhibitEnumeratedClasses RegularExpressions::RequireDotMatchAnything RegularExpressions::RequireExtendedFormatting)

## no critic (InputOutput::RequireBracedFileHandleWithPrint InputOutput::RequireCheckedSyscalls)

## no critic (BuiltinFunctions::ProhibitReverseSortBlock)

## no critic (Subroutines::RequireArgUnpacking) 

sub usage {

  print STDERR "\n";
  print STDERR "samtools view bam_file | npg_qc_tag_sniff.pl [opts]\n";
  print STDERR "\n";
  print STDERR "        --sample_size <int>\n";
  print STDERR "          maximum number of tags to check, default 10000. Use -1 if you want to read the whole file\n";
  print STDERR "\n";
  print STDERR "        --relative_max_drop <int>\n";
  print STDERR "          stop reporting when the drop in tag count relative to the previous tag exceeds this factor, default 10\n";
  print STDERR "\n";
  print STDERR "        --absolue_max_drop <int>\n";
  print STDERR "          stop reporting when the drop in tag count relative to the most common tag exceeds this factor, default 10\n";
  print STDERR "\n";
  print STDERR "        --degenerate_toleration\n";
  print STDERR "          don't stop reporting if a tag is all N, default false\n";
  print STDERR "\n";
  print STDERR "\n";
  return;
}

main();
0;

sub selectModeTags {
    my $relativeMaxDrop  = shift;
    my $absoluteMaxDrop = shift;
    my $degeneratingToleration = shift;
    my %tagsFound = @_;
    my $previousCount = 0;
    my $maxCount;
    my @topTags = ();

    foreach my $tag (sort {$tagsFound{$b} <=> $tagsFound{$a};} (keys %tagsFound)) {
	if (!(defined $maxCount)) {
	    $maxCount = $tagsFound{$tag};
	}
	if ( (($relativeMaxDrop * $tagsFound{$tag}) < $previousCount) ||
	     (($absoluteMaxDrop * $tagsFound{$tag}) < $maxCount) ||
	     (!$degeneratingToleration && ($tag =~ /^N*$/)) # may wish to stop with this or exclude it
	    ) {
	    last;
	}
	$previousCount = $tagsFound{$tag};
	push @topTags,$tag;
    }
    return @topTags;
}

sub showTags{

## no critic (ValuesAndExpressions::ProhibitNoisyQuotes ValuesAndExpressions::ProhibitInterpolationOfLiterals ValuesAndExpressions::ProhibitMagicNumbers)

    my $ra_topTags = shift;
    my $sampleSize = shift;
    my %tagsFound = @_;
    my $unassigned =  $sampleSize;
    foreach my $tag (@{$ra_topTags}) {
	printf "%s = %.2f%s\n", $tag, (100 * $tagsFound{$tag}/$sampleSize), '%';
	$unassigned -= $tagsFound{$tag};
    }
    printf "%s = %.2f%s\n", "REMAINDER", (100 * $unassigned/$sampleSize), "%";
    return;
}

sub main{
    my $opts = initialise();

    my $sampleSize = $opts->{sample_size};
    my $relativeMaxDrop = $opts->{relative_max_drop};
    my $absoluteMaxDrop = $opts->{absolute_max_drop};
    my $degeneratingToleration = $opts->{degenerate_toleration};

    my %tagsFound;

    my $tagsFound = 0;

    while (<>) {
	if (/((BC:)|(RT:))Z:([A-Z]*)/) {
	    $tagsFound++;
	    $tagsFound{$4}++;
	}
	if ($tagsFound == $sampleSize) {
	    last;
	}
    }

    if ($sampleSize != $tagsFound) {
        $sampleSize = $tagsFound;
    }

    my @modeTags = selectModeTags($relativeMaxDrop, $absoluteMaxDrop, $degeneratingToleration, %tagsFound);
    showTags(\@modeTags, $sampleSize, %tagsFound);
    return;
}

sub initialise {

## no critic (InputOutput::ProhibitInteractiveTest InputOutput::RequireCheckedSyscalls ValuesAndExpressions::RequireNumberSeparators)

    my %options = (sample_size => 10000, relative_max_drop => 10, absolute_max_drop => 10, degenerate_toleration=> 0);

    my $rc = GetOptions(\%options,
                        'help',
                        'sample_size:i',
			'relative_max_drop:i',
			'absolute_max_drop:i',
			'degenerate_toleration',
                        );
    if ( ! $rc) {
        print {*STDERR} "\nerror in command line parameters\n" or croak 'print failed';
        usage;
        exit 1;
    }

    if (-t STDIN) {
        print {*STDERR} "\nyou must supply a sam file on stdin\n" or croak 'print failed';
        usage;
        exit 1;
    }

    if (exists $options{'help'}) {
        usage;
        exit;
    }

    return \%options;

}

__END__

=head1 NAME

tag_sniff.pl

=head1 USAGE
  
  samtools view 5008_1#2.bam | npg_qc_tag_sniff.pl [opts]

=head1 CONFIGURATION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 REQUIRED ARGUMENTS

=head1 OPTIONS

=head1 EXIT STATUS

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item FindBin

=item Getopt::Long

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Nadeem Faruque<lt>nf2@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2011 GRL, by Nadeem Faruque

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


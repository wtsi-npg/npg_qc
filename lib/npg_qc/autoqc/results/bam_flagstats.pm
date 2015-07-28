package npg_qc::autoqc::results::bam_flagstats;

use Moose;
use namespace::autoclean;
use Carp;
use English qw(-no_match_vars);
use Perl6::Slurp;
use List::Util qw(sum);
use File::Spec::Functions qw(splitpath catpath);
use Try::Tiny;
use Compress::Zlib;
use Readonly;

use npg_tracking::util::types;
extends qw(npg_qc::autoqc::results::result);
with qw(npg_qc::autoqc::role::bam_flagstats);

our $VERSION = '0';

Readonly::Scalar my $METRICS_FIELD_LIST => [qw(
   library
   unpaired_mapped_reads
   paired_mapped_reads
   unmapped_reads
   unpaired_read_duplicates
   paired_read_duplicates
   read_pair_optical_duplicates
   percent_duplicate
   library_size)];

# picard and biobambam mark duplicates assign this
# value for aligned data with no mapped paired reads
Readonly::Scalar my $LIBRARY_SIZE_NOT_AVAILABLE => -1;

Readonly::Scalar my $HUMAN_SPLIT_ATTR_DEFAULT => 'all';
Readonly::Scalar my $SUBSET_ATTR_DEFAULT      => 'target';
Readonly::Scalar my $STATS_RELATIONSHIP_NAME  => 'samtools_stats';

has [ qw/ +path
          +id_run
          +position / ] => ( required   => 0, );

has 'human_split' => ( isa            => 'Maybe[Str]',
                       is             => 'rw',
                       predicate      => '_has_human_split',
);

has 'subset'      => ( isa            => 'Maybe[Str]',
                       is             => 'rw',
                       predicate      => '_has_subset',
);

has 'library' =>     ( isa  => 'Maybe[Str]',
                       is   => 'rw',
);
has [ qw/ num_total_reads
          unpaired_mapped_reads
          paired_mapped_reads
          unmapped_reads
          unpaired_read_duplicates
          paired_read_duplicates
          read_pair_optical_duplicates
          library_size
          proper_mapped_pair
          mate_mapped_defferent_chr
          mate_mapped_defferent_chr_5
          read_pairs_examined / ] => (
    isa => 'Maybe[Int]',
    is  => 'rw',
);

has 'percent_duplicate' => ( isa => 'Maybe[Num]',
                             is  => 'rw',
);

has 'histogram'         => ( isa     => 'HashRef',
                             is      => 'rw',
                             default => sub { {} },
);

has [ qw/ markdups_metrics_file
          flagstats_metrics_file / ] => (
    isa => 'Maybe[NpgTrackingReadableFile]',
    is  => 'ro',
    required => 0,
);

has 'samtools_stats_file' => ( isa        => 'HashRef',
                               is         => 'ro',
                               predicate  => '_has_samtools_stats_file',
                               lazy_build => 1,
);
sub _build_samtools_stats_file {
  my $self = shift;

  my $paths = {};

  my $mfile = $self->markdups_metrics_file || $self->flagstats_metrics_file;
  my $file_name_prefix;
  if ($mfile) {
    my ($volume, $directories, $filename) = splitpath($mfile);
    ($file_name_prefix) = $filename =~ /^([^.]+)/xms;
    if ($file_name_prefix) {
      foreach my $file ( grep { -f $_ } glob
          catpath($volume, $directories, $file_name_prefix . q[*.stats]) ) {
        $paths->{_get_filter($file)} = $file;
      }
    }
  }

  if (!$mfile || !$file_name_prefix) {
    carp 'Not looking for samtools stats files';
  }

  my @found = values %{$paths};
  if (@found) {
    carp 'Found the following samtools stats files: ' . join q[, ], @found;
  } else {
    carp 'Not found samtools stats files';
  }

  return $paths;
}

has 'related_data' => ( isa        => 'ArrayRef',
                        is         => 'rw',
                        lazy_build => 1,
);
sub _build_related_data {
  my $self = shift;

  my @related = ();
  if ($self->_has_samtools_stats_file) {
    foreach my $filter (keys %{$self->samtools_stats_file}) {
      my $ref = {};
      $ref->{'relationship_name'} = $STATS_RELATIONSHIP_NAME;
      $ref->{'filter'} = $filter;
      my $path =  $self->samtools_stats_file->{$filter};
      try {
        $ref->{'file_content'} = compress(slurp $path);
        push @related, $ref;
      } catch {
        carp "Error reading ${path}: $_";
      };
    }
  }

  return \@related;
}
sub _get_filter {
  my $path = shift;
  my ($volume, $directories, $file) = splitpath($path);
  ##no critic (RegularExpressions::ProhibitEnumeratedClasses)
  my ($filter) = $file =~ /_([a-zA-Z0-9]+)[.]stats\Z/xms;
  ## use critic
  if (!$filter) {
    croak "Failed to get filter from $path";
  }
  return $filter;
}

sub BUILD {
  my $self = shift;

  if ($self->_has_human_split && $self->_has_subset) {
    if ($self->human_split ne $self->subset) {
      croak sprintf 'human_split and subset attrs are different: %s and %s',
        $self->human_split, $self->subset;
    }
  } else {
    if ($self->_has_human_split) {
      if (!$self->_has_subset && $self->human_split ne $HUMAN_SPLIT_ATTR_DEFAULT ) {
        # Backwards compatibility with old results.
        # Will be done by the trigger anyway, but let's not rely on the trigger
        # which we will remove as soon as we can.
        $self->subset($self->human_split);
      }
    } else {
      if ($self->_has_subset && $self->subset ne $SUBSET_ATTR_DEFAULT) {
        # Do reverse as well so that the human_split column, while we
        # have it, is correctly populated.
        $self->human_split($self->subset);
      }
    }
  }

  return;
}

sub execute {
  my $self = shift;

  if ($self->markdups_metrics_file) {
    $self->parsing_metrics_file($self->markdups_metrics_file);
  }

  if ($self->flagstats_metrics_file) {
    my $fn = $self->flagstats_metrics_file;
    open my $fh, '<', $fn or croak "Error: $OS_ERROR - failed to open $fn for reading";
    $self->parsing_flagstats($fh);
    close $fh or carp "Warning: $OS_ERROR - failed to close filehandle to $fn";
  }

  $self->samtools_stats_file();

  return;
}

sub parsing_metrics_file {
  my ($self, $metrics_file) = @_;

  my @file_contents = slurp ( $metrics_file, { irs => qr/\n\n/mxs } );

  my $header = $file_contents[0];
  chomp $header;
  $self->set_info('Picard_metrics_header', $header);

  my ($metrics_source) = $header =~ /(MarkDuplicates | EstimateLibraryComplexity | bam\S*markduplicates)/mxs;

  my $metrics = $file_contents[1];
  my $histogram  = $file_contents[2];

  my @metrics_lines = split /\n/mxs, $metrics;
  my @metrics_numbers = split /\t/mxs, $metrics_lines[2];

  if (scalar  @metrics_numbers > scalar @{$METRICS_FIELD_LIST} ) {
    croak 'MarkDuplicate metrics format is wrong';
  }

  foreach my $field (@{$METRICS_FIELD_LIST}){
    my $field_value = shift @metrics_numbers;
    if ($field_value) {
      if ($field_value =~/\?/mxs) {
        $field_value = undef;
      } elsif ($field eq 'library_size' && $field_value < 0) {
        if ($field_value == $LIBRARY_SIZE_NOT_AVAILABLE) {
          $field_value = undef;
        } else {
          croak "Library size less than $LIBRARY_SIZE_NOT_AVAILABLE";
        }
      }
    }
    $self->$field( $field_value );
  }

  $self->read_pairs_examined( $self->paired_mapped_reads() );
  if ($metrics_source eq 'EstimateLibraryComplexity') {
    $self->paired_mapped_reads(0)
  }

  if ($histogram) {
    my @histogram_lines = split /\n/mxs, $histogram;
    my %histogram_hash = map { $_->[0] => $_->[1] } map{ [split /\s/mxs] } grep {/^[\d]/mxs } @histogram_lines;
    $self->histogram(\%histogram_hash);
  }

  return;
}

sub parsing_flagstats {
  my ($self, $samtools_output_fh) = @_;

  while ( my $line = <$samtools_output_fh> ) {
    chomp $line;
    my $number = sum $line =~ /^(\d+)\s*\+\s*(\d+)\b/mxs;

    ( $line =~ /properly\ paired/mxs )                                            ? $self->proper_mapped_pair($number)
      :( $line =~ /with\ mate\ mapped\ to\ a\ different\ chr$/mxs )               ? $self->mate_mapped_defferent_chr($number)
      :( $line =~ /with\ mate\ mapped\ to\ a\ different\ chr\ \(mapQ\>\=5\)/mxs ) ? $self->mate_mapped_defferent_chr_5($number)
      :( $line =~ /in\ total/mxs )                                                ? $self->num_total_reads($number)
      : next;
  }
  return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__


=head1 NAME

npg_qc::autoqc::results::bam_flagstats

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 BUILD - ensures human_split and subset fields are populated consistently

=head2 execute

  calls methods for parsing samtools flagstats and mark duplicates outputs,
  finds and saves locations of stats files

=head2 parsing_flagstats

  parses Picard MarkDuplicates metrics output file and save the result to the object

=head2 parsing_metrics_file

  parses samtools flagstats output file handler and save the result to the object

=head2 markdups_metrics_file

=head2 flagstats_metrics_file

=head2 samtools_stats_file

=head2 related_data

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Carp

=item English

=item Perl6::Slurp

=item List::Util

=item File::Spec

=item Try:Tiny

=item Compress::Zlib

=item Readonly

=item namespace::autoclean

=item npg_tracking::util::types

=item npg_qc::autoqc::results::result

=item npg_qc::autoqc::role::bam_flagstats

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Guoying Qi E<lt>gq1@sanger.ac.ukE<gt><gt>
Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt><gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 GRL

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

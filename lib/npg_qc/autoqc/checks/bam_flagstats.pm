package npg_qc::autoqc::checks::bam_flagstats;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use Carp;
use English qw(-no_match_vars);
use Perl6::Slurp;
use List::Util qw(sum);
use File::Spec::Functions qw(catfile);
use Readonly;

use npg_tracking::util::types;
use npg_qc::autoqc::results::sequence_summary;
use npg_qc::autoqc::results::samtools_stats;

extends qw( npg_qc::autoqc::checks::check );
with    qw( npg_tracking::glossary::subset );

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
Readonly::Scalar our $EXT => q[bam];

has '+subset' => ( isa => 'Str', );

has '+file_type' => (default => $EXT,);

has [ qw/ _sequence_file
          markdups_metrics_file
          flagstats_metrics_file / ] => (
    isa        => 'NpgTrackingReadableFile',
    is         => 'ro',
    required   => 0,
    lazy_build => 1,
);
has '+_sequence_file' => (init_arg   => undef);
sub _build__sequence_file {
  my $self = shift;
  return $self->input_files->[0];
}
sub _build_markdups_metrics_file {
  my $self = shift;
  return join q[.], $self->_file_path_root, 'markdups_metrics.txt';
}
sub _build_flagstats_metrics_file {
  my $self = shift;
  return join q[.], $self->_file_path_root, 'flagstat';
}

has '_file_path_root'     => ( isa        => 'Str',
                               is         => 'ro',
                               lazy_build => 1,
);
sub _build__file_path_root {
  my $self = shift;
  my $path;
  if ($self->has_filename_root && $self->has_qc_in) {
    $path = catfile $self->qc_in, $self->filename_root;
  } else {
    ($path) = $self->_sequence_file =~ /\A(.+)\.[[:lower:]]+\Z/smx;
  }
  return $path;
}

has 'samtools_stats_file' => ( isa        => 'ArrayRef',
                               is         => 'ro',
                               lazy_build => 1,
);
sub _build_samtools_stats_file {
  my $self = shift;

  my @underscores = ($self->_file_path_root =~ /_/gsmx);
  my $n = 1 + scalar @underscores;
  my @paths = sort grep { -f $_ && _matches_seq_file($_, $n) } glob $self->_file_path_root . q[_*.stats];
  if (!@paths) {
    warn 'WARNING: Samtools stats files are not found for ' . $self->to_string() . qq[\n];
  }

  return \@paths;
}
sub _matches_seq_file {
  my ($path, $expected_num_underscores) = @_;
  my @underscores = ($path =~ /_/gsmx);
  return scalar @underscores == $expected_num_underscores;
}

has 'related_results' => ( isa        => 'ArrayRef[Object]',
                           is         => 'ro',
                           lazy_build => 1,
);
sub _build_related_results {
  my $self = shift;

  my @objects = map { npg_qc::autoqc::results::samtools_stats->new(
                        filename_root => $self->result->filename_root,
                        composition   => $self->composition,
                        stats_file    => $_
                      )
                   } @{$self->samtools_stats_file};
  push @objects, npg_qc::autoqc::results::sequence_summary->new(
                   filename_root   => $self->result->filename_root,
                   composition     => $self->composition,
                   sequence_format => $self->file_type,
                   file_path_root  => $self->_file_path_root
                 );

  return \@objects;
}

override 'execute' => sub {
  my $self = shift;

  $self->_parse_markdups_metrics();
  $self->_parse_flagstats();
  for my $rr ( @{$self->related_results()} ) {
    $rr->execute();
  }

  return;
};

sub _parse_markdups_metrics {
  my $self = shift;

  my @file_contents = slurp ( $self->markdups_metrics_file, { irs => qr/\n\n/mxs } );

  my $header = $file_contents[0];
  chomp $header;
  $self->result()->set_info('markdups_metrics_header', $header);

  my ($metrics_source) = $header =~ /(MarkDuplicates | EstimateLibraryComplexity | bam\S*markduplicates)/mxs;

  my $metrics    = $file_contents[1];
  my $histogram  = $file_contents[2];

  my @metrics_lines   = split /\n/mxs, $metrics;
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
    $self->result()->$field( $field_value );
  }

  $self->result()->read_pairs_examined( $self->result()->paired_mapped_reads() );
  if ($metrics_source eq 'EstimateLibraryComplexity') {
    $self->result()->paired_mapped_reads(0);
  }

  if ($histogram) {
    my @histogram_lines = split /\n/mxs, $histogram;
    my %histogram_hash = map { $_->[0] => $_->[1] } map{ [split /\s/mxs] } grep {/^[\d]/mxs } @histogram_lines;
    $self->result()->histogram(\%histogram_hash);
  }

  return;
}

sub _parse_flagstats {
  my $self = shift;

  my $fn = $self->flagstats_metrics_file;
  ## no critic (InputOutput::RequireBriefOpen)
  open my $samtools_output_fh, '<', $fn or croak "Error: $OS_ERROR - failed to open $fn for reading";
  while ( my $line = <$samtools_output_fh> ) {
    chomp $line;
    my $number = sum $line =~ /^(\d+)\s*\+\s*(\d+)\b/mxs;

    ( $line =~ /properly\ paired/mxs )
      ? $self->result()->proper_mapped_pair($number)
      : ( $line =~ /with\ mate\ mapped\ to\ a\ different\ chr$/mxs )
      ? $self->result()->mate_mapped_defferent_chr($number)
      : ( $line =~ /with\ mate\ mapped\ to\ a\ different\ chr\ \(mapQ\>\=5\)/mxs )
      ? $self->result()->mate_mapped_defferent_chr_5($number)
      :( $line =~ /in\ total/mxs )
      ? $self->result()->num_total_reads($number)
      : next;
  }
  close $samtools_output_fh  or carp "Warning: $OS_ERROR - failed to close filehandle to $fn";

  return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__


=head1 NAME

npg_qc::autoqc::checks::bam_flagstats

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 subset

  An optional subset, see npg_tracking::glossary::subset for details.

=head2 related_results

  A lazy attribute, an array of related autoqc result objects.

=head2 markdups_metrics_file

=head2 flagstats_metrics_file

=head2 samtools_stats_file

  An an array of samtools stats file paths.

=head2 execute

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item namespace::autoclean

=item Carp

=item English

=item Perl6::Slurp

=item List::Util

=item File::Spec::Functions

=item Readonly

=item npg_tracking::util::types

=item npg_tracking::glossary::subset

=item npg_qc::autoqc::checks::check

=item npg_qc::autoqc::results::sequence_summary

=item npg_qc::autoqc::results::samtools_stats

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Guoying Qi E<lt>gq1@sanger.ac.ukE<gt><gt>
Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt><gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2016 GRL

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

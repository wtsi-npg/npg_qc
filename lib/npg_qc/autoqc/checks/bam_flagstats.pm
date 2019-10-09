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

Readonly::Hash my %METRICS_FIELD_MAPPING => {
   'LIBRARY'                      => 'library',
   'READ_PAIRS_EXAMINED'          => 'read_pairs_examined',
   'UNPAIRED_READ_DUPLICATES'     => 'unpaired_read_duplicates',
   'READ_PAIR_DUPLICATES'         => 'paired_read_duplicates',
   'READ_PAIR_OPTICAL_DUPLICATES' => 'read_pair_optical_duplicates',
   'PERCENT_DUPLICATION'          => 'percent_duplicate',
   'ESTIMATED_LIBRARY_SIZE'       => 'library_size'
};

Readonly::Hash my %SAMTOOLS_METRICS_FIELD_MAPPING => {
   'LIBRARY'                      => 'library', 
   'PAIRED'                       => 'read_pairs_examined',
   'DUPLICATE SINGLE'             => 'unpaired_read_duplicates',
   'DUPLICATE PAIR'               => 'paired_read_duplicates',
   'DUPLICATE OPTICAL'            => 'read_pair_optical_duplicates',
   'PERCENT_DUPLICATION'          => 'percent_duplicate',
   'ESTIMATED_LIBRARY_SIZE'       => 'library_size'
};

Readonly::Scalar my $LIBRARY_SIZE_NOT_AVAILABLE => -1;  # assigned to ESTIMATED_LIBRARY_SIZE by picard and biobambam for aligned data with no mapped paired reads
Readonly::Scalar my $METRICS_NUMBER => 10;
Readonly::Scalar my $PAIR_NUMBER => 2;
Readonly::Scalar my $TARGET_STATS_PATTERN => 'target';
Readonly::Scalar my $TARGET_AUTOSOME_STATS_PATTERN => 'target_autosome';
Readonly::Scalar my $TARGET_STATS_DEFAULT_DEPTH => 15;
Readonly::Scalar my $STATS_FILTER => '[[:alnum:]]+[\_[:lower:]]*?';
Readonly::Scalar our $EXT => q[cram];

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
  my $metrics_file;
  if( !$self->skip_markdups_metrics ){
    $metrics_file = join q[.], $self->_file_path_root, 'markdups_metrics.txt';
  }
  return $metrics_file;
}
sub _build_flagstats_metrics_file {
  my $self = shift;
  return join q[.], $self->_file_path_root, 'flagstat';
}

has 'skip_markdups_metrics' => (is       => 'ro',
                                isa      => 'Bool',
                                required => 0,
                                default  => 0,
                                );

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
  my @paths = sort grep { -f && $self->_matches_seq_file($_) } glob $self->_file_path_root . q[_*.stats];
  if (!@paths) {
    warn 'WARNING: Samtools stats files are not found for ' . $self->to_string() . qq[\n];
  }
  return \@paths;
}
sub _matches_seq_file {
  my ($self,$path) = @_;
  if ( ! $path) { croak q(No input path defined) }
  my ($ext) = $path =~ /(_$STATS_FILTER[.]stats)\Z/xms;
  return $path eq $self->_file_path_root . $ext;
}

has 'target_stats_file' => ( isa        => 'Str | Undef',
                             is         => 'ro',
                             lazy_build => 1,
);
sub _build_target_stats_file {
  my $self = shift;
  return $self->_find_stats_file($TARGET_STATS_PATTERN);
}
has 'target_autosome_stats_file' => ( isa        => 'Str | Undef',
                                      is         => 'ro',
                                      lazy_build => 1,
);

sub _build_target_autosome_stats_file {
  my $self = shift;
  return $self->_find_stats_file($TARGET_AUTOSOME_STATS_PATTERN);
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

  super();

  if( !$self->skip_markdups_metrics ){
    $self->_parse_markdups_metrics();
  }
  if( $self->target_stats_file ) {
    $self->_parse_target_stats_file
        ($self->target_stats_file,$TARGET_STATS_PATTERN);
  }
  if( $self->target_autosome_stats_file ) {
    $self->_parse_target_stats_file
        ($self->target_autosome_stats_file,$TARGET_AUTOSOME_STATS_PATTERN);
  }
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

  if($header =~ /^COMMAND:[^\n]*samtools[ ]markdup/smx) {
    chomp $header;
    $self->result()->set_info('markdups_metrics_header', $header);

    $header =~ s/ESTIMATED_LIBRARY_SIZE[^:]/ESTIMATED_LIBRARY_SIZE:/smx; # temporary workaround for samtools markdup metrics format bug
    my %metrics = map { split /:/smx } (split /\n/smx, $header);

    @metrics{keys %metrics} = (map { _trim($_) } values %metrics); # remove any leading and trailing spaces from values

    for my $field (keys %SAMTOOLS_METRICS_FIELD_MAPPING) {
      my $field_value = $metrics{$field};

      ($field eq q[PAIRED] or $field eq q[DUPLICATE PAIR]) && ($field_value /= 2);
      ($field eq q[PERCENT_DUPLICATION]) && ((($field_value = $metrics{'EXAMINED'}) == 0) || ($field_value = sprintf q[%0.6f], ($metrics{'DUPLICATE PAIR'} + $metrics{'DUPLICATE SINGLE'}) / $metrics{'EXAMINED'}));
      ($field eq q[COMMAND]) && next;

      $self->result->${\$SAMTOOLS_METRICS_FIELD_MAPPING{$field}}($field_value);
    }

    # note: no histogram from samtools markdup
  }
  else { # not samtools, assume picard/biobambam2 format
    chomp $header;
    $self->result()->set_info('markdups_metrics_header', $header);

    my $metrics    = $file_contents[1];
    my $histogram  = $file_contents[2];

    my @metrics_lines   = split /\n/mxs, $metrics;
    my @metrics_header  = split /\t/mxs, $metrics_lines[1];
    my @metrics_numbers = split /\t/mxs, $metrics_lines[2];

    my %metrics;
    @metrics{@metrics_header} = @metrics_numbers;

    if (scalar  @metrics_numbers > $METRICS_NUMBER ) {
      croak 'MarkDuplicate metrics format is wrong';
    }

    foreach my $field (keys %METRICS_FIELD_MAPPING){
      my $field_value = $metrics{$field};
      if ($field_value) {
        if ($field_value =~/\?/mxs) {
          $field_value = undef;
        } elsif ($field eq 'ESTIMATED_LIBRARY_SIZE' && $field_value < 0) {
          if ($field_value == $LIBRARY_SIZE_NOT_AVAILABLE) {
            $field_value = undef;
          } else {
            croak "Library size less than $LIBRARY_SIZE_NOT_AVAILABLE";
          }
        }
      }
      $self->result()->${\$METRICS_FIELD_MAPPING{$field}}( $field_value );
    }

    if ($histogram) {
      my @histogram_lines = split /\n/mxs, $histogram;
      my %histogram_hash = map { $_->[0] => $_->[1] } map{ [split /\s/mxs] } grep {/^[\d]/mxs } @histogram_lines;
      $self->result()->histogram(\%histogram_hash);
    }
  }
  return;
}

sub _trim {
  my ($s) = @_;

  # remove any leading and trailing spaces
  $s =~ s/^\s*//smx;
  $s=~s/\s*$//smx;

  return $s;
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
      : ( $line =~ /with\ itself\ and\ mate\ mapped/mxs )
      ? $self->result()->paired_mapped_reads($number/$PAIR_NUMBER)
      : ( $line =~ /singletons\ \(/mxs )
      ? $self->result()->unpaired_mapped_reads($number)
      : ( $line =~ /mapped\ \(/mxs )
      ? $self->result()->unmapped_reads($self->result()->num_total_reads() - $number)
      : next;
  }
  close $samtools_output_fh  or carp "Warning: $OS_ERROR - failed to close filehandle to $fn";

  return;
}

sub _parse_target_stats_file {
   my($self,$fn,$prefix) = @_;

   ## no critic (InputOutput::RequireBriefOpen)
   open my $target_stats_fh, '<', $fn or croak "Error: $OS_ERROR - failed to open $fn for reading";
   while ( my $line = <$target_stats_fh> ) {
     chomp $line;
     if ( $line =~ /The\ command\ line\ was/mxs ) {
       if($line =~ /-(g|cov\-threshold)\s*(\d+)/mxs ){
         $self->_set_result($prefix . '_coverage_threshold',$2);
       } else{
         $self->_set_result($prefix . '_coverage_threshold',$TARGET_STATS_DEFAULT_DEPTH);
       }
       if( $line =~ /-(t|target\-regions)\s*([\w\/\-\.]+)/mxs ){
         $self->result()->set_info($prefix .'_path', $2);
       }
     }
     elsif ( $line =~ /^SN\s+/mxs ){
          my ($number) = $line =~ /^SN\s+.*\:\s+([\d\.]+)\b/mxs;
          ( $line =~ /reads\ mapped\:/mxs )
          ? $self->_set_result($prefix . '_mapped_reads',$number)
          : ( $line =~ /reads\ properly\ paired\:/mxs )
          ? $self->_set_result($prefix . '_proper_pair_mapped_reads',$number)
          : ( $line =~ /bases\ mapped\ \(cigar\)\:/mxs )
          ? $self->_set_result($prefix . '_mapped_bases',$number)
          : ( $line =~ /bases\ inside\ the\ target\:/mxs )
          ? $self->_set_result($prefix . '_length',$number)
          : ( $line =~ /percentage\ of\ target\ genome\ with\ coverage/mxs )
          ? $self->_set_result($prefix . '_percent_gt_coverage_threshold',$number)
          : next;
     }
     elsif ( $line =~ /^FFQ\s+/mxs ) { last; }
   }
   close $target_stats_fh  or carp "Warning: $OS_ERROR - failed to close filehandle to $fn";

   my ($filter) = $fn =~ /_($STATS_FILTER)[.]stats\Z/xms;
   $self->_set_result($prefix . '_filter',$filter);

   return;
}

sub _set_result {
  my ($self,$method,$result) = @_;
  $self->result()->$method($result);
  return;
}

sub _find_stats_file {
  my ($self,$pattern) = @_;
  my $file;
  if($self->samtools_stats_file && @{$self->samtools_stats_file}){
    my @x = @{$self->samtools_stats_file};
    my @found = grep { /\_$pattern\./smx } @{$self->samtools_stats_file};
    if (@found == 1){ $file = $found[0]; }
  }
  return $file;
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

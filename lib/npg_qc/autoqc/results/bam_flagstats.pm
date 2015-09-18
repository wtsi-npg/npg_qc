package npg_qc::autoqc::results::bam_flagstats;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use Carp;
use English qw(-no_match_vars);
use Perl6::Slurp;
use List::Util qw(sum);
use File::Spec::Functions qw( splitpath
                              catpath
                              catfile
                              splitdir
                              catdir );
use Try::Tiny;
use Readonly;

use npg_tracking::util::types;
use npg_qc::autoqc::results::sequence_summary;
use npg_qc::autoqc::results::samtools_stats;

extends qw( npg_qc::autoqc::results::result );
with    qw(
            npg_tracking::glossary::subset
            npg_qc::autoqc::role::bam_flagstats
          );
with 'npg_tracking::glossary::composition::factory' =>
  {component_class => 'npg_tracking::glossary::composition::component::illumina'};

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

has [ qw/ +path
          +id_run
          +position / ] => ( required   => 0, );

has '+subset' => ( writer      => '_set_subset', );

has 'human_split' => ( isa            => 'Maybe[Str]',
                       is             => 'rw',
                       predicate      => '_has_human_split',
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

has 'sequence_file' => (
    isa        => 'NpgTrackingReadableFile',
    is         => 'ro',
    traits     => [ 'DoNotSerialize' ],
    required   => 0,
    writer     => '_set_sequence_file',
);

has [ qw/ markdups_metrics_file
          flagstats_metrics_file / ] => (
    isa        => 'Maybe[NpgTrackingReadableFile]',
    is         => 'ro',
    traits     => [ 'DoNotSerialize' ],
    required   => 0,
    lazy_build => 1,
);
sub _build_markdups_metrics_file {
  my $self = shift;
  if ($self->sequence_file) {
    return join q[.], $self->_file_path_root, 'markdups_metrics.txt';
  }
  return;
}
sub _build_flagstats_metrics_file {
  my $self = shift;
  if ($self->sequence_file) {
    return join q[.], $self->_file_path_root, 'flagstat';
  }
  return;
}

has '_file_path_root'     => ( traits     => [ 'DoNotSerialize' ],
                               isa        => 'Str',
                               is         => 'ro',
                               lazy_build => 1,
);
sub _build__file_path_root {
  my $self = shift;
  my $path = q[];
  if ($self->sequence_file) {
    ($path) =  _drop_extension($self->sequence_file);
  }
  return $path;
}
sub _drop_extension {
  my $path = shift;
  ($path) = $path =~ /\A(.+)\.[[:lower:]]+\Z/smx;
  return $path
}

has 'samtools_stats_file' => ( isa        => 'ArrayRef',
                               is         => 'ro',
                               lazy_build => 1,
);
sub _build_samtools_stats_file {
  my $self = shift;

  my @paths = ();
  if ($self->sequence_file) {
    my @underscores = ($self->sequence_file =~ /_/gsmx);
    my $n = 1 + scalar @underscores;
    @paths = sort grep { -f $_ && _matches_seq_file($_, $n) } glob $self->_file_path_root . q[_*.stats];
    if (!@paths) {
      warn 'WARNING: Samtools stats files are not found for ' . $self->to_string() . qq[\n];
    }
  } else {
    warn 'WARNING: Sequence file not given - not looking for samtools stats files' . qq[\n];
  }

  return \@paths;
}
sub _matches_seq_file {
  my ($path, $expected_num_underscores) = @_;
  my @underscores = ($path =~ /_/gsmx);
  return scalar @underscores == $expected_num_underscores;
}

has 'related_objects' => ( isa        => 'ArrayRef[Object]',
                           is         => 'ro',
                           lazy_build => 1,
                           writer     => '_set_related_objects',
                           predicate  => '_has_related_objects',
);
sub _build_related_objects {
  my $self = shift;

  my @objects = ();
  if ($self->sequence_file && $self->id_run && $self->position) {
    my $composition = $self->create_composition();
    @objects = map { npg_qc::autoqc::results::samtools_stats->new(
                          composition => $composition,
                          stats_file  => $_
                        )
                   } @{$self->samtools_stats_file};
    push @objects, npg_qc::autoqc::results::sequence_summary->new(
                     composition   => $composition,
                     sequence_file => $self->sequence_file
                   );
  }
  return \@objects;
}

sub BUILD {
  my $self = shift;

  if ($self->_has_human_split && $self->has_subset) {
    if ($self->human_split ne $self->subset) {
      croak sprintf 'human_split and subset attrs are different: %s and %s',
        $self->human_split, $self->subset;
    }
  } else {
    if ($self->_has_human_split) {
      if (!$self->has_subset && $self->human_split ne $HUMAN_SPLIT_ATTR_DEFAULT ) {
        # Backwards compatibility with old results.
        # Will be done by the trigger anyway, but let's not rely on the trigger
        # which we will remove as soon as we can.
        $self->_set_subset($self->human_split);
      }
    } else {
      if ($self->has_subset && $self->subset ne $SUBSET_ATTR_DEFAULT) {
        # Do reverse as well so that the human_split column, while we
        # have it, is correctly populated.
        $self->human_split($self->subset);
      }
    }
  }

  return;
}

around 'store' => sub {
  my ($orig, $self, $path) = @_;
  if ($self->_has_related_objects()) {
    for my $o ( @{$self->related_objects()} ) {
      $o->store($path);
    }
  }
  $self->_set_related_objects([]);
  return $self->$orig($path);
};

sub filename_root {
  my $self = shift;

  if (!$self->id_run && $self->_file_path_root) {
    my ($volume, $directories, $file) = splitpath($self->_file_path_root);
    my $subset = $self->subset;
    if ($subset) {
      $file =~ s/\Q_${subset}\E\Z//msx;
    }
    return $file;
  }
  return;
}

sub execute {
  my $self = shift;

  $self->_parse_markdups_metrics();
  $self->_parse_flagstats();
  for my $ro ( @{$self->related_objects()} ) {
    $ro->execute();
  }

  return;
}

sub create_related_objects {
  my ($self, $path) = @_;
  if (!$self->_has_related_objects()) {
    if (!$self->sequence_file) {
      $self->_set_sequence_file(_find_sequence_file($path));
    }
    foreach my $ro ( @{$self->related_objects()} ) {
      $ro->execute();
    }
  }
  return;
}

sub _parse_markdups_metrics {
  my $self = shift;

  if (!$self->markdups_metrics_file) {
    croak 'markdups_metrics_file not found';
  }
  my @file_contents = slurp ( $self->markdups_metrics_file, { irs => qr/\n\n/mxs } );

  my $header = $file_contents[0];
  chomp $header;
  $self->set_info('markdups_metrics_header', $header);

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

sub _parse_flagstats {
  my $self = shift;

  my $fn = $self->flagstats_metrics_file;
  if (!$fn) {
    croak 'flagstats_metrics_file not found';
  }

  ## no critic (InputOutput::RequireBriefOpen)
  open my $samtools_output_fh, '<', $fn or croak "Error: $OS_ERROR - failed to open $fn for reading";
  while ( my $line = <$samtools_output_fh> ) {
    chomp $line;
    my $number = sum $line =~ /^(\d+)\s*\+\s*(\d+)\b/mxs;

    ( $line =~ /properly\ paired/mxs )
      ? $self->proper_mapped_pair($number)
      : ( $line =~ /with\ mate\ mapped\ to\ a\ different\ chr$/mxs )
      ? $self->mate_mapped_defferent_chr($number)
      : ( $line =~ /with\ mate\ mapped\ to\ a\ different\ chr\ \(mapQ\>\=5\)/mxs )
      ? $self->mate_mapped_defferent_chr_5($number)
      :( $line =~ /in\ total/mxs )
      ? $self->num_total_reads($number)
      : next;
  }
  close $samtools_output_fh  or carp "Warning: $OS_ERROR - failed to close filehandle to $fn";

  return;
}

sub _find_sequence_file {
  my $path = shift;

  if (!$path) {
    croak 'Path should be given';
  }
  if (!-f $path) {
    croak 'File path should be given';
  }

  my ($volume, $directories, $file) = splitpath($path);
  $file = _drop_extension($file);
  $file =~ s/[\._]bam_flagstats\Z//msx;
  $file = join q[.], $file, 'cram';
  my @dirs = splitdir $directories;
  if (! pop @dirs) { # move one directory up
    pop @dirs
  }

  return catpath $volume, catdir(@dirs), $file;
}

__PACKAGE__->meta->make_immutable;

1;

__END__


=head1 NAME

npg_qc::autoqc::results::bam_flagstats

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 id_run

  an optional attribute

=head2 position

  an optional attribute

=head2 tag_index

  an optional attribute

=head2 subset

  an optional subset, see npg_tracking::glossary::subset for details.

=head2 BUILD - ensures human_split and subset fields are populated consistently

=head2 sequence_file

  an optional attribute, a full path to the sequence, should be set
  for 'execute' method to work correctly

=head2 store

  extended parent method of the same name, serializes related objects to files
  and resets the related objects attribute to an empty array, then calls
  the parent method

=head2 execute

  calls methods for parsing samtools flagstats and mark duplicates outputs

=head2 related_objects

  a lazy attribute, an array of related autoqc result objects

=head2 create_related_objects

  method forcing related objects attribute to be built

=head2 markdups_metrics_file

  an optional attribute, should be either set or built for 'execute' method to work correctly

=head2 flagstats_metrics_file

  an optional attribute, should be either set or built for 'execute' method to work correctly

=head2 samtools_stats_file

  an attribute which is built when 'execute' method is invoked

=head2 filename_root

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item Carp

=item English

=item Perl6::Slurp

=item List::Util

=item File::Spec::Functions

=item Try::Tiny

=item Readonly

=item namespace::autoclean

=item npg_tracking::util::types

=item npg_tracking::glossary::subset

=item npg_tracking::glossary::composition::factory

=item npg_tracking::glossary::composition::component::illumina

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

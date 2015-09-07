package npg_qc::autoqc::results::bam_flagstats;

use Moose;
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
    required   => 0,
);

has [ qw/ markdups_metrics_file
          flagstats_metrics_file / ] => (
    isa        => 'Maybe[NpgTrackingReadableFile]',
    is         => 'ro',
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

has 'samtools_stats_file' => ( isa        => 'HashRef',
                               is         => 'ro',
                               lazy_build => 1,
);
sub _build_samtools_stats_file {
  my $self = shift;

  my $paths = {};

  if ($self->sequence_file) {
    my $path = $self->_file_path_root . q[*.stats];
    foreach my $file ( grep { -f $_ } glob $path) {
      my $filter = $self->_filter($file);
      if ($filter) {
        $paths->{$filter} = $file;
      }
    }

    my @found = values %{$paths};
    if (@found) {
      carp 'Found the following samtools stats files: ' . join q[, ], @found;
    } else {
      carp 'Not found samtools stats files';
    }
  } else {
    carp 'Sequence file not given - not looking for samtools stats files';
  }

  return $paths;
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
  if ($self->sequence_file) {
    my $composition = $self->create_composition();
    if ($composition) {
      foreach my $filter (sort keys %{$self->samtools_stats_file}) {
        push @objects,
          npg_qc::autoqc::results::samtools_stats->new(
            composition => $composition,
            filter      => $filter,
            stats_file  => $self->samtools_stats_file->{$filter}
          );
      }

      push @objects,
        npg_qc::autoqc::results::sequence_summary->new(
          composition   => $composition,
          sequence_file => $self->sequence_file
        );

      for my $o ( @objects ) {
        $o->execute;
      }
    }
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

around 'write2file' => sub {
  my ($orig, $self, $path) = @_;
  if ($self->_has_related_objects()) {
    for my $o ( @{$self->related_objects()} ) {
      $o->write2file($path);
    }
  }
  $self->_set_related_objects([]);
  return $self->$orig($path);
};

sub execute {
  my $self = shift;

  for my $attr ( qw/markdups_metrics_file flagstats_metrics_file/ ) {
    if (!$self->$attr) {
      croak "$attr not found";
    }
  }

  $self->parsing_metrics_file($self->markdups_metrics_file);

  my $fn = $self->flagstats_metrics_file;
  open my $fh, '<', $fn or croak "Error: $OS_ERROR - failed to open $fn for reading";
  $self->parsing_flagstats($fh);
  close $fh or carp "Warning: $OS_ERROR - failed to close filehandle to $fn";

  try {
    $self->related_objects();
  } catch {
    carp qq[Warning: failed to build related objects: $_];
  };

  return;
}

sub parsing_metrics_file {
  my ($self, $metrics_file) = @_;

  my @file_contents = slurp ( $metrics_file, { irs => qr/\n\n/mxs } );

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

sub parsing_flagstats {
  my ($self, $samtools_output_fh) = @_;

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
  return;
}

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

sub create_related_objects {
  my ($self, $path) = @_;
  if (!$self->_has_related_objects()) {
    if (!$self->sequence_file) {
      $self->_set_sequence_file(_find_sequence_file($path));
    }
    $self->related_objects();
  }
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
  $file =~ s/\Q_bam_flagstats\E\Z//msx;
  $file = join q[.], $file, 'cram';
  my @dirs = splitdir $directories;
  if (! pop @dirs) { # move one directory up
    pop @dirs
  }
  my $seq_file = catpath($volume, catdir(@dirs), $file);
  if ( !-f $seq_file ) {
    croak "$seq_file is not found, cannot compute related objects for " . __PACKAGE__;
  }

  return $seq_file;
}

sub _filter {
  my ($self, $path) = @_;

  my ($volume, $directories, $file) = splitpath($path);
  my ($filter) = $file =~ /_([[:lower:][:upper:][:digit:]]+)[.]stats\Z/xms;
  if (!$filter) {
    croak "Failed to get filter from $path";
  }
  my $subset = $self->subset ? $self->subset . q[_] : q[];

  return  ($file =~ / \d _ $subset $filter [.]stats\Z/xms) ? $filter : undef;
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

=head2 write2file

  extended parent method of the same name, serializes related objects to files
  and resets the related objects attribute to an empty array, then calls
  teh parent method

=head2 execute

  calls methods for parsing samtools flagstats and mark duplicates outputs

=head2 related_objects

  a lazy attribute, an array of related autoqc result objects

=head2 create_related_objects

  method forcing related objects attribute to be built

=head2 parsing_flagstats

  parses Picard MarkDuplicates metrics output file and save the result to the object

=head2 parsing_metrics_file

  parses samtools flagstats output file handler and save the result to the object

=head2 markdups_metrics_file

  an optional attribute, should be either set or built for 'execute' method to work correctly

=head2 flagstats_metrics_file

  an optional attribute, should be either set or built for 'execute' method to work correctly

=head2 samtools_stats_file

  an attribute, is built when 'execute' method is invoked

=head2 filename_root

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

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

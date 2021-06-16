package npg_qc::autoqc::checks::cscreen;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use Carp;
use English qw(-no_match_vars);
use Perl6::Slurp;
use File::Spec;
use Readonly;
use Cwd q(abs_path);
use File::Basename;

extends 'npg_qc::autoqc::checks::check';
with    'npg_tracking::data::reference::list';
with    'npg_common::roles::software_location' =>
          { tools => [qw/mash samtools/] };

our $VERSION = '0';

Readonly::Scalar my $EXT                    => q[cram];
Readonly::Scalar my $SHIFT_EIGHT            => 8;
Readonly::Scalar my $SUFFICIENT_NUM_READS   => 10_000_000;
Readonly::Scalar my $SAMTOOLS_FILTER        => q[0x900];
Readonly::Scalar my $MASH_SCREEN_MAX_PVALUE => 0.0001;
Readonly::Scalar my $QUERY_ID_INDEX         => 4;
Readonly::Scalar my $SKETCH_FILE_NAME       => q[all_species_current.msh];
Readonly::Scalar my $SKETCH_DIR_REL_PATH    => q[mash/screen];
Readonly::Hash   my %EMPTY_RESULT           =>
                   ('references' => q[], 'adapters' => q[]);
# TODO or rather to consider:
# 1. How many CPU overrall, how many for each tool?
# 2. Filter for p==0 ?

has '+file_type' => (default => $EXT,);

has 'sketch_path' => (
  isa        => q{Str},
  is         => q{ro},
  required   => 0,
  lazy_build => 1,
);
sub _build_sketch_path {
  my $self = shift;
  my $dir = catdir($self->metaref_repository, $SKETCH_DIR_REL_PATH);
  if (not -d $dir) {
    croak qq[mash screen sketch directory $dir does not exist];
  }
  my $sketch = catfile($dir, $SKETCH_FILE_NAME);
  if (not -f $sketch) {
    croak qq[mash sketch for $sketch does not exist];
  }
  return $sketch;
}
around 'sketch_path' => sub {
  my $orig = shift;
  my $self = shift;
  my $path = $self->$orig();

  if (!-e $path) {
    croak "'$path' is not found";
  }

  # The path might be a symlink, we have to resolve it.
  if (-l $path) {
    my $target = readlink $path;
    if (File::Spec->file_name_is_absolute($target)) {
      $path = $target;
    } else {
      my ($name,$dir) = fileparse($path);
      $path = File::Spec->catfile($dir, $target);
    }
  } elsif (!-f $path) {
    croak "'$path' is not a file";
  }

  # Return an absolute path.
  return abs_path($path);
};

has 'tm_json_file' => (
  isa      => 'Str',
  is       => 'ro',
  required => 0,
);

has 'num_input_reads' => (
  isa        => q{Maybe[Int]},
  is         => q{ro},
  required   => 0,
  lazy_build => 1,
);
sub _build_num_input_reads {
  return;
}

override 'execute' => sub {
  my $self = shift;

  super(); # Will figure out the input file if not given explicitly.

  # The result is a hash reference with two keys, 'adapters' and 'references'.
  # In both cases the values are two-dimentional tables (a array of arrays).
  # The six columns of the tables are:
  #   identity
  #   median-multiplicity
  #   shared-hashes - number of full k-mer matches
  #   p-value
  #   query-ID - adapter description or a path of the reference fasta file
  #   species and strain or, where not applicable or impossible to infer,
  #     the same value as in the previous column
  # The tables are sorted in order of decreasing identity.

  $self->result->doc(\%EMPTY_RESULT); # Initialise the result.
  if (defined $self->num_input_reads and $self->num_input_reads == 0 ) {
    $self->result->add_comment('Zero input reads, not running the check');
  } else {
    try {
      $self->result->doc($self->_capture_output($self->_screen()));
    } catch {
      $self->result->add_comment(qq[Error: $_]);
    };
    $self->result->set_info('command', $self->_command());
    $self->result->set_info('samtools_version',
      $self->current_version($self->samtools_cmd));
    $self->result->set_info('mash_version',
      $self->current_version($self->mash_cmd));
    $self->result->set_info('mash_sketch', $self->sketch_path());
  }

  return;
};

has '_command' => (
  isa        => q{Str},
  is         => q{ro},
  lazy_build => 1,
);
sub _build__command {
  my $self = shift;
  # The input file (cram or bam) is converted to FASTQ, the output is piped
  # to mash. The winner takes it all strategy for mash (-w option).
  my $command = sprintf
    '%s fasta -F%s - | %s screen -w -v %d %s -',
    $self->samtools_cmd,
    $SAMTOOLS_FILTER,
    $self->mash_cmd,
    $MASH_SCREEN_MAX_PVALUE,
    $self->sketch_path;

  # If the number of reads is known and is non-zero and is larger than
  # the threshold, screen a proportion of reads.
  if (defined $self->num_input_reads) {
    if ($self->num_input_reads > $SUFFICIENT_NUM_READS) {
      my $scale_factor = sprintf '%.2f',
                         ${SUFFICIENT_NUM_READS}/$self->num_input_reads;
      $self->result->add_comment(
        qq[Number of input reads is subsampled by a factor of $scale_factor]);
      # Will convert to SAM here - OK?
      $command = sprintf 'samtools view -s %s | %s',
                          $scale_factor, $command;
    }
  } else {
    $self->result->add_comment(q[Number of input reads is not known]);
  }

  $command = sprintf 'cat %s | %s', $self->input_files->[0], $command;

  return qq[/bin/bash -c "set -o pipefail && $command"];
}

sub _screen {
  my $self = shift;

  my $command = $self->_command();
  open my $fh, q[|-], $command or
    croak qq[Cannot open filehandle for '$command', error $ERRNO];
  #my @data = slurp $fh;
  #my $child_error = $CHILD_ERROR >> $SHIFT_EIGHT;
  #if ($child_error != 0) {
  #  croak qq[Error in pipe '$command': $child_error];
  #}
  my @data = slurp $fh;
  close $fh or croak qq[Cannot close file handle for '$command'];
  # mash fails if input with no reads is supplied. If we did not know the
  # number of input reads upfront and were not able to bypass executing of
  # commands, the error might be due to empty input.

  return \@data;
}

sub _capture_output {
  my ($self, $data) = @_;

  # Sort results in order of decreasing identity.
  my @rows = reverse
             sort { $a->[0] <=> $b->[0] }
             map { [(split /\s/smx)] }
             @{$data};
  my %empty   = %EMPTY_RESULT;
  my $results = \%empty;
  # Examine the query ID - fifth column - to see whether this is a match to
  # the adapter or the reference. There might be no data for adapter matches
  # either because the data is not contaminated by the adapters, or because
  # the mash sketchh does not contain data adapter k-mers, or because the
  # descriptions of the adapter sequences do not conform to our expected
  # pattern.
  for my $row (@rows) {

    my $query_id = $row->[$QUERY_ID_INDEX];
    my $name = $query_id;
    my $is_adapter = ($query_id =~ /\|adapter\Z/smx);

    # The sixth column is query comment, in our case the description of the
    # first contig for references or nothing for adapters. This is not useful,
    # so we replace it by the species and strain or version name or, failing
    # to infer this data, by the query id.
    if (not $is_adapter) {
      my ($ref, $strain) = $query_id =~ m{/references/(\w+)/(\w+)/}smx;
      if ($ref and $strain) {
        $name = sprintf '%s (%s)', $ref, $strain;
      } else {
        carp "Failed to infer species and strain from $query_id";
      }
    }
    $row->[$QUERY_ID_INDEX + 1] = $name;

    if ($is_adapter) {
      push @{$results->{'adapters'}}, $row;
    } else {
      push @{$results->{'references'}}, $row;
    }
  }

  return $results;
}

__PACKAGE__->meta->make_immutable();

1;

__END__

=head1 NAME

npg_qc::autoqc::checks::cscreen

=head1 SYNOPSIS

=head1 DESCRIPTION

Contamination screen performed with mash against a sketch which contains
k-mers from references of all species in teh WTS reference collection.

=head1 SUBROUTINES/METHODS

=head2 new

A Moose class constructor.

=head2 repository

A path to the NPG data repository. Is set automatically if the
NPG_REPOSITORY_ROOT environment variableis set. Inherited from the
C<npg_tracking::data::reference::list> role.

=head2 metaref_repository

A path to the NPG repository for matagenome references. Inherited from the
C<npg_tracking::data::reference::list> role.

=head2 file_type

Input file type, ie file extension without a dot (cram, bam). Relevant if
the inputs_file array is not set by the caller. Inherited from the parent
C<npg_qc::autoqc::checks::check>.

=head2 input_files

An array of input files, only the first file will be used as input.
Inherited from the parent C<npg_qc::autoqc::checks::check>.

=head2 samtools_cmd

An absolute path to C<samtools> executable, inferred automatically if
<samtools> is on the C<PATH>, error if not. Inherited from the 
C<npg_common::roles::software_location> role.

=head2 mash_cmd

An absolute path to C<mash> executable, inferred automatically if
<mash> is on the C<PATH>, error if not. Inherited from the 
C<npg_common::roles::software_location> role.

=head2 sketch_path

An absolute path to a mash sketch that will be used to screen the reads
against. Defaults to C<<mash/screen/all_species_current.msh>> in the directory
specified by the metaref_repository attribute.

If the file is a symbolic link, the target file will be used. A relative
path will be converted to an absolute path.

=head2 tm_json_file

A path to a JSON file serialization of the tag_metrics autoqc result object
for the same lane and run this object belongs to. An optional attribute.
If set, provides data about the number of input reads.

=head2 num_input reads

Number of input reads. An optional argument. An attempt to infer the value
from the tag_metrics autoqc result will be made, the value will be set to
undefined if the metrics is not available or there is a problem accessing it.

=head2 execute

Extends the parent's C<execute> method. 

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

samtools and mash executables should be on the PATH

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor;

=item namespace::autoclean

=item Carp

=item English

=item Perl6::Slurp

=item Readonly

=item File::Spec

=item Cwd

=item File::Basename

=item npg_tracking::data::reference::list

=item npg_common::roles::software_location

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

No information about the degree of contamination is produced.

=head1 AUTHOR

Marina Gourtovaia

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2021 GRL.

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

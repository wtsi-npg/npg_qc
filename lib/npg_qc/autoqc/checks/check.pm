package npg_qc::autoqc::checks::check;

use Moose;
use MooseX::Aliases;
use MooseX::StrictConstructor;
use namespace::autoclean;
use Class::Load qw(load_class);
use File::Basename;
use File::Spec::Functions qw(catfile);
use File::Temp qw(tempdir);
use List::MoreUtils qw(any uniq);
use Readonly;
use Carp;

use npg_tracking::util::types;

extends 'npg_tracking::glossary::composition::factory::rpt_list';

with qw/ npg_tracking::glossary::run
         npg_tracking::glossary::lane
         npg_tracking::glossary::tag
         npg_tracking::glossary::rpt
         MooseX::Getopt
       /;

our $VERSION = '0';

Readonly::Scalar my $FILE_EXTENSION  => 'fastq';
Readonly::Scalar my $HUMAN           => q[Homo_sapiens];
Readonly::Scalar my $FORWARD_READ_FILE_NAME_SUFFIX => q[1];
Readonly::Scalar my $REVERSE_READ_FILE_NAME_SUFFIX => q[2];

## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc::autoqc::checks::check

=head1 SYNOPSIS

  my $check = npg_qc::autoqc::checks::check->new(qc_in    => q[a/valid/path],
                                                 position => 1,
                                                 id_run   => 2222);

=head1 DESCRIPTION

A parent class for autoqc checks. Checks are performed either for a lane or
for a plex (index, lanelet) or for a composition of the former defined by the
rpt_list attribute.

=head1 SUBROUTINES/METHODS

=head2 rpt_list

Semi-colon separated list of run:position or run:position:tag.
An optional attribute. Should be given if id_run and position are not supplied.

=cut

has '+rpt_list' => ( required      => 0,
                     lazy_build    => 1,
                   );
sub _build_rpt_list {
  my $self = shift;
  return $self->deflate_rpt();
}

=head2 id_run

An optional run id.

=cut

has '+id_run' => ( required => 0, );

=head2 position

An optional position.

=cut

has '+position' => ( required => 0, );

=head2 tag_index

An optional tag index.

=cut

has '+tag_index' => ( isa => 'NpgTrackingTagIndex', );

=head2 composition

A npg_tracking::glossary::composition object.

=cut

has 'composition' => (
    is         => 'ro',
    isa        => 'npg_tracking::glossary::composition',
    required   => 0,
    lazy_build => 1,
    metaclass  => 'NoGetopt',
    handles   => {
      'num_components'     => 'num_components',
    },
);
sub _build_composition {
  my $self = shift;
  return $self->create_composition();
}

with qw/npg_tracking::glossary::moniker/;

=head2 BUILD

A constructor helper, runs after the default constructor.

=cut

sub BUILD {
  my $self = shift;
  $self->composition();
  return;
}

=head2 qc_in

A path to a directory with input files. If not defined, the input
will be read from standard in.

=head2 path

Alias for qc_in.

=cut

has 'qc_in'        => (isa        => 'Str',
                       is         => 'ro',
                       required   => 0,
                       alias      => 'path',
                       predicate  => 'has_qc_in',
                       trigger    => \&_test_qc_in,
                      );
sub _test_qc_in {
  my ($self, $qc_in) = @_;

  foreach my $d ( ref $qc_in ? @{$qc_in} : ($qc_in) ) {
    if (!-R $d) {
      croak qq[Input qc directory $d does not exist or is not readable];
    }
  }
  return;
}

=head2 qc_out

Path to a directory where the results should be written to. Read-only.

=cut

has 'qc_out'      => (isa        => 'Str',
                      is         => 'ro',
                      required   => 0,
                      lazy_build => 1,
                      trigger    => \&_test_qc_out,
                     );
sub _build_qc_out {
  my $self = shift;
  if (!$self->has_qc_in) {
    croak 'qc_out should be defined';
  }
  $self->_test_qc_out($self->qc_in);
  return $self->qc_in;
}
sub _test_qc_out {
  my ($self, $qc_out) = @_;
  if (!-W $qc_out) {
    croak qq[Output qc directory $qc_out does not exist or is not writable];
  }
  return;
}

=head2 filename_root

A filename root for storing the serialized result objects and finding
input files.

=cut

has 'filename_root' => (isa           => q[Str],
                        is            => q[ro],
                        required      => 0,
                        predicate     => 'has_filename_root',
                       );

=head2 tmp_path

A path to a directory that can be used by the check to write temporary files to.
By default, a temporary directory in a usual place for temporary files (/tmp on Linux)
will be created and deleted automatically on exit.

=cut

has 'tmp_path'    => (isa        => 'Str',
                      is         => 'ro',
                      required   => 0,
                      default    => sub { return tempdir(CLEANUP => 1); },
                     );

=head2 file_type

Input file type as extension. Example: bam, fastq.
Default - fastq.

=cut

has 'file_type' => (isa        => 'Str',
                    is         => 'ro',
                    required   => 0,
                    default    => $FILE_EXTENSION,
                   );

=head2 suffix

Input file name suffix. The semantics to be defined by a specific
check object. An optional attribute.

=cut

has 'suffix' => (isa        => 'Str',
                 is         => 'ro',
                 required   => 0,
                );

=head2 input_files

Array reference with names of input files for this check

=cut

has 'input_files'    => (isa        => 'ArrayRef',
                         is         => 'ro',
                         required   => 0,
                         lazy_build => 1,
                        );
sub _build_input_files {
  my $self = shift;
  if (!$self->has_qc_in) {
    croak 'Input file(s) are not given, qc_in should be defined';
  }
  my @files = sort $self->get_input_files();
  return \@files;
}

=head2 result

A result object. Read-only.

=cut

has 'result'     =>  (isa        => 'Object',
                      is         => 'ro',
                      required   => 0,
                      metaclass  => 'NoGetopt',
                      lazy_build => 1,
                     );
sub _build_result {
  my $self = shift;

  my $class_name = ref $self;
  my $module_version = $VERSION;
  my $module = $class_name;

  $module =~ s/checks/results/xms;
  $module =~ s/check\Z/result/xms;
  load_class($module);

  my $nref = {};
  if ($self->composition->num_components == 1) {
    $nref = $self->inflate_rpts($self->rpt_list)->[0];
  }
  $nref->{'composition'} = $self->composition;
  if ($self->has_qc_in) {
    # We'll capture one path only. Can be changed in the future.
    $nref->{'path'} = ref $self->qc_in ? $self->qc_in->[0] : $self->qc_in;
  }
  if ($self->can('subset') && $self->subset) {
    $nref->{'subset'} = $self->subset;
  }
  if ($self->has_filename_root) {
    $nref->{'filename_root'} = $self->filename_root;
  }

  my $result = $module->new($nref);
  $result->set_info('Check', $class_name);
  $result->set_info('Check_version', $module_version);

  return $result;
}

=head2 run

Creates an object that can perform the requested test, calls test
execution and writes out test results to the output directory.

=cut

sub run {
  my $self = shift;
  $self->execute();
  my @results = ($self->result());
  if ($self->can('related_results')) {
    push @results, @{$self->related_results()};
  }
  foreach my $r (@results) {
    $r->store($self->qc_out);
  }
  return 1;
}

=head2 execute

This method is called by the qc script to run the check, perform
all necessary computation and save results as an in-memory result
object. The derived class should provide a full implementation of
this method.

In this class the method tries to find input files if not given
and exists with an error if no files are found. If input_files
attribute is set by the caller, the method errors if the array
of files is empty or any of the files in the array do not exist.

Returns the number of input files.

=cut

sub execute {
  my $self = shift;
  my @files = @{$self->input_files};
  @files or croak 'input_files array cannot be empty';
  if (any { !-e } @files) {
    croak 'Some of input files do not exist: ' . join q[, ], @files;
  }
  return scalar @files;
}

=head2 can_run

Decides whether this check can be run for a particular run.
Returns true. The derived class might implement this method.

=cut

sub can_run {
  return 1;
}

=head2 get_id_run

If all components belong to the same run, returns this run's id.
In other cases returns an undefined value.

=cut

sub get_id_run {
  my $self = shift;
  my @ids = uniq map { $_->id_run } $self->composition->components_list();
  if (scalar @ids == 1) {
    return $ids[0];
  }
  return;
}

=head2 get_input_files

Returns an array containing full paths to input files.
Error if the only input file or an input file for the
forward read is not found.

=cut

sub get_input_files {
  my $self = shift;

  my @fnames = ();
  my $file_name_root = $self->file_name;

  my $filename = catfile($self->qc_in, $self->create_filename($file_name_root));
  if (-e $filename) {
    push @fnames, $filename;
  } else {
    if ($self->file_type =~ /\Afastq/smx) {
      my $original = $filename;
      $filename = catfile($self->qc_in,
        $self->create_filename($file_name_root, $FORWARD_READ_FILE_NAME_SUFFIX));
      if (!-e $filename) {
        croak qq[Neither $original nor $filename file found];
      }
      push @fnames, $filename;
      $filename = catfile($self->qc_in,
        $self->create_filename($file_name_root, $REVERSE_READ_FILE_NAME_SUFFIX));
      if (-e $filename) {
        push @fnames, $filename;
      }
    } else {
      croak qq[$filename file not found];
    }
  }

  return @fnames;
}

=head2 generate_filename_attr

Returns an array ref with input file names.

=cut

sub generate_filename_attr {
  my $self = shift;
  my @filenames = ();
  foreach my $fname (@{$self->input_files}) {
    my($name, $directories, $suffix) = fileparse($fname);
    push @filenames, $name;
  }
  return \@filenames;
}

=head2 overall_pass

If the evaluation is performed separately for a forward and a reverse sequence,
computes overall lane pass value for a particular check.

=cut

sub overall_pass {
  my ($self, @apass) = @_;
  return (any { $_ == 0 } @apass) ? 0 : 1;
}

=head2 create_filename

Returns an input file name for an argument file name root. Takes an optional
second argument - end. The file extention is appended as well, the value
is taken from the file_type attribute of the object. For samtools stats files
the F0xB00 filter is used.

=cut

sub create_filename {
  my ($self, $file_name_root, $end) = @_;

  $file_name_root or croak 'File name root is required';

  my $name = $file_name_root;
  if ($self->suffix) {
    $name = $self->file_name_full($name, suffix => $self->suffix );
  }
  if ($end) {
    $name = $self->file_name_full($name, suffix => $end);
  }

  return $self->file_name_full($name, ext => $self->file_type);
}

=head2 entity_has_human_reference

Returns true if the reference_genome attribute is defined
for the entiry and the value of the attribute indicates
that the reference is for Homo Sapiens.

=cut

sub entity_has_human_reference {
  my $self = shift;

  if (!$self->can('lims')) {
    $self->result->add_comment('lim saccessor is not defined');
    return 0;
  }

  my $ref = $self->lims->reference_genome;
  if(!$ref) {
    $self->result->add_comment('No reference genome specified');
    return 0;
  }
  if($ref !~ /\A$HUMAN/smx) {
    $self->result->add_comment("Non-human reference genome '$ref'");
    return 0;
  }

  return 1;
}

=head2 to_string

Returns a human readable string representation of the object.

=cut

sub to_string {
  my $self = shift;
  return join q[ ], ref $self , $self->composition->freeze;
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::Aliases

=item MooseX::StrictConstructor

=item MooseX::Getopt

=item namespace::autoclean

=item Class::Load

=item Carp

=item Readonly

=item File::Basename

=item File::Spec::Functions

=item File::Temp

=item List::MoreUtils

=item npg_tracking::glossary::run

=item npg_tracking::glossary::lane

=item npg_tracking::glossary::tag

=item npg_tracking::glossary::moniker

=item npg_tracking::util::types

=item npg_tracking::glossary::composition::factory::rpt_list

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018 GRL

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

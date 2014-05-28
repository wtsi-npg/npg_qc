#########
# Author:        Marina Gourtovaia
# Created:       29 July 2009
#

package npg_qc::autoqc::checks::check;

use Moose;
use MooseX::ClassAttribute;
use MooseX::Aliases;
use Carp;
use English qw(-no_match_vars);
use File::Basename;
use File::Spec::Functions qw(catfile);
use File::Temp qw(tempdir);
use Perl6::Slurp;
use Readonly;

use npg_tracking::util::types;

with qw/ npg_tracking::glossary::tag
         npg_common::roles::run::lane::file_names
       /;

our $VERSION = '0';
## no critic (Documentation::RequirePodAtEnd ProhibitParensWithBuiltins ProhibitStringySplit)

=head1 NAME

npg_qc::autoqc::checks::check

=head1 SYNOPSIS

  my $check1 = npg_qc::autoqc::checks::check->new(path => q[a/valid/path], position => 1, id_run => 2222);

=head1 DESCRIPTION

A top-level class for autoqc checks. Checks are performed for one lane.

=head1 SUBROUTINES/METHODS

=cut


Readonly::Scalar our $FILE_EXTENSION  => 'fastq';


=head2 path

A path to a directory with input files. Read-only.

=cut
has 'path'        => (isa      => 'Str',
                      is       => 'ro',
                      required => 1,
                     );

=head2 position

Lane number. An integer from 1 to 8 inclusive. Read-only.

=cut
has 'position'    => (isa       => 'NpgTrackingLaneNumber',
                      is        => 'ro',
                      required  => 1,
                     );


=head2 id_run

Run id for the lane to be checked. Read-only.

=cut
has 'id_run'      => (
                       isa      => 'NpgTrackingRunId',
                       is       => 'ro',
                       required => 1,
                     );

=head2 sequence_type

Sequence type as phix for spiked phix or similar. Read-only.

=cut
has 'sequence_type'  => (
                         isa      => 'Maybe[Str]',
                         is       => 'ro',
                         required => 0,
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

=head2 input_file_ext

Input file extension.

=cut
has 'input_file_ext' => (isa        => 'Str',
                         is         => 'ro',
                         required   => 0,
                         default    => $FILE_EXTENSION,
                         writer     => '_set_ext',
                         alias      => 'file_type',
                        );


=head2 input_file

A ref to a list with names of input files for this check

=cut
has 'input_files'    => (isa        => 'ArrayRef',
                         is         => 'ro',
                         required   => 0,
                         lazy_build => 1,
                        );
sub _build_input_files {
    my $self = shift;
    my @files = $self->get_input_files();
    return \@files;
}


=head2 result

A result object. Read-only.

=cut
has 'result'     =>  (isa        => 'Object',
                      is         => 'ro',
                      required   => 0,
                      lazy_build => 1,
                     );
sub _build_result {

    my $self = shift;

    my $pkg_name = ref $self;
    ## no critic (TestingAndDebugging::ProhibitNoStrict ValuesAndExpressions::ProhibitInterpolationOfLiterals)
    no strict 'refs';
    my $module_version = ${$pkg_name."::VERSION"};
    use strict;
    ## use critic

    my ($ref) = ($pkg_name) =~ /(\w*)$/smx;
    if ($ref eq q[check]) { $ref =  q[result]; }
    my $module = "npg_qc::autoqc::results::$ref";
    Class::MOP::load_class($module);

    my $result = $module->new(
                    id_run    => $self->id_run,
                    position  => $self->position,
                    path      => $self->path,
                    tag_index => $self->tag_index
                             );
    $result->set_info('Check', $pkg_name);
    $result->set_info('Check_version', $module_version);
    if ($result->can(q[sequence_type])) {
        $result->sequence_type($self->sequence_type);
    }
    return $result;
}

=head2 _cant_run_ms

A message describing why the check cannot be run

=cut
has '_cant_run_ms' => (isa => 'Str',
  is => 'rw',
  required => 0,
);

=head2 execute

The actual test should be performed within this method. In this class this method only checks that the given path exists.

=cut
sub execute {
    my $self = shift;
    if (!$self->path)     {croak q[No input files directory supplied];}
    if (!-e $self->path)  {croak q[Input files directory ] . $self->path() . q[ does not exist];}
    if (!@{$self->input_files}) {
        return 0;
    }
    return 1;
}


=head2 can_run

Decides whether this check can be run for a particular run.

=cut
sub can_run {
    return 1;
}


=head2 get_input_files

Returns an array containing full paths to a forward and reverse(if any) input files.

=cut
sub get_input_files {
    my $self = shift;

    my @fnames = ();
    my $forward = File::Spec->catfile($self->path, $self->create_filename($self->input_file_ext, 1));
    my $no_end_forward = undef;
    if (!-e $forward) {
        $no_end_forward = File::Spec->catfile($self->path, $self->create_filename($self->input_file_ext));
        if (-e $no_end_forward) {
           $forward = $no_end_forward;
        } else {
           $self->result->comments(qq[Neither $forward no $no_end_forward file found]);
           return @fnames;
        }
    }

    push @fnames, $forward;
    if (!defined $no_end_forward) {
        my $reverse =  File::Spec->catfile($self->path, $self->create_filename($self->input_file_ext, 2));
        if (-e $reverse) {push @fnames, $reverse;}
    }

    return @fnames;
}


=head2 generate_filename_attr

Gets an array containing paths to forward and reverse (if any) input files, and returns
an array ref with filenames that is suitable for setting the filename attribute.

=cut
sub generate_filename_attr {

    my ($self) = shift;

    my $count = 0;
    my $filename;
    foreach my $fname (@{$self->input_files}) {
        my($name, $directories, $suffix) = fileparse($fname);
        $filename->[$count] = $name;
        $count++;
    }
    return $filename;
}


=head2 overall_pass

Use this function to compute overall lane pass value for a particular check
if the evaluation is performed separately for a forward and a reverse sequence.

=cut
sub overall_pass {

  my ($self, $apass, $count) = @_;
  if ($apass->[0] != 1 || $count == 1) {return $apass->[0];}
  if ($apass->[1] != 1) {return $apass->[1];}
  return ($apass->[0] && $apass->[1]);
}

no MooseX::ClassAttribute;
no Moose;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::ClassAttribute

=item Carp

=item English -no_match_vars

=item File::Basename

=item File::Spec::Functions

=item File::Temp

=item npg_tracking::glossary::tag

=item npg_tracking::util::types

=item npg_common::roles::run::lane::file_names

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Marina Gourtovaia

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

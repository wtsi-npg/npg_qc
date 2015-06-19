package npg_qc_viewer::Util::FileFinder;
use Moose;
use Carp;
use English qw{-no_match_vars};
use File::Spec::Functions qw(catfile);
use File::Basename;
use Readonly;
use npg_qc::Schema;

with qw/ npg_tracking::glossary::lane
  npg_tracking::glossary::tag
  npg_tracking::illumina::run::short_info
  npg_tracking::illumina::run::folder
  /;

our $VERSION = '0';
## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)

Readonly::Scalar our $FILE_EXTENSION    => q[fastq];
Readonly::Scalar our $RESULT_CLASS_NAME => q[Fastqcheck];

has 'db_lookup' => (
  isa      => 'Bool',
  is       => 'ro',
  required => 0,
  writer   => '_set_db_lookup',
  default  => 1,
);

has 'file_extension' => (
  isa      => 'Maybe[Str]',
  is       => 'rw',
  required => 0,
  default  => $FILE_EXTENSION,
);

has 'with_t_file' => (
  isa      => 'Bool',
  is       => 'ro',
  required => 0,
  default  => 0,
);

has 'lane_archive_lookup' => (
  isa      => 'Bool',
  is       => 'ro',
  required => 0,
  default  => 1,
);

has 'qc_schema' => (
  isa        => 'npg_qc::Schema',
  is         => 'ro',
  required   => 0,
  lazy_build => 1,
);

sub _build_qc_schema {
  my $self   = shift;
  my $schema = npg_qc::Schema->connect();
  return $schema;
}

has 'globbed' => (
  isa        => 'HashRef',
  is         => 'ro',
  required   => 0,
  lazy_build => 1,
);

sub _build_globbed {
  my $self   = shift;
  my $hfiles = {};

  if ( $self->file_extension eq q[fastqcheck] && $self->db_lookup ) {
    my $pattern = join q[_], $self->id_run, $self->position;
    $pattern .= q[%];

    if ( $self->file_extension ) {
      $pattern .= $self->file_extension;
    }
    my @rows = $self->qc_schema->resultset($RESULT_CLASS_NAME)->search(
      { id_run => $self->id_run, position => $self->position, },
      { columns   => 'file_name', },
    )->all;
    foreach my $row (@rows) {
      my $fname = $row->file_name;
      $hfiles->{$fname} = $fname;
    }
  }

  if ( ( scalar keys %{$hfiles} ) == 0 ) {
    my $path =
      ( defined $self->tag_index && $self->lane_archive_lookup )
      ? File::Spec->catfile( $self->archive_path, $self->lane_archive )
      : $self->archive_path;

    my $glob = catfile( $path, q[*] );

    if ( $self->file_extension ) {
      $glob .= $self->file_extension;
    }

    my @files = glob "$glob";
    foreach my $file (@files) {
      my ( $fname, $dir, $ext ) = fileparse($file);
      $hfiles->{$fname} = $file;
    }

    $self->_set_db_lookup(0);
  }
  return $hfiles;
}

sub BUILD {
  my $self = shift;
  $self->_test_options_compatibility();
  return;
}

sub _test_options_compatibility {
  my $self = shift;
  if ( defined $self->tag_index && $self->with_t_file ) {
    croak 'tag_index and with_t_file attributes cannot be both set';
  }
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

npg_qc_viewer::Util::FileFinder - utilities library to locate files

=head1 SYNOPSIS

=head1 DESCRIPTION

Utility object to provide tools to find file using DB or file system
The object is initialised during construction when it receives a hash
with the query parameters. This initialisation includes locating the
files and keeping them in an attribute of this object.

=head1 SUBROUTINES/METHODS

=head2 file_extension - an attribute, defaults to fastq, can be empty

=head2 with_t_file - a boolean attribute, defaults to false, determines whether a file for tags will be looked up.

=head2 qc_schema - DBIx schema object for the NPG QC database

=head2 db_lookup - a boolean attribute defining whether a lookup in the qc db should be performed.
Is reset by the files method to show whether the file names do come from the db lookup. The
default initial value is true.

=head2 lane_archive_lookup - a boolean attribute indicating whether the files for tags (plexes) are
expected to be in the lane archive under the archive folder; defaults to true;

=head2 globbed - a lazily buils hash ref containing all actually available file names for a lane

=head2 BUILD

Query DB/file system to find the files which match the query from
the hash passed as constructor parameter. The files found are
stored in the object's attributes.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Carp

=item English qw{-no_match_vars}

=item File::Spec::Functions qw(catfile)

=item File::Basename

=item Readonly

=item npg_qc::Schema

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 Genome Research Ltd.

This file is part of NPG software.

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


package npg_qc_viewer::Util::FileFinder;

use Moose;
use namespace::autoclean;
use MooseX::StrictConstructor;
use Carp;
use File::Spec::Functions qw(catfile);
use File::Basename;
use Readonly;
use Try::Tiny;

use npg_qc::Schema;

with qw/ npg_tracking::illumina::run::short_info
         npg_tracking::illumina::run::folder /;

our $VERSION = '0';

Readonly::Scalar our $FILE_EXTENSION    => q[fastqcheck];
Readonly::Scalar our $RESULT_CLASS_NAME => q[Fastqcheck];

has 'db_lookup' => (
  isa        => 'Bool',
  is         => 'ro',
  required   => 0,
  writer     => '_set_db_lookup',
);

sub BUILD {
  my $self = shift;
  if ( $self->file_extension ne $FILE_EXTENSION || $self->has_location() ) {
    $self->_set_db_lookup(0);
  }
  return;
}

has 'file_extension' => (
  isa      => 'Str',
  is       => 'ro',
  required => 0,
  default  => $FILE_EXTENSION,
);

has 'qc_schema' => (
  isa      => 'Maybe[npg_qc::Schema]',
  is       => 'ro',
  required => 0,
);

has 'location' => (
  isa        => 'ArrayRef',
  is         => 'ro',
  required   => 0,
  predicate  => 'has_location',
  lazy_build => 1,
);
sub _build_location {
  my $self = shift;
  my @l = ();
  try {
    push @l, $self->archive_path;
    push @l, catfile($self->archive_path, q[lane*]);
  } catch {
    carp q[Failed to get runfolder location ] . ($_ ? $_ : q[no params]);
  };
  return \@l;
}

has 'files' => (
  isa        => 'HashRef',
  is         => 'ro',
  required   => 0,
  lazy_build => 1,
);
sub _build_files {
  my $self   = shift;

  my $hfiles = {};

  if ( $self->db_lookup ) {
    my $rs = $self->qc_schema->resultset($RESULT_CLASS_NAME)->search(
      { id_run  => $self->id_run },
      { columns => 'file_name', },
    );
    while (my $row = $rs->next) {
      my $fname = $row->file_name;
      $hfiles->{$fname} = $fname;
    }
  }

  if ( ( scalar keys %{$hfiles} ) == 0 ) {
    my $ext = $self->file_extension;
    my @globs = map { catfile($_, q[*]) . q[.] . $ext } @{$self->location};
    my @files = glob join q[ ], @globs; # All paths in one go
    foreach my $file (@files) {
      my ( $fname, $dir, $e ) = fileparse($file, ($ext));
      $hfiles->{ $fname.$ext } = $file;
    }
    if (@files) {
      $self->_set_db_lookup(0);
    }
  }

  return $hfiles;
}

sub create_filename {
  my ($self, $map, $end) = @_;
  
  return sprintf '%i_%i%s%s',
    $map->{'id_run'},
    $map->{'position'},
    $end ? "_$end" : q[],
    defined $map->{'tag_index'} ? '#'.$map->{'tag_index'} : q[];
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

npg_qc_viewer::Util::FileFinder

=head1 SYNOPSIS

=head1 DESCRIPTION

Finds files if file-extension type corresponding to this objects' attributes.
Files can be stored either in a database or on a file system or both.
If the database connection is available (qc_schema attribute is set), the database search
is performed first; id_run should be set for this. If the database search brings no results,
a file system glob is performed.

If the file extension differs from default, the database search is not performed.

One of run folder paths can be supplied in the constructor to assist with defining the
archival path for the run folder. Both run and all lane archives are going to be searched
at once.

Location attribute can be supplied to force a search in a number of known file system locations.
In this case the value of the id_run attribute is disregarded.

=head1 SUBROUTINES/METHODS

=head2 db_lookup - boolean flag showing whether the file names come from the database

=head2 BUILD - Sets db_lookup to 0 in case a non-default extension is used.

=head2 file_extension - an attribute, defaults to fastqcheck

=head2 qc_schema - DBIx schema object for the NPG QC database, optional

=head2 location - an optional array ref of paths for looking up files

=head2 files - lazily built hash ref containing all actually available file names
as keys and, in case of successful file system search, file paths as values

=head2 create_filename - given run id, position, tag index (optional) and end (optional)
returns a file name

  npg_qc_viewer::Util::FileFinder->create_filename(5,3,1,2);
  $obj->->create_filename(5,3,1);

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item MooseX::StrictConstructor

=item Carp

=item File::Spec::Functions

=item File::Basename

=item Readonly

=item Try::Tiny

=item npg_qc::Schema

=item npg_tracking::illumina::run::short_info

=item npg_tracking::illumina::run::folder

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


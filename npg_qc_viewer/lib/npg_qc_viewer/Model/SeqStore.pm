package npg_qc_viewer::Model::SeqStore;

use Carp;
use Moose;
use Readonly;

use npg_qc_viewer::Util::FileFinder;
use npg_common::roles::run::lane::file_names;
use npg_tracking::glossary::tag;
use npg_tracking::glossary::lane;
use npg_tracking::glossary::run;

extends 'Catalyst::Model::Factory::PerRequest';

our $VERSION = '0';
## no critic (Documentation::RequirePodAtEnd)

Readonly::Scalar our $FILE_EXTENSION      => q[fastqcheck];

__PACKAGE__->config( class => 'npg_qc_viewer::Model::SeqStore' );

has 'file_paths_cache' => (
  isa        => 'HashRef',
  is      => 'rw',
  default => sub { {} },
);

=head1 NAME

npg_qc_viewer::Model::SeqStore - access to sequence store

=head1 SYNOPSIS

=head1 DESCRIPTION

Catalyst model for accessing both short and long-term sequence store. 
It extends the Catalyst::Model::Factory::PerRequest model to allow for
cache data to be kept when looking for files.

=head1 SUBROUTINES/METHODS

=head2 files

A list of fastqcheck file paths for a run and position

=cut

sub files {
  my @sargs       = @_;
  my $self        = shift @sargs;
  my $rpt_key_map = shift @sargs;    # tag_index position id_run
  my $db_lookup   = shift @sargs;

  if ( @sargs && ( ref $sargs[0] ) eq q[ARRAY] ) {    # this is a list of paths
    $db_lookup = 0;
    my $all_files = {};
    my $count     = 0;
    foreach my $path ( @{ $sargs[0] } ) {
      my $files = $self->_files4one_path( $rpt_key_map, $db_lookup, $path );
      foreach my $ftype ( keys %{$files} ) {
        $all_files->{$ftype} = $files->{$ftype};
      }
    }
    if ( scalar keys %{$all_files} ) {
      $all_files->{db_lookup} = 0;
    }
    return $all_files;
  } else {
    return $self->_files4one_path($rpt_key_map, $db_lookup );
  }
  return;
}

sub _prepare_cache {
  my ( $self, $ref ) = @_;

  my $id_run = $ref->{id_run};

  if ( !( exists $self->file_paths_cache->{ $id_run }
      && defined $self->file_paths_cache->{ $id_run } )) {
    $self->file_paths_cache->{ $id_run } = {};
  }

  my $with_t_file = $ref->{with_t_file};

  if ( !(exists $self->file_paths_cache->{ $id_run }->{ $with_t_file }
      && defined $self->file_paths_cache->{ $id_run }->{ $with_t_file } )) {

    my $finder = npg_qc_viewer::Util::FileFinder->new($ref);

    my $globbed     = $finder->globbed;
    my $db_lookup   = $finder->db_lookup;

    my $cache = {globbed => $globbed, db_lookup => $db_lookup};

    $self->file_paths_cache->{ $id_run }->{ $with_t_file } = $cache;
  }

  return;
}

sub _build_file_name_helper {
  my ( $self, $ref ) = @_;
  return Moose::Meta::Class->create_anon_class(
    roles => [qw/npg_common::roles::run::lane::file_names
    npg_tracking::glossary::tag
    npg_tracking::glossary::lane
    npg_tracking::glossary::run/])->new_object($ref);
}

sub _files4one_path {
  my ( $self, $rpt_key_map, $db_lookup, $path ) = @_;

  my $ref = {
    file_extension      => $FILE_EXTENSION,
    with_t_file         => 1,
    lane_archive_lookup => 1,
    db_lookup           => $db_lookup,
  };

  foreach my $key ('file_extension', 'archive_path', 'lane_archive', 'lane_archive_lookup', 'id_run', 'position') {
    if (exists $rpt_key_map->{$key} && defined $rpt_key_map->{$key} ) {
      $ref->{$key} = $rpt_key_map->{$key}
    }
  }

  if ( exists $rpt_key_map->{tag_index} && defined $rpt_key_map->{tag_index} ) {
    $ref->{tag_index}   = $rpt_key_map->{tag_index};
    $ref->{with_t_file} = 0;
    if ($path) { $ref->{lane_archive_lookup} = 0; }
  }

  if ($path) { $ref->{archive_path} = $path; }

  #Load from file using $ref data
  $self->_prepare_cache($ref);

  my $file_name_helper = $self->_build_file_name_helper($ref);

  my $file_cache = $self->file_paths_cache->{ $ref->{id_run} }->{ $ref->{with_t_file} };

  my $fnames = {};
  #Try to get without tags
  my $f     = $file_name_helper->create_filename( $ref->{file_extension} );
  if ( exists $file_cache->{globbed}->{$f} ) {
    $fnames->{forward} = $file_cache->{globbed}->{$f};
  }

  if ( !exists $fnames->{forward} ) { # Get for forward and reverse with tag
    my $forward = $file_name_helper->create_filename( $ref->{file_extension}, 1 );
    if ( exists $file_cache->{globbed}->{$forward} ) {
      $fnames->{forward} = $file_cache->{globbed}->{$forward};
    }
    my $reverse = $file_name_helper->create_filename( $ref->{file_extension}, 2 );
    if ( exists $file_cache->{globbed}->{$reverse} ) {
      $fnames->{reverse} = $file_cache->{globbed}->{$reverse};
    }
  }

  #Look for the extra heatmap for tag
  if ( $ref->{with_t_file} ) {
    my $tag = $file_name_helper->create_filename( $ref->{file_extension}, q[t] );
    if ( exists $file_cache->{globbed}->{$tag} ) {
      $fnames->{tags} = $file_cache->{globbed}->{$tag};
    }
  }

  my $files = $fnames;
  if ( scalar keys %{$files} ) { #Keep the value of db_lookup for the template
    $files->{db_lookup} = $file_cache->{db_lookup};
  }

  return $files;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Readonly

=item Carp

=item Moose

=item Catalyst::Model

=item npg_common::run::file_finder

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

Jaime Tovar E<lt>jmtc@sanger.ac.ukE<gt>

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


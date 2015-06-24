package npg_qc_viewer::Model::SeqStore;

use Moose;
use Readonly;

use npg_qc_viewer::Util::FileFinder;
use npg_common::roles::run::lane::file_names;
use npg_tracking::glossary::tag;
use npg_tracking::glossary::lane;
use npg_tracking::glossary::run;
use npg_tracking::Schema;

extends 'Catalyst::Model::Factory::PerRequest';
__PACKAGE__->config( class => 'npg_qc_viewer::Model::SeqStore' );

our $VERSION = '0';
##no critic (Documentation::RequirePodAtEnd)

Readonly::Scalar our $FILE_EXTENSION  => q[fastqcheck];

=head1 NAME

npg_qc_viewer::Model::SeqStore

=head1 SYNOPSIS

=head1 DESCRIPTION

Catalyst model for accessing fastqcheck file storage.

Extends the Catalyst::Model::Factory::PerRequest model to allow for
cached data to be kept per request when looking for files.

=head1 SUBROUTINES/METHODS

=head2 qc_schema

=cut

has 'qc_schema' => (
  isa      => 'Maybe[npg_qc::Schema]',
  is       => 'ro',
  required => 0,
);

=head2 npg_tracking_schema

=cut

has 'npg_tracking_schema' => (
  isa      => 'Maybe[npg_tracking::Schema]',
  is       => 'ro',
  required => 0,
);

has '_file_cache' => (
  isa     => 'HashRef',
  is      => 'ro',
  default => sub { return {}; },
);
sub _add2cache {
  my ( $self, $ref ) = @_;

  $ref->{'qc_schema'}           = $self->qc_schema;
  $ref->{'npg_tracking_schema'} = $self->npg_tracking_schema;

  my $id_run = $ref->{'id_run'};
  if ( !$self->_file_cache->{$id_run} ) {
    my $finder = npg_qc_viewer::Util::FileFinder->new($ref);
    $self->_file_cache->{$id_run} =
      {'files' => $finder->files, 'db_lookup' => $finder->db_lookup};
  }
  return;
}

=head2 files

A hash of fastqcheck file paths for a given query

=cut

sub files {
  my @sargs       = @_;
  my $self        = shift @sargs;
  my $rpt_key_map = shift @sargs;    # tag_index position id_run
  my $db_lookup   = shift @sargs;

  my $ref = {};
  $ref->{'id_run'}    = $rpt_key_map->{'id_run'};
  $ref->{'db_lookup'} = $db_lookup;
  #Checking for locations (passed as array)
  if (@sargs && ( ref $sargs[0] ) eq q[ARRAY] ) {
    $ref->{'location'}  = $sargs[0];
  }
  $self->_add2cache($ref);

  return $self->_get_file_paths($rpt_key_map);
}

sub _file_name_helper {
  my $ref = shift;
  return Moose::Meta::Class->create_anon_class(
    roles => [qw/npg_common::roles::run::lane::file_names
                 npg_tracking::glossary::tag
                 npg_tracking::glossary::lane
                 npg_tracking::glossary::run/])->new_object($ref);
}

sub _get_file_paths {
  my ( $self, $rpt_key_map) = @_;

  my $id_run = $rpt_key_map->{'id_run'};

  my $fnames = {};
  my $helper = _file_name_helper($rpt_key_map);
  my $file_cache = $self->_file_cache->{$id_run}->{'files'};
  my $ext = $FILE_EXTENSION;

  my $file_name = $helper->create_filename($ext);
  if ($file_cache->{$file_name}) {
    $fnames->{'forward'} = $file_cache->{$file_name};
  }

  if ( !$fnames->{'forward'} ) { # Get for forward and reverse with end
    $file_name = $helper->create_filename($ext, 1);
    if ($file_cache->{$file_name}) {
      $fnames->{'forward'} = $file_cache->{$file_name};
    }
    $file_name = $helper->create_filename($ext, 2);
    if ($file_cache->{$file_name}) {
      $fnames->{'reverse'} = $file_cache->{$file_name};
    }
  }

  #Look for the extra heatmap for tag
  if ( !exists $rpt_key_map->{'tag_index'}) {
    $file_name = $helper->create_filename($ext, q[t]);
    if ($file_cache->{$file_name}) {
      $fnames->{'tags'} = $file_cache->{$file_name};
    }
  }

  if ( scalar keys %{$fnames} ) { #Keep the value of db_lookup for the template
    $fnames->{'db_lookup'} = $self->_file_cache->{$id_run}->{'db_lookup'};
  }

  return $fnames;
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

=item Moose

=item Catalyst::Model::Factory::PerRequest

=item npg_common::roles::run::lane::file_names

=item npg_tracking::glossary::tag

=item npg_tracking::glossary::lane

=item npg_tracking::glossary::run

=item npg_tracking::Schema

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


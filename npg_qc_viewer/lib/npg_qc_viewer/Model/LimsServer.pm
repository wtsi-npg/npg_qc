package npg_qc_viewer::Model::LimsServer;

use Moose;
use namespace::autoclean;
use Carp;

extends 'Catalyst::Model';

our $VERSION = '0';

##no critic (Subroutines::ProhibitUnusedPrivateSubroutines)

sub generate_url {
  my ($self, $entity_type, $values) = @_;

  if (!$entity_type) {
    croak 'Entity type (library|pool|sample) is missing';
  }
  if ($entity_type !~ /^sample$|^library$|^pool$/smx) {
    croak "Unknown entity type $entity_type";
  }
  if (!$values) {
    croak 'LIMS values object is missing';
  }
  my $expected_type = 'npg_qc_viewer::TransferObjects::ProductMetrics4RunTO';
  my $actual = ref $values || q[];
  if (ref $values ne $expected_type) {
    croak "$expected_type is expected, got $actual";
  }

  my $method = '_link_' . ($values->is_gclp ? 'clarity' : 'sscape');
  return $self->$method($entity_type, $values);
}

sub _link_clarity {
  my ($self, $entity_type, $values) = @_;

  my $url = npg_qc_viewer->config->{'Model::LimsServer'}->{'clarity_url'};
  my $link = q[];
  if ($url and $entity_type ne 'pool') {
    my $scope = $entity_type eq 'sample' ? 'Sample' : 'Container';
    my $id;
    if ($scope eq 'Container') {
      ($id) = $values->id_library_lims =~ /\A([^:]+)/smx;
    } else {
      $id = $values->id_sample_lims;
    }
    $link = sprintf '%s/search?scope=%s&query=%s', $url, $scope, $id;
  }

  return $link;
}

sub _link_sscape {
  my ($self, $entity_type, $values) = @_;

  my $url = npg_qc_viewer->config->{'Model::LimsServer'}->{'sscape_url'};
  my $link = q[];
  if ($url) {
    my $scope = $entity_type eq 'sample' ? 'samples' : 'assets';
    my $id = $entity_type eq 'sample'
           ? $values->id_sample_lims
           : ($entity_type eq 'pool'
           ? $values->entity_id_lims : $values->legacy_library_id);
    $link = join q[/], $url, $scope, $id;
  }
  return $link;
}

__PACKAGE__->meta->make_immutable;

1;
__END__


=head1 NAME

npg_qc_viewer::Model::LimsServer

=head1 SYNOPSIS

=head1 DESCRIPTION

Catalyst model for wrapping LIMS server information.

=head1 SUBROUTINES/METHODS

=head2 generate_url
  
  Generates a link to a LIMS resource.

  my $is_gclp_lims = 1;
  my $values = npg_qc_viewer::TransferObjects::ProductMetrics4RunTO->new();
  my $surl = $c->model('LimsServer')
    ->generate_url('sample', '$is_gclp_lims', $values);
  $lurl = $c->model('LimsServer')
    ->generate_url('library', '$is_gclp_lims', $values);
  $lurl = $c->model('LimsServer')
    ->generate_url('pool', '$is_gclp_lims', $values);

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Carp

=item Moose

=item namespace::autoclean

=item Catalyst::Model

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


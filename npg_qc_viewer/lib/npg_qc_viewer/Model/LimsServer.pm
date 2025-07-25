package npg_qc_viewer::Model::LimsServer;

use Moose;
use namespace::autoclean;
use Carp;

extends 'Catalyst::Model';

our $VERSION = '0';

sub generate_url {
  my ($self, $entity_type, $to) = @_;

  $entity_type ||= q[];
  if ($entity_type !~ /^sample$|^library$|^pool$/smx) {
    croak qq[Unknown entity type "$entity_type"];
  }

  my $url = npg_qc_viewer->config->{'Model::LimsServer'}->{'sscape_url'};
  my $link = q[];
  if ($url) {
    my $scope = $entity_type eq 'sample' ? 'samples' : 'assets';
    my $id = $entity_type eq 'sample'
           ? $to->sample_id
           : ($entity_type eq 'pool'
           ? $to->entity_id_lims : $to->legacy_library_id);
    if ($id) {
      $link = join q[/], $url, $scope, $id;
    }
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

  # $to is a npg_qc_viewer::Util::TransferObject object
  my $surl = $c->model('LimsServer')->generate_url('sample', $to);
  my $lurl = $c->model('LimsServer')->generate_url('library', $to);
  my $lurl = $c->model('LimsServer')->generate_url('pool', $to);

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

Copyright (C) 2017, 2025  Genome Research Ltd.

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


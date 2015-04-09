package npg_qc_viewer::Controller::Mqc_Run;

use Moose;
use namespace::autoclean;
use Readonly;

BEGIN { extends 'Catalyst::Controller::REST' }

#Just to declare a default. But seems the content type should come from client
#anyway
__PACKAGE__->config(default => 'application/json');

with 'npg_qc_viewer::api::error';

our $VERSION  = '0';

sub mqc_runs :Path('/mqc/mqc_runs') :ActionClass('REST') { }

sub mqc_runs_GET {

  my ( $self, $c, $id_run) = @_;

  # Return a 200 OK, with the data in entity
  # serialized in the body
  $self->status_ok(
    $c,
    entity => {
      some => 'data',
      foo  => 'is real bar-y',
      id_run => $id_run,
    },
  );
}

__PACKAGE__->meta->make_immutable;

1;

=head1 NAME

npg_qc_viewer::Controller::Mqc_Run

=head1 SYNOPSIS

=head1 DESCRIPTION

Controller to expose runs through REST

=head1 SUBROUTINES/METHODS 

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Readonly

=item namespace::autoclean

=item Moose

=item Catalyst::Controller::REST

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

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
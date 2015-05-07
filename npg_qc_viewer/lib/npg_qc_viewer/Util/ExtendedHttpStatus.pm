package npg_qc_viewer::Util::ExtendedHttpStatus;

use Moose::Role;
use Carp;
use Readonly;
use Params::Validate;

our $VERSION = '0';

requires '_set_entity';

Readonly::Scalar my $RESPONSE_UNAUTHORIZED          => 401;
Readonly::Scalar my $RESPONSE_INTERNAL_SERVER_ERROR => 500;

## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_qc_viewer::Util::ExtendedHttpStatus

=head1 SYNOPSIS

=head1 DESCRIPTION

Moose role for extending functionality of REST controller by adding
subs for extra response codes.

=head1 SUBROUTINES/METHODS

=head2 status_unauthorized

 Returns a "401 Unauthorized" response. Takes a "message" argument
 as a scalar, which will become the value of "error" in the serialized
 response.

=cut

sub status_unauthorized {
  my @params = @_;
  my $self = shift @params;
  my $c    = shift @params;
  my %p    = Params::Validate::validate( @params, { message => { type => Params::Validate::SCALAR }, }, );
  $c->response->status($RESPONSE_UNAUTHORIZED);
  if ($c->debug) {
    $c->log->debug(q[Status Unauthorized: ] . $p{'message'} ) ;
  }
  $self->_set_entity( $c, { error => $p{'message'} } );
  return 1;
}

sub status_internal_server_error {
  my @params = @_;
  my $self = shift @params;
  my $c    = shift @params;
  my %p    = Params::Validate::validate( @params, { message => { type => Params::Validate::SCALAR }, }, );
  $c->response->status($RESPONSE_INTERNAL_SERVER_ERROR);
  if ($c->debug) {
    $c->log->debug(q[Internal Server Error: ] . $p{'message'} ) ;
  }
  $self->_set_entity( $c, { error => $p{'message'} } );
  return 1;
}

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Carp

=item Readonly

=item Params::Validate

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

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